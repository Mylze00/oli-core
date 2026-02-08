/**
 * Service FCM — Envoi de push notifications via Firebase Cloud Messaging
 * S'intègre dans NotificationService.send() comme 3ème canal (DB + Socket.IO + FCM)
 */

const db = require('../config/db');

let admin = null;
let initialized = false;

class FcmService {
    /**
     * Initialiser Firebase Admin SDK
     * Utilise GOOGLE_APPLICATION_CREDENTIALS_JSON (variable Render) 
     * ou GOOGLE_APPLICATION_CREDENTIALS (fichier local)
     */
    init() {
        if (initialized) return;

        try {
            admin = require('firebase-admin');

            // Option 1: Variable d'environnement JSON (Render/production)
            if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
                const serviceAccount = JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
                admin.initializeApp({
                    credential: admin.credential.cert(serviceAccount)
                });
                console.log('✅ [FCM] Initialisé via GOOGLE_APPLICATION_CREDENTIALS_JSON');
                initialized = true;
                return;
            }

            // Option 2: Fichier service-account.json (dev local)
            const fs = require('fs');
            const path = require('path');
            const saPath = path.resolve(__dirname, '../../service-account.json');

            if (fs.existsSync(saPath)) {
                const serviceAccount = require(saPath);
                admin.initializeApp({
                    credential: admin.credential.cert(serviceAccount)
                });
                console.log('✅ [FCM] Initialisé via service-account.json');
                initialized = true;
                return;
            }

            console.warn('⚠️ [FCM] Pas de credentials Firebase trouvées. Push désactivé.');
            console.warn('   → Configurez GOOGLE_APPLICATION_CREDENTIALS_JSON ou service-account.json');
        } catch (error) {
            console.warn(`⚠️ [FCM] Initialisation échouée: ${error.message}`);
            console.warn('   → Les push notifications sont désactivées');
        }
    }

    /**
     * Envoyer un push à un utilisateur
     * @param {number} userId - ID utilisateur
     * @param {string} title - Titre de la notification
     * @param {string} body - Corps du message
     * @param {object} data - Données additionnelles
     */
    async sendToUser(userId, title, body, data = {}) {
        if (!initialized || !admin) {
            console.log(`⚠️ [FCM] Push ignoré (non initialisé) pour user ${userId}`);
            return;
        }

        try {
            // Récupérer les tokens FCM de l'utilisateur
            const result = await db.query(
                'SELECT token FROM device_tokens WHERE user_id = $1',
                [userId]
            );

            if (result.rows.length === 0) {
                console.log(`📱 [FCM] Aucun token pour user ${userId}`);
                return;
            }

            const tokens = result.rows.map(r => r.token);

            // Convertir toutes les valeurs data en strings (requis par FCM)
            const stringData = {};
            for (const [key, value] of Object.entries(data)) {
                if (value !== null && value !== undefined) {
                    stringData[key] = String(value);
                }
            }

            // Envoyer via multicast
            const message = {
                notification: { title, body },
                data: stringData,
                tokens: tokens,
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'oli_notifications',
                        sound: 'default',
                        priority: 'high',
                    }
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1,
                        }
                    }
                }
            };

            const response = await admin.messaging().sendEachForMulticast(message);

            console.log(`📱 [FCM] Push envoyé à user ${userId}: ${response.successCount}/${tokens.length} réussis`);

            // Nettoyer les tokens invalides
            if (response.failureCount > 0) {
                const tokensToRemove = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        const errorCode = resp.error?.code;
                        if (errorCode === 'messaging/invalid-registration-token' ||
                            errorCode === 'messaging/registration-token-not-registered') {
                            tokensToRemove.push(tokens[idx]);
                        }
                    }
                });

                if (tokensToRemove.length > 0) {
                    await db.query(
                        'DELETE FROM device_tokens WHERE token = ANY($1)',
                        [tokensToRemove]
                    );
                    console.log(`🧹 [FCM] ${tokensToRemove.length} tokens invalides supprimés`);
                }
            }

        } catch (error) {
            console.error(`❌ [FCM] Erreur envoi push user ${userId}:`, error.message);
        }
    }

    /**
     * Envoyer un push broadcast (à un topic)
     */
    async sendToTopic(topic, title, body) {
        if (!initialized || !admin) return;

        try {
            await admin.messaging().send({
                topic: topic,
                notification: { title, body },
            });
            console.log(`📢 [FCM] Push broadcast topic "${topic}": ${title}`);
        } catch (error) {
            console.error(`❌ [FCM] Erreur broadcast topic "${topic}":`, error.message);
        }
    }
}

module.exports = new FcmService();
