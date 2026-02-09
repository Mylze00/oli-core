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

/**
 * GET /setup/migrate-exchange-rates
 * Route utilitaire pour créer la table 'exchange_rates'
 */
router.get('/migrate-exchange-rates', async (req, res) => {
    try {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Création de la table exchange_rates
            await client.query(`
                CREATE TABLE IF NOT EXISTS exchange_rates (
                    id SERIAL PRIMARY KEY,
                    base_currency VARCHAR(3) DEFAULT 'USD',
                    target_currency VARCHAR(3) NOT NULL,
                    rate NUMERIC(12, 6) NOT NULL,
                    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    source VARCHAR(50) DEFAULT 'exchangerate-api'
                );
            `);
            console.log('✅ Table "exchange_rates" créée.');

            // Créer un index unique sur la date (sans heure) pour éviter les doublons par jour
            await client.query(`
                CREATE UNIQUE INDEX IF NOT EXISTS unique_rate_per_day 
                ON exchange_rates (base_currency, target_currency, CAST(fetched_at AS DATE));
            `);
            console.log('✅ Index unique créé.');

            // Créer les autres index
            await client.query(`
                CREATE INDEX IF NOT EXISTS idx_exchange_rates_currencies 
                    ON exchange_rates(base_currency, target_currency);
            `);
            await client.query(`
                CREATE INDEX IF NOT EXISTS idx_exchange_rates_fetched_at 
                    ON exchange_rates(fetched_at DESC);
            `);
            console.log('✅ Index créés.');

            // Insérer un taux par défaut
            await client.query(`
                INSERT INTO exchange_rates (base_currency, target_currency, rate, source)
                VALUES ('USD', 'CDF', 2800.00, 'default');
            `);
            console.log('✅ Taux par défaut inséré.');

            await client.query('COMMIT');
            res.json({
                success: true,
                message: 'Table exchange_rates créée avec succès ! 🎉',
                next_step: 'Le système de taux de change est maintenant opérationnel.'
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur Migration Exchange Rates:', err);
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
});

/**
 * GET /setup/migrate-device-tokens
 * Route utilitaire pour créer la table 'device_tokens' (FCM)
 */
router.get('/migrate-device-tokens', async (req, res) => {
    try {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            await client.query(`
                CREATE TABLE IF NOT EXISTS device_tokens (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    token TEXT NOT NULL UNIQUE,
                    platform VARCHAR(20) DEFAULT 'android',
                    created_at TIMESTAMP DEFAULT NOW(),
                    updated_at TIMESTAMP DEFAULT NOW()
                );
            `);
            console.log('✅ Table "device_tokens" créée.');

            await client.query(`
                CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
            `);
            console.log('✅ Index créé.');

            await client.query('COMMIT');
            res.json({
                success: true,
                message: 'Table device_tokens créée avec succès ! 📱🔔'
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur Migration device_tokens:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

/**
 * GET /setup/migrate-user-hidden
 * Ajoute la colonne is_hidden pour masquer des utilisateurs du marketplace
 */
router.get('/migrate-user-hidden', async (req, res) => {
    try {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            await client.query(`
                ALTER TABLE users 
                ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;
            `);
            console.log('✅ Colonne "is_hidden" ajoutée à "users".');

            await client.query(`
                CREATE INDEX IF NOT EXISTS idx_users_is_hidden 
                ON users(is_hidden) 
                WHERE is_hidden = TRUE;
            `);
            console.log('✅ Index créé.');

            await client.query('COMMIT');
            res.json({
                success: true,
                message: 'Colonne is_hidden ajoutée avec succès ! 👁️'
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur Migration user hidden:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
