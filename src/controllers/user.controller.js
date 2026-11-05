const userService = require('../services/user.service');
const pool = require('../config/db');

exports.getVisitedProducts = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;
        const products = await userService.getVisitedProducts(req.user.id, limit);
        res.json(products);
    } catch (error) {
        console.error('Erreur /user/visited-products:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.trackProductView = async (req, res) => {
    try {
        const productId = parseInt(req.params.productId);

        if (!productId || isNaN(productId)) {
            return res.status(400).json({ error: 'Product ID invalide' });
        }

        await userService.trackProductView(req.user.id, productId);
        res.json({ success: true, message: 'Vue enregistrée' });
    } catch (error) {
        console.error('Erreur /user/track-view:', error);
        // On retourne quand même success pour ne pas bloquer l'UX
        res.json({ success: true, message: 'Vue non enregistrée' });
    }
};

exports.updateName = async (req, res) => {
    try {
        const { name } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Le nom est requis' });
        }

        const updatedUser = await userService.updateUserName(req.user.id, name);
        res.json({
            success: true,
            message: 'Nom mis à jour',
            user: updatedUser
        });
    } catch (error) {
        console.error('Erreur /user/update-name:', error);
        res.status(400).json({ error: error.message });
    }
};

exports.getPublicProfile = async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        if (!userId || isNaN(userId)) {
            return res.status(400).json({ error: 'ID utilisateur invalide' });
        }

        const profile = await userService.getPublicProfile(userId);
        if (!profile) {
            return res.status(404).json({ error: 'Utilisateur introuvable' });
        }

        res.json(profile);
    } catch (error) {
        console.error('Erreur /user/public-profile:', error);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

/**
 * DELETE /user/account
 * Suppression du compte (anonymisation). Exige la confirmation explicite
 * { "confirm": "SUPPRIMER" } pour éviter tout appel accidentel.
 */
exports.deleteAccount = async (req, res) => {
    try {
        if (req.body?.confirm !== 'SUPPRIMER') {
            return res.status(400).json({
                success: false,
                error: 'Confirmation requise : envoyez { "confirm": "SUPPRIMER" }',
            });
        }

        const accountService = require('../services/account.service');
        const result = await accountService.deleteAccount(req.user.id);

        if (result.notFound) {
            return res.status(404).json({ success: false, error: 'Compte introuvable' });
        }
        if (result.blockers && result.blockers.length > 0) {
            return res.status(409).json({
                success: false,
                error: 'Suppression impossible pour le moment',
                reasons: result.blockers,
            });
        }

        return res.json({
            success: true,
            message: 'Votre compte a été supprimé. Vos informations personnelles ont été effacées.',
        });
    } catch (error) {
        console.error('Erreur DELETE /user/account:', error);
        res.status(500).json({ success: false, error: 'Erreur serveur' });
    }
};

// ── Préférences de notification ─────────────────────────────────────────────
const NOTIFICATION_KEYS = ['push', 'email', 'sms'];
const DEFAULT_NOTIFICATION_PREFS = { push: true, email: true, sms: false };

/**
 * GET /user/notification-preferences
 */
exports.getNotificationPreferences = async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT notification_prefs FROM users WHERE id = $1',
            [req.user.id]
        );
        if (rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Utilisateur introuvable' });
        }
        res.json({ ...DEFAULT_NOTIFICATION_PREFS, ...(rows[0].notification_prefs || {}) });
    } catch (error) {
        console.error('Erreur GET /user/notification-preferences:', error);
        res.status(500).json({ success: false, error: 'Erreur serveur' });
    }
};

/**
 * PUT /user/notification-preferences
 * Body partiel accepté : { push?: boolean, email?: boolean, sms?: boolean }
 */
exports.updateNotificationPreferences = async (req, res) => {
    try {
        const body = req.body || {};
        const patch = {};
        for (const key of NOTIFICATION_KEYS) {
            if (Object.prototype.hasOwnProperty.call(body, key)) {
                if (typeof body[key] !== 'boolean') {
                    return res.status(400).json({ success: false, error: `"${key}" doit être un booléen` });
                }
                patch[key] = body[key];
            }
        }
        if (Object.keys(patch).length === 0) {
            return res.status(400).json({ success: false, error: 'Aucune préférence valide fournie' });
        }

        const { rows } = await pool.query(
            `UPDATE users
             SET notification_prefs = COALESCE(notification_prefs, '{}'::jsonb) || $2::jsonb,
                 updated_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL
             RETURNING notification_prefs`,
            [req.user.id, JSON.stringify(patch)]
        );
        if (rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Utilisateur introuvable' });
        }
        res.json({ ...DEFAULT_NOTIFICATION_PREFS, ...rows[0].notification_prefs });
    } catch (error) {
        console.error('Erreur PUT /user/notification-preferences:', error);
        res.status(500).json({ success: false, error: 'Erreur serveur' });
    }
};
