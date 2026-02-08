/**
 * Migration: Table device_tokens pour stocker les tokens FCM
 */

const path = require('path');
const db = require(path.join(__dirname, '..', 'config', 'db'));

async function migrate() {
    console.log('📱 Migration device_tokens...');

    try {
        await db.query(`
            CREATE TABLE IF NOT EXISTS device_tokens (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token TEXT NOT NULL UNIQUE,
                platform VARCHAR(20) DEFAULT 'android',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        `);

        // Index pour recherche rapide par user_id
        await db.query(`
            CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
        `);

        console.log('✅ Table device_tokens créée avec succès');
    } catch (error) {
        console.error('❌ Erreur migration device_tokens:', error.message);
        throw error;
    }
}

migrate()
    .then(() => {
        console.log('✅ Migration terminée');
        process.exit(0);
    })
    .catch((err) => {
        console.error('❌ Migration échouée:', err);
        process.exit(1);
    });
