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
const exchangeRateService = require('../services/exchange-rate.service');
const cloudinary = require('cloudinary').v2;

/**
 * Re-upload une image externe vers Cloudinary
 * Nécessaire car les images scrapées (ex: losako.shop) n'ont pas de headers CORS,
 * ce qui empêche Flutter Web de les afficher.
 */
async function reuploadToCloudinary(imageUrl) {
    try {
        if (!imageUrl || !imageUrl.startsWith('http')) return imageUrl;

        // Si c'est déjà une URL Cloudinary, ne pas re-uploader
        if (imageUrl.includes('cloudinary.com')) return imageUrl;

        const result = await cloudinary.uploader.upload(imageUrl, {
            folder: 'oli_app/imported',
            resource_type: 'image',
        });
        console.log(`☁️  Image re-uploadée: ${imageUrl.substring(0, 50)}... → ${result.secure_url.substring(0, 50)}...`);
        return result.secure_url;
    } catch (err) {
        console.warn(`⚠️  Échec re-upload image: ${imageUrl.substring(0, 80)}... - ${err.message}`);
        return imageUrl; // Garder l'URL originale en fallback
    }
}

// Configuration multer pour fichiers CSV en mémoire
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 }, // Max 10MB
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
 * Fonction utilitaire pour parser le CSV — conforme RFC 4180
 * Gère correctement les guillemets doubles ("") dans les champs entre guillemets
 */
function parseCSV(csvString) {
    // Normaliser les fins de ligne (CRLF → LF)
    const text = csvString.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    // Tokenizer RFC 4180 : parcourt chaque caractère
    function parseRow(line, sep) {
        const fields = [];
        let field = '';
        let inQuotes = false;
        let i = 0;
        while (i < line.length) {
            const ch = line[i];
            if (inQuotes) {
                if (ch === '"') {
                    // Guillemet double ("") = guillemet littéral
                    if (i + 1 < line.length && line[i + 1] === '"') {
                        field += '"';
                        i += 2;
                        continue;
                    }
                    // Fin de champ entre guillemets
                    inQuotes = false;
                } else {
                    field += ch;
                }
            } else {
                if (ch === '"') {
                    inQuotes = true;
                } else if (ch === sep) {
                    fields.push(field);
                    field = '';
                } else {
                    field += ch;
                }
            }
            i++;
        }
        fields.push(field);
        return fields;
    }

    // Découper en lignes (respecter les champs multi-lignes entre guillemets)
    const lines = [];
    let current = '';
    let inQ = false;
    for (let ci = 0; ci < text.length; ci++) {
        const ch = text[ci];
        if (ch === '"') {
            inQ = !inQ;
            current += ch;
        } else if (ch === '\n' && !inQ) {
            if (current.trim()) lines.push(current);
            current = '';
        } else {
            current += ch;
        }
    }
    if (current.trim()) lines.push(current);

    if (lines.length < 2) return [];

    // Auto-détecter le séparateur
    const headerLine = lines[0];
    const separator = headerLine.includes(';') ? ';' : ',';
    console.log(`📄 CSV Separator detected: "${separator}"`);

    const rawHeaders = parseRow(headerLine, separator);
    const headers = rawHeaders.map(h => {
        const normalized = h.toLowerCase().trim();
        const mapping = {
            'nom': 'name',
            'prix': 'price',
            'stock': 'quantity',
            'quantite': 'quantity',
            'quantité': 'quantity',
            'catégorie': 'category',
            'categorie': 'category',
            'marque': 'brand',
            'unité': 'unit',
            'unite': 'unit',
            'poids': 'weight',
            'actif': 'is_active',
            'mainimage': 'images',
            'title': 'name',
            'companyname': 'brand',
            'moq': 'quantity',
            'producturl': 'source_url',
            'promotionprice': 'promotion_price',
            'reviewscore': 'review_score',
            'reviewcount': 'review_count',
            'deliveryestimate': 'delivery_estimate',
            'goldsupplieryears': 'supplier_years',
        };
        return mapping[normalized] || normalized;
    });

    console.log(`📋 Headers (${headers.length}):`, headers.slice(0, 10));

    const results = [];
    for (let i = 1; i < lines.length; i++) {
        const values = parseRow(lines[i], separator);
        const row = {};
        headers.forEach((header, index) => {
            row[header] = values[index] !== undefined ? values[index] : '';
        });
        results.push(row);
    }

    return results;
}

