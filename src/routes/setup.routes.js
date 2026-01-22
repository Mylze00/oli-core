const express = require('express');
const router = express.Router();
const pool = require('../config/db');

/**
 * GET /setup/ads-db
 * Route utilitaire pour créer la table 'ads' et modifier 'products'
 */
router.get('/ads-db', async (req, res) => {
    try {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // 1. Création de la table 'ads'
            await client.query(`
                CREATE TABLE IF NOT EXISTS ads (
                    id SERIAL PRIMARY KEY,
                    image_url TEXT NOT NULL,
                    title TEXT,
                    link_url TEXT,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            `);
            console.log('✅ Table "ads" vérifiée/créée.');

            // 2. Modification de la table 'products' pour "Bon Deal"
            await client.query(`
                ALTER TABLE products 
                ADD COLUMN IF NOT EXISTS is_good_deal BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS promo_price NUMERIC(10, 2);
            `);
            console.log('✅ Colonnes "is_good_deal" et "promo_price" ajoutées à "products".');

            await client.query('COMMIT');
            res.json({ message: 'Base de données mise à jour avec succès pour Pubs & Bons Deals ! 🚀' });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur Setup DB:', err);
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
