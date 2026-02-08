/**
 * Routes API pour la gestion des device tokens FCM
 * POST /device-tokens — Enregistrer un token
 * DELETE /device-tokens — Supprimer un token (déconnexion)
 */

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { requireAuth } = require('../middlewares/auth.middleware');

/**
 * POST /device-tokens
 * Enregistrer ou mettre à jour un token FCM
 */
router.post('/', requireAuth, async (req, res) => {
    try {
        const { token, platform } = req.body;
        const userId = req.user.id;

        if (!token) {
            return res.status(400).json({ error: 'Token requis' });
        }

        console.log(`📱 [POST /device-tokens] User ${userId}, platform: ${platform || 'android'}`);

        // Upsert: si le token existe déjà, on met à jour le user_id et la date
        await db.query(`
            INSERT INTO device_tokens (user_id, token, platform, updated_at)
            VALUES ($1, $2, $3, NOW())
            ON CONFLICT (token) 
            DO UPDATE SET user_id = $1, platform = $3, updated_at = NOW()
        `, [userId, token, platform || 'android']);

        console.log(`   ✅ Token enregistré pour user ${userId}`);

        res.json({ success: true, message: 'Token enregistré' });

    } catch (error) {
        console.error('❌ Erreur POST /device-tokens:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /device-tokens
 * Supprimer un token FCM (lors de la déconnexion)
 */
router.delete('/', requireAuth, async (req, res) => {
    try {
        const { token } = req.body;
        const userId = req.user.id;

        if (!token) {
            return res.status(400).json({ error: 'Token requis' });
        }

        console.log(`🗑️ [DELETE /device-tokens] User ${userId}`);

        const result = await db.query(
            'DELETE FROM device_tokens WHERE user_id = $1 AND token = $2',
            [userId, token]
        );

        console.log(`   ✅ ${result.rowCount} token(s) supprimé(s)`);

        res.json({ success: true, message: 'Token supprimé' });

    } catch (error) {
        console.error('❌ Erreur DELETE /device-tokens:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
