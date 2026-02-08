// Firebase Messaging Service Worker (pour les push en arrière-plan sur le Web)
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

// Gestion des messages en arrière-plan
messaging.onBackgroundMessage((payload) => {
    console.log('[SW] Push reçu en arrière-plan:', payload);

    const notificationTitle = payload.notification?.title || 'Oli';
    const notificationOptions = {
        body: payload.notification?.body || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});
