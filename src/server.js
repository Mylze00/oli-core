require("dotenv").config();
const express = require("express");
const http = require('http');
const { Server } = require("socket.io");
const cors = require("cors");
const helmet = require("helmet");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwt = require("jsonwebtoken");
const pool = require("./config/db");

// Routes Imports
const authRoutes = require("./routes/auth.routes");
const ordersRoutes = require("./routes/orders.routes");
const productsRoutes = require("./routes/products.routes");
const chatRoutes = require("./routes/chat.routes");

// --- INITIALISATION ---
const app = express();
const server = http.createServer(app);
const JWT_SECRET = process.env.JWT_SECRET || "oli_default_secret_2024_secure_change_me";
if (!process.env.JWT_SECRET) {
    console.warn("⚠️ ATTENTION: JWT_SECRET non défini. Utilisation du secret de secours.");
}

// Origines autorisées (séparer par des virgules via la variable d'environnement ALLOWED_ORIGINS)
// Origines autorisées (séparer par des virgules via la variable d'environnement ALLOWED_ORIGINS)
const DEFAULT_ORIGINS = [
    "https://oli-core.web.app",
    "https://oli-core.firebaseapp.com",
    "https://oli-core.onrender.com",
    "http://localhost:3000",
    "http://localhost:5000",
    "http://127.0.0.1:3000"
];
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim()) : DEFAULT_ORIGINS);
if (ALLOWED_ORIGINS.length === 1 && ALLOWED_ORIGINS[0] === '*') {
    console.warn("⚠️ ALLOWED_ORIGINS est '*' — configuration non sécurisée pour la production");
}

// --- SOCKET.IO CONFIG ---
const io = new Server(server, {
    cors: {
        origin: ALLOWED_ORIGINS,
        methods: ["GET", "POST"]
    }
});

app.set('io', io); // Partager l'instance IO

io.on('connection', (socket) => {
    console.log('⚡ Client Socket connecté:', socket.id);

    socket.on('join', (userId) => {
        socket.join(`user_${userId}`);
        console.log(`👤 User ${userId} joined room user_${userId}`);
    });

    socket.on('disconnect', () => {
        console.log('Client déconnecté');
    });
});

// --- MIDDLEWARES GÉNÉRAUX ---
app.use(cors({
    origin: true, // Autorise dynamiquement l'origine qui fait la requête
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "authorization", "X-Requested-With", "Accept"],
    exposedHeaders: ["Content-Type", "Authorization"]
}));

// Handler explicite pour OPTIONS (Preflight)
app.options('*', cors());

// Middleware de debug pour logger TOUS les headers sur les requêtes sensibles
app.use((req, res, next) => {
    if (req.method !== 'GET') {
        console.log(`[DEBUG LOG] Headers for ${req.method} ${req.url}:`, JSON.stringify(req.headers));
    }
    next();
});

app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// --- MIDDLEWARE DE SÉCURITÉ (JWT) ---
const verifyToken = (req, res, next) => {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (!token) return res.status(401).json({ error: "Accès refusé" });

    try {
        const verified = jwt.verify(token, JWT_SECRET);
        req.user = verified;
        next();
    } catch (err) {
        res.status(403).json({ error: "Token invalide" });
    }
};

// --- CONFIGURATION UPLOADS (MULTER) ---
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
    destination: (req, file, cb) => { cb(null, 'uploads/'); },
    filename: (req, file, cb) => {
        const cleanName = file.originalname.replace(/[^\w.]+/g, '_');
        cb(null, Date.now() + '-' + cleanName);
    }
});
const upload = multer({ storage: storage, limits: { fileSize: 5 * 1024 * 1024 } });

// --- ROUTES API ---

// 1. Auth & Commandes
app.use("/auth", authRoutes);
app.use("/orders", verifyToken, ordersRoutes);

// 2. Chat (Nouveau Phase 2)
app.use("/chat", verifyToken, chatRoutes);

// 3. Produits (Hybride Public/Privé)
app.use("/products", (req, res, next) => {
    // Middleware optionnel pour peupler req.user si token présent
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (token) {
        try {
            req.user = jwt.verify(token, JWT_SECRET);
            console.log(`✅ Token valide (${req.method} ${req.path}) pour: ${req.user.phone}`);
        } catch (err) {
            console.error(`❌ Token invalide/expiré (${req.method} ${req.path}): ${err.message}`);
        }
    } else if (req.method !== 'GET') {
        // On ne prévient que pour les méthodes qui REQUIRE l'auth (POST/PUT/DELETE)
        console.warn(`⚠️ Aucun token fourni pour la requête sensible: ${req.method} ${req.path}`);
    }
    next();
}, productsRoutes);

// --- ROUTES INLINE (Legacy - Profil/Wallet) ---

// Profil Utilisateur
app.get("/auth/me", verifyToken, async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT id, phone, name, id_oli, wallet, avatar_url FROM users WHERE phone = $1",
            [req.user.phone]
        );

        if (result.rows.length === 0) return res.status(404).json({ error: "User non trouvé" });

        const user = result.rows[0];
        res.json({
            user: {
                ...user,
                wallet: parseFloat(user.wallet || 0).toFixed(2),
                initial: user.name ? user.name[0].toUpperCase() : "?"
            }
        });
    } catch (err) {
        res.status(500).json({ error: "Erreur base de données" });
    }
});

// Upload Avatar
app.post("/auth/upload-avatar", verifyToken, upload.single('avatar'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: "Pas de fichier" });

    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const avatarUrl = `${protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    try {
        await pool.query("UPDATE users SET avatar_url = $1 WHERE phone = $2", [avatarUrl, req.user.phone]);
        res.json({ avatar_url: avatarUrl });
    } catch (err) {
        res.status(500).json({ error: "Erreur lors de la sauvegarde" });
    }
});

// Wallet Deposit
app.post("/wallet/deposit", verifyToken, async (req, res) => {
    const { amount } = req.body;
    if (!amount || isNaN(amount)) return res.status(400).json({ error: "Montant invalide" });

    try {
        const result = await pool.query(
            "UPDATE users SET wallet = wallet + $1 WHERE phone = $2 RETURNING wallet",
            [parseFloat(amount), req.user.phone]
        );
        res.json({ newBalance: parseFloat(result.rows[0].wallet).toFixed(2) });
    } catch (err) {
        res.status(500).json({ error: "Erreur transaction" });
    }
});

// --- DEBUG ROUTE (A supprimer plus tard) ---
app.get("/debug/migrate-schema", async (req, res) => {
    try {
        await pool.query(`
            ALTER TABLE products 
            ADD COLUMN IF NOT EXISTS condition VARCHAR(50) DEFAULT 'Neuf',
            ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
            ADD COLUMN IF NOT EXISTS delivery_price DECIMAL(10, 2) DEFAULT 0.00,
            ADD COLUMN IF NOT EXISTS delivery_time VARCHAR(100) DEFAULT '',
            ADD COLUMN IF NOT EXISTS color VARCHAR(50) DEFAULT '',
            ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
            ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;
        `);
        // Phase 4 : Mise à jour des status et nettoyage
        await pool.query("UPDATE products SET status = 'active' WHERE status IS NULL");
        console.log("✅ Phase 4 : Status des produits existants mis à jour.");

        res.json({ success: true, message: "Schéma et données (Phase 4) mis à jour avec succès !" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- DÉMARRAGE DU SERVEUR ---
const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 SERVEUR OLI ACTIF SUR LE PORT ${PORT} (HTTP + WebSocket)`);
});