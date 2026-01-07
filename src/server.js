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
const JWT_SECRET = process.env.JWT_SECRET || "ton_secret_jwt_ici";

// --- SOCKET.IO CONFIG ---
const io = new Server(server, {
    cors: {
        origin: "*", // A sécuriser en production
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
    origin: ["https://oli-core.web.app", "https://oli-core.firebaseapp.com"],
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"]
}));

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
        } catch (err) { /* Ignorer erreur token visiteur */ }
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
            ...user,
            wallet: parseFloat(user.wallet || 0).toFixed(2),
            initial: user.name ? user.name[0].toUpperCase() : "?"
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

// --- DÉMARRAGE DU SERVEUR ---
const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 SERVEUR OLI ACTIF SUR LE PORT ${PORT} (HTTP + WebSocket)`);
});