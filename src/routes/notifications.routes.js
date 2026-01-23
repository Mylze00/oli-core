/**
 * Routes API pour les notifications
 */

const express = require('express');
const router = express.Router();
const notificationRepo = require('../repositories/notification.repository');
const { requireAuth } = require('../middlewares/auth.middleware');

/**
 * GET /notifications
 * Récupérer toutes les notifications de l'utilisateur connecté
 */
router.get('/', requireAuth, async (req, res) => {
    try {
        console.log(`📥 [GET /notifications] User ${req.user.id}`);

        const notifications = await notificationRepo.findByUser(req.user.id);
        const unreadCount = await notificationRepo.countUnread(req.user.id);

        console.log(`   - ${notifications.length} notifications trouvées`);
        console.log(`   - ${unreadCount} non lues`);

        res.json({
            success: true,
            notifications,
            unreadCount
        });
    } catch (error) {
        console.error('❌ Erreur GET /notifications:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /notifications/unread-count
 * Récupérer uniquement le nombre de notifications non lues
 */
router.get('/unread-count', requireAuth, async (req, res) => {
    try {
        const count = await notificationRepo.countUnread(req.user.id);

        res.json({
            success: true,
            count
        });
    } catch (error) {
        console.error('❌ Erreur GET /notifications/unread-count:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * PUT /notifications/:id/read
 * Marquer une notification comme lue
 */
router.put('/:id/read', requireAuth, async (req, res) => {
    try {
        console.log(`📖 [PUT /notifications/${req.params.id}/read] User ${req.user.id}`);

        const notification = await notificationRepo.markAsRead(req.params.id, req.user.id);

        if (!notification) {
            return res.status(404).json({ error: 'Notification not found' });
        }

        res.json({
            success: true,
            notification
        });
    } catch (error) {
        console.error('❌ Erreur PUT /notifications/:id/read:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * PUT /notifications/read-all
 * Marquer toutes les notifications comme lues
 */
router.put('/read-all', requireAuth, async (req, res) => {
    try {
        console.log(`📖 [PUT /notifications/read-all] User ${req.user.id}`);

        const count = await notificationRepo.markAllAsRead(req.user.id);

        console.log(`   - ${count} notifications marquées comme lues`);

        res.json({
            success: true,
            message: 'All notifications marked as read',
            count
        });
    } catch (error) {
        console.error('❌ Erreur PUT /notifications/read-all:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * DELETE /notifications/:id
 * Supprimer une notification
 */
router.delete('/:id', requireAuth, async (req, res) => {
    try {
        console.log(`🗑️ [DELETE /notifications/${req.params.id}] User ${req.user.id}`);

        const deleted = await notificationRepo.delete(req.params.id, req.user.id);

        if (!deleted) {
            return res.status(404).json({ error: 'Notification not found' });
        }

        res.json({
            success: true,
            message: 'Notification deleted'
        });
    } catch (error) {
        console.error('❌ Erreur DELETE /notifications/:id:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * DELETE /notifications/read
 * Supprimer toutes les notifications lues
 */
router.delete('/read', requireAuth, async (req, res) => {
    try {
        console.log(`🗑️ [DELETE /notifications/read] User ${req.user.id}`);

        const count = await notificationRepo.deleteAllRead(req.user.id);

        console.log(`   - ${count} notifications supprimées`);

        res.json({
            success: true,
            message: 'Read notifications deleted',
            count
        });
    } catch (error) {
        console.error('❌ Erreur DELETE /notifications/read:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
