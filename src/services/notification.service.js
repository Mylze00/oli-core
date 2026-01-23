/**
 * Service de Notifications
 * Fournit des helpers pour créer et envoyer des notifications
 */

const notificationRepo = require('../repositories/notification.repository');

class NotificationService {
    /**
     * Créer et envoyer une notification
     * @param {number} userId - ID de l'utilisateur
     * @param {string} type - Type de notification
     * @param {string} title - Titre
     * @param {string} body - Corps du message
     * @param {object} data - Données additionnelles (optionnel)
     * @param {object} io - Instance Socket.io pour émettre en temps réel (optionnel)
     */
    async send(userId, type, title, body, data = null, io = null) {
        // Créer la notification en DB
        const notification = await notificationRepo.create(userId, type, title, body, data);

        // Émettre via Socket.io si disponible
        if (io) {
            const userRoom = `user_${userId}`;
            io.to(userRoom).emit('new_notification', notification);
            console.log(`   📡 Notification émise via Socket.io vers ${userRoom}`);
        }

        return notification;
    }

    /**
     * Notification de nouveau message
     */
    async sendMessageNotification(userId, senderName, messagePreview, io = null) {
        return this.send(
            userId,
            'message',
            `Nouveau message de ${senderName}`,
            messagePreview,
            { sender: senderName },
            io
        );
    }

    /**
     * Notification de mise à jour de commande
     */
    async sendOrderNotification(userId, orderId, status, io = null) {
        const statusMessages = {
            'confirmed': { title: 'Commande confirmée', body: `Votre commande #${orderId} a été confirmée` },
            'shipped': { title: 'Commande expédiée', body: `Votre commande #${orderId} est en route` },
            'delivered': { title: 'Commande livrée', body: `Votre commande #${orderId} a été livrée` },
            'cancelled': { title: 'Commande annulée', body: `Votre commande #${orderId} a été annulée` },
        };

        const message = statusMessages[status] || {
            title: 'Mise à jour de commande',
            body: `Votre commande #${orderId} a été mise à jour`
        };

        return this.send(
            userId,
            'order',
            message.title,
            message.body,
            { order_id: orderId, status },
            io
        );
    }

    /**
     * Notification d'offre spéciale
     */
    async sendOfferNotification(userId, offerTitle, offerBody, data = null, io = null) {
        return this.send(
            userId,
            'offer',
            `🎉 ${offerTitle}`,
            offerBody,
            data,
            io
        );
    }

    /**
     * Annonce importante (broadcast à tous les users)
     */
    async sendAnnouncement(title, body, io = null) {
        if (io) {
            io.emit('announcement', {
                type: 'announcement',
                title: `📢 ${title}`,
                body: body,
                created_at: new Date()
            });
            console.log(`📢 Annonce broadcast à tous: ${title}`);
        }
    }

    /**
     * Notification système
     */
    async sendSystemNotification(userId, title, body, data = null, io = null) {
        return this.send(
            userId,
            'system',
            `⚙️ ${title}`,
            body,
            data,
            io
        );
    }
}

module.exports = new NotificationService();
