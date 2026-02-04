/**
 * Routes Import/Export Produits
 * Gestion de l'import CSV et export catalogue
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const { Readable } = require('stream');
const { requireAuth } = require('../middlewares/auth.middleware');
const db = require('../config/db');

// Configuration multer pour fichiers CSV en mémoire
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 }, // Max 5MB
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'text/csv' || file.originalname.endsWith('.csv')) {
            cb(null, true);
        } else {
            cb(new Error('Seuls les fichiers CSV sont acceptés'), false);
        }
    }
});

/**
 * Middleware pour vérifier que l'utilisateur est vendeur
 */
const requireSeller = (req, res, next) => {
    if (!req.user.is_seller) {
        return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
    }
    next();
};

/**
 * Fonction utilitaire pour parser le CSV manuellement
 * (sans dépendance externe csv-parser)
 */
function parseCSV(csvString) {
    const lines = csvString.split('\n').filter(line => line.trim());
    if (lines.length < 2) return [];

    // Première ligne = headers
    const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, '').toLowerCase());

    const results = [];
    for (let i = 1; i < lines.length; i++) {
        const values = [];
        let current = '';
        let inQuotes = false;

        for (const char of lines[i]) {
            if (char === '"') {
                inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
                // Nettoyer la valeur : enlever les guillemets au début/fin et trim
                const cleanValue = current.trim().replace(/^"|"$/g, '');
                values.push(cleanValue);
                current = '';
            } else {
                current += char;
            }
        }
        // Dernière valeur de la ligne
        const cleanValue = current.trim().replace(/^"|"$/g, '');
        values.push(cleanValue);

        const row = {};
        headers.forEach((header, index) => {
            row[header] = values[index] || '';
        });
        results.push(row);
    }

    return results;
}

/**
 * GET /import-export/template
 * Télécharger le template CSV pour l'import
 */
router.get('/template', requireAuth, requireSeller, (req, res) => {
    const csvTemplate = `name,description,price,quantity,category,brand,unit,weight,images
"Exemple Produit","Description du produit",25.99,100,"Électronique","Samsung","Pièce","500g","https://example.com/image.jpg"
"Autre Produit","Une autre description",15.50,50,"Alimentation > Épicerie","","Kg","1kg",""`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename=oli_products_template.csv');
    res.send(csvTemplate);
});

/**
 * POST /import-export/import
 * Import CSV de produits en masse
 */
