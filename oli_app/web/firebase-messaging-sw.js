// Firebase Messaging Service Worker — OLI App
// Gère les push notifications web (Chrome) même quand l'app est fermée
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "AIzaSyDQMF7DsuTE4-2TlkzA9ZC96fjIzYX3wpc",
    authDomain: "oli-core.firebaseapp.com",
    projectId: "oli-core",
    storageBucket: "oli-core.firebasestorage.app",
    messagingSenderId: "1045211732966",
    appId: "1:1045211732966:web:af7f43365f187d500b1427",
});

const messaging = firebase.messaging();

// ── Gestion des messages en arrière-plan (Chrome fermé ou en BG) ─────────────
messaging.onBackgroundMessage((payload) => {
    console.log('[OLI SW] Push reçu en arrière-plan:', payload);

    const data = payload.data || {};
    const isCall = data.oli_notification_type === 'incoming_call';

    let title, body, actions, tag, requireInteraction;

    if (isCall) {
        const callerName = data.caller_name || 'Utilisateur OLI';
        const callType   = data.call_type === 'video' ? 'vidéo' : 'audio';

        title             = `📞 Appel ${callType} entrant`;
        body              = `${callerName} vous appelle`;
        tag               = 'oli-incoming-call';
        requireInteraction = true; // Reste visible, ne disparaît pas automatiquement
        actions           = [
            { action: 'accept', title: '✅ Décrocher' },
            { action: 'reject', title: '❌ Refuser'   },
        ];
    } else {
        title             = payload.notification?.title || data.title || 'OLI';
        body              = payload.notification?.body  || data.body  || '';
        tag               = 'oli-notification';
        requireInteraction = false;
        actions           = [];
    }

    return self.registration.showNotification(title, {
        body,
        icon:              '/icons/Icon-192.png',
        badge:             '/icons/Icon-192.png',
        tag,
        requireInteraction,
        vibrate:           isCall ? [200, 100, 200, 100, 200] : [200],
        data:              { ...data, url: '/chat' },
        actions,
    });
});

// ── Tap sur la notification ──────────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
    const notification = event.notification;
    const action       = event.action;
    const data         = notification.data || {};

    notification.close();

    // Si c'est un appel
    if (data.oli_notification_type === 'incoming_call') {
        if (action === 'reject') {
            // Envoyer un event au client Flutter pour refuser
            event.waitUntil(
                self.clients.matchAll({ type: 'window' }).then((clients) => {
                    clients.forEach(client => client.postMessage({
                        type: 'call_rejected',
                        callerId: data.caller_id,
                    }));
                })
            );
            return;
        }

        // Action "accept" ou tap direct → ouvrir/focus l'app avec les données d'appel
        const targetUrl = `/?call_incoming=1&caller_id=${data.caller_id || ''}&caller_name=${encodeURIComponent(data.caller_name || '')}&call_type=${data.call_type || 'audio'}&conversation_id=${data.conversation_id || ''}`;

        event.waitUntil(
            self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
                // Si l'app est déjà ouverte → focus + message
                for (const client of clients) {
                    if ('focus' in client) {
                        client.focus();
                        client.postMessage({
                            type: 'incoming_call',
                            callerId:       data.caller_id,
                            callerName:     data.caller_name,
                            callerAvatar:   data.caller_avatar,
                            callType:       data.call_type,
                            conversationId: data.conversation_id,
                        });
                        return;
                    }
                }
                // Sinon → ouvrir une nouvelle fenêtre
                if (self.clients.openWindow) {
                    return self.clients.openWindow(targetUrl);
                }
            })
        );
    } else {
        // Notification standard → ouvrir l'app
        event.waitUntil(
            self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
                if (clients.length > 0) {
                    return clients[0].focus();
                }
                return self.clients.openWindow('/');
            })
        );
    }
});
