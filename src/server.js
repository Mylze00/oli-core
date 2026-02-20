/**
 * Serveur Principal Oli
 * Super-App RDC - Marketplace, Chat, Paiements, Livraison
 */
const express = require("express");
const http = require('http');
const { Server } = require("socket.io");
const cors = require("cors");
const helmet = require("helmet");
const jwt = require("jsonwebtoken");

// Configuration
const config = require("./config");

// Initialiser FCM
const fcmService = require('./services/fcm.service');
fcmService.init();


// Routes
const authRoutes = require("./routes/auth.routes");
const productsRoutes = require("./routes/products.routes");
const ordersRoutes = require("./routes/orders.routes");
const chatRoutes = require("./routes/chat.routes");
const shopsRoutes = require("./routes/shops.routes");
const walletRoutes = require("./routes/wallet.routes");
const deliveryRoutes = require("./routes/delivery.routes");
const delivererApplicationRoutes = require("./routes/deliverer-application.routes");
const userRoutes = require("./routes/user.routes");
const adminRoutes = require("./routes/admin.routes"); // ✨ Routes admin
const sellerRoutes = require("./routes/seller.routes"); // ✨ Routes vendeur
const paymentRoutes = require("./routes/payment.routes"); // 💳 Routes Paiement (Simulé)
const { requireAuth, optionalAuth } = require("./middlewares/auth.middleware");

const app = express();
const server = http.createServer(app);

// --- SOCKET.IO CONFIG ---
const io = new Server(server, {
    cors: {
        origin: config.ALLOWED_ORIGINS,
        methods: ["GET", "POST"]
    }
});

app.set('io', io);

// --- SOCKET.IO AUTH MIDDLEWARE ---
io.use((socket, next) => {
    const token = (socket.handshake.auth && socket.handshake.auth.token)
        || socket.handshake.headers.authorization;

    if (!token) {
        console.warn("[SOCKET] Pas de token fourni");
        return next(new Error("No authentication token"));
    }

    const cleanToken = token.replace("Bearer ", "");
    try {
        const decoded = jwt.verify(cleanToken, config.JWT_SECRET, {
            ignoreExpiration: false  // ✅ Vérifier l'expiration
        });
        socket.user = decoded;
        console.log(`✅ [SOCKET] User ${decoded.id} authentifié`);
        next();
    } catch (err) {
        console.warn(`❌ [SOCKET] Échec auth : ${err.message}`);
        if (err.name === 'TokenExpiredError') {
            return next(new Error("Token expired - please refresh"));
        }
        next(new Error("Authentication error"));
    }
});

// --- SOCKET.IO EVENTS ---
io.on('connection', (socket) => {
    const userId = socket.user ? socket.user.id : null;

    if (userId) {
        // IMPORTANT : On utilise une syntaxe simple et constante
        const userRoom = `user_${userId}`;
        socket.join(userRoom);
        console.log(`✅ Room rejointe : ${userRoom}`);

        io.emit('user_online', { userId, online: true });
    }

    // 3. LE JOIN MANUEL (Amélioré)
    socket.on('join', (roomName) => {
        if (roomName.startsWith('user_')) {
            const requestedId = roomName.replace('user_', '');
            if (userId && userId.toString() === requestedId.toString()) {
                socket.join(roomName);
                console.log(`👤 Manual Join: Room ${roomName} confirmée`);
            }
        } else if (roomName.startsWith('conversation_')) {
            socket.join(roomName);
            console.log(`💬 Joined Chat Room: ${roomName}`);
        }
    });

    socket.on('join_conversation', (conversationId) => {
        socket.join(`conversation_${conversationId}`);
        console.log(`💬 Client dans la conversation : ${conversationId}`);
    });

    // 4. INDICATEUR DE FRAPPE (Typing)
    socket.on('typing', ({ conversationId, isTyping }) => {
        if (userId) {
            socket.to(`conversation_${conversationId}`).emit('user_typing', {
                userId,
                conversationId,
                isTyping
            });
        }
    });

    socket.on('disconnect', () => {
        if (userId) {
            io.emit('user_online', { userId, online: false });
            console.log(`❌ User ${userId} déconnecté`);
        }
    });
});


// --- MIDDLEWARES GÉNÉRAUX ---
const corsOptions = {
    origin: function (origin, callback) {
        // Allow requests with no origin (mobile apps, curl, etc)
        if (!origin) return callback(null, true);
        if (config.ALLOWED_ORIGINS.includes('*') || config.ALLOWED_ORIGINS.includes(origin)) {
            callback(null, true);
        } else {
            console.error(`❌ CORS blocked origin: ${origin}`);
            console.error(`   Allowed origins: ${JSON.stringify(config.ALLOWED_ORIGINS)}`);
            callback(new Error(`CORS not allowed for origin: ${origin}`));
        }
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "authorization", "X-Requested-With", "Accept"],
    exposedHeaders: ["Content-Type", "Authorization"]
};
app.use(cors(corsOptions));

app.options('*', cors(corsOptions));

// Logging middleware
if (config.NODE_ENV !== 'production') {
    app.use((req, res, next) => {
        if (req.method !== 'GET') {
            console.log(`[DEBUG] ${req.method} ${req.url}`, req.body ? Object.keys(req.body) : '');
        }
        next();
    });
}