router.post('/import', requireAuth, requireSeller, upload.single('file'), async (req, res) => {
    const client = await db.connect();

    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Fichier CSV requis' });
        }

        const csvString = req.file.buffer.toString('utf-8');
        const rows = parseCSV(csvString);

        if (rows.length === 0) {
            return res.status(400).json({ error: 'Fichier CSV vide ou mal formaté' });
        }

        // Créer un enregistrement d'import
        const importRecord = await client.query(`
            INSERT INTO import_history (seller_id, filename, total_rows, status)
            VALUES ($1, $2, $3, 'processing')
            RETURNING id
        `, [req.user.id, req.file.originalname, rows.length]);

        const importId = importRecord.rows[0].id;

        // Récupérer le shop du vendeur
        const shopResult = await client.query(
            'SELECT id FROM shops WHERE owner_id = $1 LIMIT 1',
            [req.user.id]
        );
        const shopId = shopResult.rows[0]?.id || null;

        await client.query('BEGIN');

        let imported = 0;
        const errors = [];

        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];

            try {
                // Mapper les colonnes (support français et anglais)
                const name = row.name || row.nom || '';
                const description = row.description || '';
                const price = parseFloat(row.price || row.prix || 0);
                const quantity = parseInt(row.quantity || row.stock || row.quantite || 0);
                const category = row.category || row.categorie || '';
                const brand = row.brand || row.marque || '';
                const unit = row.unit || row.unite || 'Pièce';
                const weight = row.weight || row.poids || '';
                const images = row.images ? row.images.split(';').map(i => i.trim()) : [];

                // Validation
                if (!name) {
                    errors.push({ row: i + 2, field: 'name', error: 'Nom requis' });
                    continue;
                }
                if (isNaN(price) || price <= 0) {
                    errors.push({ row: i + 2, field: 'price', error: 'Prix invalide' });
                    continue;
                }

                // Insérer le produit
                await client.query(`
                    INSERT INTO products (
                        seller_id, shop_id, name, description, price, 
                        category, quantity, brand, unit, weight, images,
                        status, is_active, created_at, updated_at
                    ) VALUES (
                        $1, $2, $3, $4, $5, 
                        $6, $7, $8, $9, $10, $11,
                        'active', true, NOW(), NOW()
                    )
                `, [
                    req.user.id, shopId, name, description, price,
                    category, quantity, brand, unit, weight, images
                ]);

                imported++;
            } catch (err) {
                errors.push({
                    row: i + 2,
                    error: err.message,
                    data: row.name || row.nom || 'Inconnu'
                });
            }
        }

        await client.query('COMMIT');

        // Mettre à jour l'enregistrement d'import
        await client.query(`
            UPDATE import_history 
            SET imported_count = $1, error_count = $2, errors = $3, 
                status = 'completed', completed_at = NOW()
            WHERE id = $4
        `, [imported, errors.length, JSON.stringify(errors), importId]);

        res.json({
            success: true,
            import_id: importId,
            total: rows.length,
            imported,
            errors: errors.length,
            error_details: errors.slice(0, 10) // Limiter à 10 erreurs dans la réponse
        });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error POST /import-export/import:', error);
        res.status(500).json({ error: 'Erreur lors de l\'import' });
    } finally {
        client.release();
    }
});

/**
 * GET /import-export/export
 * Export CSV de tous les produits du vendeur
 */
router.get('/export', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT 
                p.id, p.name, p.description, p.price, p.quantity,
                p.category, p.brand, p.unit, p.weight, p.images,
                p.is_active, p.created_at
            FROM products p
            WHERE p.seller_id = $1
            ORDER BY p.created_at DESC
        `, [req.user.id]);

        const products = result.rows;

        // Créer le CSV
        const headers = ['id', 'name', 'description', 'price', 'quantity', 'category', 'brand', 'unit', 'weight', 'images', 'is_active'];

        let csv = headers.join(',') + '\n';

        for (const product of products) {
            const row = headers.map(h => {
                let value = product[h] ?? '';

                // Formater les images comme string séparé par ;
                if (h === 'images' && Array.isArray(value)) {
                    value = value.join(';');
                }

                // Échapper les guillemets et entourer de guillemets si nécessaire
                if (typeof value === 'string' && (value.includes(',') || value.includes('"') || value.includes('\n'))) {
                    value = `"${value.replace(/"/g, '""')}"`;
                }

                return value;
            });

            csv += row.join(',') + '\n';
        }

        const filename = `oli_products_export_${new Date().toISOString().split('T')[0]}.csv`;

        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename=${filename}`);
        res.send(csv);

    } catch (error) {
        console.error('Error GET /import-export/export:', error);
        res.status(500).json({ error: 'Erreur lors de l\'export' });
    }
});

/**
 * GET /import-export/history
 * Historique des imports du vendeur
 */
router.get('/history', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT id, filename, total_rows, imported_count, error_count, 
                   status, created_at, completed_at
            FROM import_history
            WHERE seller_id = $1
            ORDER BY created_at DESC
            LIMIT 20
        `, [req.user.id]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /import-export/history:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /import-export/history/:id
 * Détails d'un import spécifique (avec erreurs)
 */
router.get('/history/:id', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT * FROM import_history
            WHERE id = $1 AND seller_id = $2
        `, [req.params.id, req.user.id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Import non trouvé' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /import-export/history/:id:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