/**
 * Normalise une ligne brute vers le format standard attendu par l'import.
 * Supporte automatiquement :
 *   - Format Oli standard (name, price, images, ...)
 *   - Format Alibaba scraper (title, mainimage, moq, ...)
 *   - Format AliExpress scraper (title, pricing/0/dollarPrice, images/0..5, skuData, ...)
 */
function normalizeRow(row) {
    // Détecter le format AliExpress
    const isAliExpress = Object.keys(row).some(k => k.startsWith('pricing/') || k.startsWith('images/') || k.startsWith('skuData/'));

    if (!isAliExpress) {
        return row; // Formats Oli standard et Alibaba — déjà gérés par le mapping CSV
    }

    // ── Format AliExpress ────────────────────────────────────────────

    // Nom
    const name = (row['title'] || row['name'] || '').replace(/<[^>]*>/g, '').trim();

    // Prix : priorité au prix dollar
    const rawPrice =
        row['pricing/0/dollarPrice'] ||
        row['pricing/0/price'] ||
        row['pricing/0/min'] ||
        row['pricing/1/dollarPrice'] ||
        row['price'] || '0';
    const priceStr = String(rawPrice).replace(/[^\d.]/g, '');
    const price = parseFloat(priceStr) || 0;

    // Images : images/0 → images/10, thumb en fallback
    const imageKeys = Object.keys(row)
        .filter(k => /^images\/\d+$/.test(k))
        .sort((a, b) => parseInt(a.split('/')[1]) - parseInt(b.split('/')[1]));
    const imageUrls = imageKeys.map(k => row[k]).filter(url => url && url.startsWith('http'));
    const thumb = row['thumb'] || row['thumbnail'] || '';
    if (imageUrls.length === 0 && thumb.startsWith('http')) imageUrls.push(thumb);
    const imagesStr = imageUrls.slice(0, 6).join(';');

    // Marque : supplier/companyName ou supplier/companyname
    const brand =
        row['supplier/companyname'] ||
        row['supplier/companyName'] ||
        row['brand'] || row['marque'] || '';

    // Quantité : minOrder en priorité, puis quantity générique
    const rawQty = row['minorder'] || row['minOrder'] || row['quantity'] || row['stock'] || '10';
    const qty = parseInt(String(rawQty).replace(/[^\d]/g, '')) || 10;

    // Unité : orderUnit en priorité
    const unit = row['orderunit'] || row['orderUnit'] || row['unit'] || 'Pièce';

    // Délai de livraison : leadTimeInfo/0/processPeriod (en jours)
    const leadDays = row['leadtimeinfo/0/processperiod'] || row['leadTimeInfo/0/processPeriod'] || '';
    const delivery_time = leadDays ? `${leadDays} jours` : '';

    // URL source AliExpress (non scrapée, utile pour référence)
    const source_url = row['productdetailurl'] || row['productDetailUrl'] || '';

    // Description structurée depuis productProperties
    const propPairs = [];
    for (let pi = 0; pi <= 35; pi++) {
        const pName = row[`productproperties/${pi}/name`] || row[`productProperties/${pi}/name`] || '';
        const pVal = row[`productproperties/${pi}/value`] || row[`productProperties/${pi}/value`] || '';
        if (pName && pVal) propPairs.push(`${pName}: ${pVal}`);
    }
    // Infos ventes
    const salesVol = row['salesvolume'] || row['salesVolume'] || '';
    const reviews = row['reviewscount'] || row['reviewsCount'] || '';
    const evalScore = row['evaluation'] || '';
    const extras = [];
    if (salesVol) extras.push(`Ventes: ${salesVol}`);
    if (reviews) extras.push(`Avis: ${reviews}`);
    if (evalScore) extras.push(`Note: ${evalScore}/5`);

    const description = [
        ...propPairs,
        ...extras,
    ].join('\n');

    // Catégorie : depuis productProperties si possible
    const category = row['category'] || row['categorie'] || '';

    // Couleur principale : skuData/0 où name contient "couleur"
    // + liste de toutes les couleurs pour les variantes
    let color = '';
    const variantColors = []; // [{name, image}]
    for (let si = 0; si <= 3; si++) {
        const skuName = (row[`skudata/${si}/name`] || row[`skuData/${si}/name`] || '').toLowerCase();
        if (skuName.includes('couleur') || skuName.includes('color')) {
            for (let vi = 0; vi <= 80; vi++) {
                const vName = row[`skudata/${si}/values/${vi}/name`] || row[`skuData/${si}/values/${vi}/name`] || '';
                const vImg = row[`skudata/${si}/values/${vi}/img`] || row[`skuData/${si}/values/${vi}/img`] || '';
                if (vName) {
                    variantColors.push({ name: vName, image: vImg });
                    if (!color) color = vName; // première couleur = couleur principale
                }
            }
        }
        // Tailles
        if (skuName.includes('taille') || skuName.includes('size') || skuName.includes('volume') || skuName.includes('longueur')) {
            for (let vi = 0; vi <= 80; vi++) {
                const vName = row[`skudata/${si}/values/${vi}/name`] || row[`skuData/${si}/values/${vi}/name`] || '';
                if (vName) variantColors.push({ name: vName, type: 'size' });
            }
        }
    }

    // Condition : déduire depuis description ("Neuf" par défaut pour AliExpress)
    const condition = 'Neuf';

    return {
        name,
        price: String(price),
        images: imagesStr,
        description,
        category,
        brand,
        quantity: String(qty),
        unit,
        weight: '',
        color,
        delivery_time,
        source_url,
        condition,
        _variants: variantColors, // utilisé en interne pour créer les variantes
        _source: 'aliexpress',
    };
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
            client.release();
            return res.status(400).json({ error: 'Fichier CSV requis' });
        }

        const csvString = req.file.buffer.toString('utf-8');
        const rows = parseCSV(csvString);

        if (rows.length === 0) {
            client.release();
            return res.status(400).json({ error: 'Fichier CSV vide ou mal formaté' });
        }

        // Récupérer le shop du vendeur
        const shopResult = await client.query(
            'SELECT id FROM shops WHERE owner_id = $1 LIMIT 1',
            [req.user.id]
        );
        const shopId = shopResult.rows[0]?.id || null;

        // Créer un enregistrement d'import
        const importRecord = await client.query(`
            INSERT INTO import_history (seller_id, filename, total_rows, status)
            VALUES ($1, $2, $3, 'processing')
            RETURNING id
        `, [req.user.id, req.file.originalname, rows.length]);

        const importId = importRecord.rows[0].id;
        const sellerId = req.user.id;

        // ✅ Répondre IMMÉDIATEMENT — le traitement continue en arrière-plan
        res.json({
            success: true,
            import_id: importId,
            total: rows.length,
            message: `Import de ${rows.length} produits démarré. Rafraîchissez l'historique pour suivre la progression.`
        });

        // Libérer le client DB avant le traitement long
        client.release();

        // 🔄 Traitement en arrière-plan (après la réponse HTTP)
        setImmediate(async () => {
            const bgClient = await db.connect();
            let imported = 0;
            const errors = [];

            try {
                // Pas de transaction globale — auto-commit par produit
                // Ainsi une erreur sur 1 produit ne rollback pas les 499 autres

                for (let i = 0; i < rows.length; i++) {
                    const row = normalizeRow(rows[i]); // Auto-détecte Oli / Alibaba / AliExpress

                    try {
                        let name = row.name || row.nom || '';
                        const description = row.description || '';
                        let price = 0;
                        const rawPrice = row.price || row.prix || '0';

                        // Parser les formats de prix Alibaba: "$17.99-19.99", "$6.60", "$3-12"
                        const priceStr = rawPrice.replace(/[^\d.\-]/g, '');
                        if (priceStr.includes('-')) {
                            const parts = priceStr.split('-').map(Number).filter(n => !isNaN(n) && n > 0);
                            price = parts.length > 0 ? parts[0] : 0;
                        } else {
                            price = parseFloat(priceStr) || 0;
                        }

                        // Nettoyer les tags HTML
                        name = name.replace(/<[^>]*>/g, '').trim();

                        // Parser le MOQ Alibaba
                        let quantity = parseInt(row.quantity || row.stock || row.quantite || 0);
                        if (isNaN(quantity) || quantity === 0) {
                            const moqMatch = (row.quantity || '').match(/(\d[\d,]*)/);
                            quantity = moqMatch ? parseInt(moqMatch[1].replace(',', '')) : 10;
                        }

                        const category = row.category || row.categorie || '';
                        const brand = row.brand || row.marque || '';
                        const unit = row.unit || row.unite || 'Pièce';
                        const weight = row.weight || row.poids || '';
                        const color = row.color || row.couleur || '';
                        const condition = row.condition || 'Neuf';
                        const delivery_time = row.delivery_time || '';
                        const source_url = row.source_url || '';
                        const rawImages = row.images ? row.images.split(';').map(img => img.trim()).filter(img => img) : [];

                        // ☁️ Re-upload UNIQUEMENT si l'image vient d'un domaine CORS-problématique
                        const SKIP_REUPLOAD_DOMAINS = ['alicdn.com', 'aliexpress.com', 'cloudinary.com'];
                        const needsReupload = (url) => {
                            try {
                                const host = new URL(url).hostname;
                                return !SKIP_REUPLOAD_DOMAINS.some(d => host.endsWith(d));
                            } catch { return false; }
                        };

                        const images = [];
                        for (const imgUrl of rawImages.slice(0, 6)) {
                            if (needsReupload(imgUrl)) {
                                images.push(await reuploadToCloudinary(imgUrl));
                            } else {
                                images.push(imgUrl);
                            }
                        }

                        // 💱 Conversion USD → CDF si prix < 100
                        if (price > 0 && price < 100) {
                            const convertedPrice = await exchangeRateService.convertAmount(price, 'USD', 'CDF');
                            console.log(`💱 Prix converti: ${price} USD → ${convertedPrice} CDF`);
                            price = convertedPrice;
                        }

                        // Validation
                        if (!name) {
                            errors.push({ row: i + 2, field: 'name', error: 'Nom requis' });
                            continue;
                        }
                        // Produits AliExpress sans pricing : mettre 1 USD par défaut
                        if (isNaN(price) || price <= 0) {
                            if (row._source === 'aliexpress') {
                                price = 1;
                            } else {
                                errors.push({ row: i + 2, field: 'price', error: 'Prix invalide' });
                                continue;
                            }
                        }

                        const insertResult = await bgClient.query(`
                            INSERT INTO products (
                                seller_id, shop_id, name, description, price,
                                category, quantity, brand, unit, weight, images,
                                color, condition, delivery_time,
                                status, is_active, created_at, updated_at
                            ) VALUES (
                                $1, $2, $3, $4, $5,
                                $6, $7, $8, $9, $10, $11,
                                $12, $13, $14,
                                'draft', false, NOW(), NOW()
                            ) RETURNING id
                        `, [sellerId, shopId, name, description, price,
                            category, quantity, brand, unit, weight, images,
                            color, condition, delivery_time]);

                        const productId = insertResult.rows[0]?.id;

                        // Insérer les variantes couleurs/tailles depuis skuData
                        if (productId && row._variants && row._variants.length > 0) {
                            for (const variant of row._variants.slice(0, 20)) {
                                try {
                                    await bgClient.query(`
                                        INSERT INTO product_variants
                                            (product_id, type, value, stock_quantity, price_adjustment, is_active, created_at)
                                        VALUES ($1, $2, $3, $4, $5, true, NOW())
                                        ON CONFLICT DO NOTHING
                                    `, [
                                        productId,
                                        variant.type === 'size' ? 'size' : 'color',
                                        variant.name,
                                        quantity,
                                        0
                                    ]);
                                } catch (_) { /* ignorer les doublons */ }
                            }
                        }

                        imported++;

                        // Mise à jour partielle toutes les 10 lignes pour suivre la progression
                        if (imported % 10 === 0) {
                            await bgClient.query(`
                                UPDATE import_history
                                SET imported_count = $1, status = 'processing'
                                WHERE id = $2
                            `, [imported, importId]);
                        }

                    } catch (err) {
                        errors.push({ row: i + 2, error: err.message, data: row.name || row.nom || 'Inconnu' });
                    }
                }

            } catch (bgErr) {
                console.error('Background import error:', bgErr);
                errors.push({ row: 0, error: 'Erreur critique: ' + bgErr.message });
            } finally {
                // Marquer l'import comme terminé
                await bgClient.query(`
                    UPDATE import_history
                    SET imported_count = $1, error_count = $2, errors = $3,
                        status = $4, completed_at = NOW()
                    WHERE id = $5
                `, [imported, errors.length, JSON.stringify(errors),
                    errors.length === rows.length ? 'failed' : 'completed',
                    importId]);

                bgClient.release();
                console.log(`✅ Import ${importId} terminé: ${imported}/${rows.length} produits, ${errors.length} erreurs`);
            }
        });

    } catch (error) {
        try { client.release(); } catch (_) { }
        console.error('Error POST /import-export/import:', error);
        if (!res.headersSent) {
            res.status(500).json({ error: 'Erreur lors de l\'import' });
        }
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