app.use(helmet({ contentSecurityPolicy: false }));
app.use("/api/payment", require('./routes/stripe-webhook.routes')); // 🔔 Stripe Webhook (simulation mode)
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// --- ROUTES API ---

// Auth (public)
app.use("/auth", authRoutes);



app.use("/products", optionalAuth, productsRoutes);
app.use("/api/shops", optionalAuth, shopsRoutes);
app.use("/orders", requireAuth, ordersRoutes);
app.use("/wallet", requireAuth, walletRoutes);
app.use("/delivery", requireAuth, deliveryRoutes);
app.use("/delivery/apply", requireAuth, delivererApplicationRoutes);
app.use("/chat", requireAuth, chatRoutes);

// 🆕 Route publique pour le profil vendeur (pas besoin d'auth)
app.get("/user/public-profile/:id", require('./controllers/user.controller').getPublicProfile);

// Autres routes user (protégées)
app.use("/user", requireAuth, userRoutes);
app.use("/addresses", requireAuth, require('./routes/address.routes'));
app.use("/notifications", require('./routes/notifications.routes')); // Notifications
app.use("/device-tokens", require('./routes/device-tokens.routes')); // 📱 Tokens FCM

// 🆕 Routes pour l'architecture utilisateur unifiée
app.use("/api/identity", require('./routes/identity.routes'));
app.use("/api/verification", require('./routes/verification.routes'));
app.use("/api/behavior", require('./routes/behavior.routes'));
app.use("/api/trust-score", require('./routes/trust-score.routes'));
app.use("/api/exchange-rate", require('./routes/exchange-rate.routes')); // 💱 Taux de change
app.use("/api/delivery-methods", require('./routes/delivery-methods.routes')); // 🚚 Méthodes de livraison
app.use("/api/subscription", require('./routes/subscription.routes')); // 🆕 Abonnement & Certification
app.use("/api/product-requests", require('./routes/product-requests.routes')); // 📦 Demandes de produit

app.use("/admin", adminRoutes); // ✨ Routes admin (protection dans admin.routes.js)
app.use("/api/seller", sellerRoutes); // ✨ Routes vendeur (protection dans seller.routes.js)
app.use("/api/analytics", require('./routes/analytics.routes')); // 📊 Analytics vendeur
app.use("/api/import-export", require('./routes/import-export.routes')); // 📥 Import/Export CSV
app.use("/api/variants", require('./routes/variants.routes')); // 🎨 Variantes produits
app.use("/api/seller/orders", require('./routes/seller-orders.routes')); // 📦 Commandes vendeur
app.use("/api/reports", require('./routes/reports.routes')); // 📊 Rapports avancés
app.use("/api/coupons", require('./routes/coupons.routes')); // 🎫 Coupons promo
app.use("/api/loyalty", require('./routes/loyalty.routes')); // ⭐ Programme fidélité
app.use("/api/payment", paymentRoutes); // 💳 Paiement Stripe (Simulé)
app.use("/admin/ads", adminRoutes); // Mounting admin ads handled inside admin.routes?? No, I created src/routes/admin/ads.routes.js
// Let's mount explicit paths
app.use("/ads", require("./routes/ads.routes"));
app.use('/search', require('./routes/search.routes')); // Recherche visuelle
app.use("/setup", require("./routes/setup.routes")); // Utility route for migration
app.use("/services", require("./routes/services.routes")); // ✨ Services dynamiques (Public)
app.use("/support", requireAuth, require("./routes/support.routes")); // 🎫 Support tickets utilisateur
app.use("/api/debug", require("./routes/debug.routes")); // 🐞 Debug DB Schema (Temporary)
app.use("/api/videos", requireAuth, require('./routes/video-sales.routes')); // 🎬 Live Shopping vidéos

// Health check
app.get("/health", (req, res) => {
    res.json({
        status: "ok",
        version: "1.0.0",
        environment: config.NODE_ENV
    });
});

// --- GESTION DES ERREURS ---
app.use((err, req, res, next) => {
    console.error("❌ ERREUR SERVEUR GLOBALE :");
    console.error("- Message:", err.message);
    console.error("- Stack:", err.stack);
    console.error("- Path:", req.path);
    console.error("- Method:", req.method);

    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ error: "Fichier trop volumineux (max 50MB)" });
    }

    res.status(err.status || 500).json({
        error: "Erreur serveur interne",
        message: err.message,
        path: req.path
    });
});

// --- CRON JOB: Mise à jour quotidienne des taux de change ---
const exchangeRateService = require('./services/exchange-rate.service');
const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000; // 24 heures en millisecondes

// Mise à jour initiale au démarrage
exchangeRateService.fetchLiveRate('USD').catch(err => {
    console.error('❌ Erreur lors de la mise à jour initiale des taux:', err.message);
});

// Mise à jour quotidienne
setInterval(() => {
    exchangeRateService.updateRatesDaily();
}, TWENTY_FOUR_HOURS);

// --- DÉMARRAGE DU SERVEUR ---
server.listen(config.PORT, "0.0.0.0", () => {
    console.log(`🚀 OLI SERVER v1.0 - Port ${config.PORT} (${config.NODE_ENV})`);
    console.log(`📡 WebSocket ready`);
    console.log(`🌐 Base URL: ${config.BASE_URL}`);
    console.log(`💱 Exchange rate auto-update: every 24h`);
});
