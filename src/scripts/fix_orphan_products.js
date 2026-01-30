const db = require('../config/db');

async function fixOrphanProducts() {
    try {
        console.log('🚀 Démarrage du script de correction (Produits & Boutique)...');

        // 1. Vérifier et Ajouter la colonne shop_id si manquante
        try {
            await db.query('SELECT shop_id FROM products LIMIT 1');
            console.log('✅ La colonne shop_id existe déjà.');
        } catch (err) {
            if (err.code === '42703') { // undefined_column
                console.log('🔧 Colonne shop_id manquante. Ajout en cours...');
                // Ajout simple sans contrainte FK stricte pour éviter les erreurs de relation si la table shops est dans un état complexe
                try {
                    await db.query(`ALTER TABLE products ADD COLUMN shop_id UUID;`);
                    console.log('✅ Colonne shop_id ajoutée avec succès.');
                } catch (alterErr) {
                    console.error('❌ Echec critique ajout colonne:', alterErr.message);
                }
            } else {
                console.warn('⚠️ Erreur inattendue lors de la vérification de colonne:', err.message);
            }
        }

        // 2. Correction des produits orphelins
        console.log('🔍 Analyse des produits sans boutique...');

        const orphans = await db.query(`
            SELECT p.id, p.seller_id, p.name 
            FROM products p 
            WHERE p.shop_id IS NULL AND p.status != 'deleted'
        `);

        if (orphans.rows.length === 0) {
            console.log('✅ Aucun produit orphelin actif trouvé. Tout semble correct.');
            process.exit(0);
        }

        console.log(`⚠️ ${orphans.rows.length} produits orphelins trouvés. Tentative de liaison automatique...`);

        let fixedCount = 0;

        for (const product of orphans.rows) {
            try {
                // Trouver la boutique du vendeur
                const shop = await db.query('SELECT id FROM shops WHERE owner_id = $1', [product.seller_id]);

                if (shop.rows.length > 0) {
                    const shopId = shop.rows[0].id;
                    await db.query('UPDATE products SET shop_id = $1 WHERE id = $2', [shopId, product.id]);
                    console.log(`✅ [FIXED] Produit "${product.name}" -> Boutique ${shopId}`);
                    fixedCount++;
                } else {
                    console.warn(`❌ [WARN] Pas de boutique trouvée pour le vendeur ${product.seller_id} (Produit: ${product.name})`);
                }
            } catch (e) {
                console.error(`❌ Erreur traitement produit ${product.id}:`, e.message);
            }
        }

        console.log(`🎉 Opération terminée ! ${fixedCount}/${orphans.rows.length} produits corrigés et visibles.`);
    } catch (error) {
        console.error('❌ Erreur fatale du script:', error);
    } finally {
        process.exit();
    }
}

fixOrphanProducts();
