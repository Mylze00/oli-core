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

// Configuration centralisée
const config = require("./config");
const pool = require("./config/db");
const { uploadDir } = require("./config/upload");

// Middlewares
const { requireAuth, optionalAuth } = require("./middlewares/auth.middleware");

// Routes
const authRoutes = require("./routes/auth.routes");
const productsRoutes = require("./routes/products.routes");
const ordersRoutes = require("./routes/orders.routes");
const chatRoutes = require("./routes/chat.routes");
const shopsRoutes = require("./routes/shops.routes");
const walletRoutes = require("./routes/wallet.routes");
const deliveryRoutes = require("./routes/delivery.routes");

// --- INITIALISATION ---
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
        console.log("Socket connection attempt without token (Anonyme)");
        return next();
    }

    const cleanToken = token.replace("Bearer ", "");
    try {
        const decoded = jwt.verify(cleanToken, config.JWT_SECRET);
        socket.user = decoded;
        next();
    } catch (err) {
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

    socket.on('join_conversation', (conversationId) => {
        socket.join(`conversation_${conversationId}`);
        console.log(`💬 Client dans la conversation : ${conversationId}`);
    });

    socket.on('disconnect', () => {
        if (userId) {
            io.emit('user_online', { userId, online: false });
        }
    });
});

// 3. LE JOIN MANUEL (Amélioré)
// Utile si tu veux aussi rejoindre des rooms de conversation spécifiques (ex: conversation_12)
socket.on('join', (roomName) => {
    // Sécurité : Un utilisateur ne peut rejoindre que sa propre room "user_ID"
    // ou une room de "conversation_ID" dont il fait partie
    if (roomName.startsWith('user_')) {
        const requestedId = roomName.replace('user_', '');
        if (userId && userId.toString() === requestedId.toString()) {
            socket.join(roomName);
            console.log(`👤 Manual Join: Room ${roomName} confirmée`);
        }
    } else if (roomName.startsWith('conversation_')) {
        // Permet de rejoindre une room de chat précise pour les indicateurs de frappe
        socket.join(roomName);
        console.log(`💬 Joined Chat Room: ${roomName}`);
    }
});

// 4. INDICATEUR DE FRAPPE (Typing)
socket.on('typing', ({ conversationId, isTyping }) => {
    if (userId) {
        // On envoie à tout le monde dans la room de la conversation sauf à l'expéditeur
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

// --- MIDDLEWARES GÉNÉRAUX ---
app.use(cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "authorization", "X-Requested-With", "Accept"],
    exposedHeaders: ["Content-Type", "Authorization"]
}));

app.options('*', cors());

// Logging middleware (mode dev uniquement)
if (!config.IS_PRODUCTION) {
    app.use((req, res, next) => {
        if (req.method !== 'GET') {
            console.log(`[DEBUG] ${req.method} ${req.url}`, req.body ? Object.keys(req.body) : '');
        }
        next();
    });
}

app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// --- ROUTES API ---

// Auth (public)
app.use("/auth", authRoutes);

// Profil utilisateur
app.get("/auth/me", requireAuth, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, phone, name, id_oli, wallet, avatar_url, 
                    is_seller, is_deliverer, rating, reward_points 
             FROM users WHERE phone = $1`,
            [req.user.phone]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Utilisateur non trouvé" });
        }

        const user = result.rows[0];
        res.json({
            user: {
                ...user,
                wallet: parseFloat(user.wallet || 0).toFixed(2),
                initial: user.name ? user.name[0].toUpperCase() : "?"
            }
        });
    } catch (err) {
        console.error("Erreur /auth/me:", err);
        res.status(500).json({ error: "Erreur base de données" });
    }
});

// Upload Avatar
const { avatarUpload } = require("./config/upload");
app.post("/auth/upload-avatar", requireAuth, avatarUpload.single('avatar'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: "Pas de fichier" });

    const avatarUrl = `${config.BASE_URL}/uploads/${req.file.filename}`;

    try {
        await pool.query("UPDATE users SET avatar_url = $1 WHERE phone = $2", [avatarUrl, req.user.phone]);
        res.json({ avatar_url: avatarUrl });
    } catch (err) {
        res.status(500).json({ error: "Erreur lors de la sauvegarde" });
    }
});

// Produits (optionalAuth pour accès public + features privées)
app.use("/products", optionalAuth, productsRoutes);

// Boutiques
app.use("/shops", optionalAuth, shopsRoutes);

// Commandes (auth obligatoire)
app.use("/orders", requireAuth, ordersRoutes);

// Wallet (auth obligatoire)
app.use("/wallet", requireAuth, walletRoutes);

// Livraison (auth obligatoire + role checked in routes)
app.use("/delivery", requireAuth, deliveryRoutes);

// Chat (auth obligatoire)
app.use("/chat", requireAuth, chatRoutes);

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
        return res.status(400).json({ error: "Fichier trop volumineux (max 10MB)" });
    }

    res.status(err.status || 500).json({
        error: "Erreur serveur interne",
        message: err.message,
        path: req.path
    });
});

// --- DÉMARRAGE DU SERVEUR ---
server.listen(config.PORT, "0.0.0.0", () => {
    console.log(`🚀 OLI SERVER v1.0 - Port ${config.PORT} (${config.NODE_ENV})`);
    console.log(`📡 WebSocket ready`);
    console.log(`🌐 Base URL: ${config.BASE_URL}`);
});
