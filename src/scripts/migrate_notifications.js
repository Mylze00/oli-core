/**
 * Migration: Création de la table notifications
 * Usage: node src/scripts/migrate_notifications.js
 */

require('dotenv').config();
const pool = require('../config/db');

async function migrate() {
    console.log('🔄 Migration des notifications - START');

    try {
        // Créer la table notifications
        await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(50) NOT NULL CHECK (type IN ('message', 'order', 'offer', 'announcement', 'system')),
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        data JSONB,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
        console.log('✅ Table notifications créée');

        // Créer les index pour optimiser les requêtes
        await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_notifications_user 
      ON notifications(user_id)
    `);
        console.log('✅ Index idx_notifications_user créé');

        await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_notifications_unread 
      ON notifications(user_id, is_read)
    `);
        console.log('✅ Index idx_notifications_unread créé');

        await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_notifications_created 
      ON notifications(created_at DESC)
    `);
        console.log('✅ Index idx_notifications_created créé');

        console.log('🎉 Migration terminée avec succès!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Erreur lors de la migration:', error);
        process.exit(1);
    }
}

migrate();
