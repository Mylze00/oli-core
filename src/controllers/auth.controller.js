const jwt = require("jsonwebtoken");
const { JWT_SECRET, JWT_EXPIRES_IN } = require("../config");
const otpService = require("../services/otp.service");
const pool = require("../config/db");
const imageService = require("../services/image.service");

/**
 * Envoie un code OTP au numéro de téléphone
 */
exports.sendOtp = async (req, res) => {
    try {
        const { phone } = req.body;

        if (!phone) {
            return res.status(400).json({ error: "Numéro de téléphone requis" });
        }

        // Valider le format du numéro (RDC: +243...)
        const cleanPhone = phone.replace(/\s/g, '');
        if (!cleanPhone.match(/^\+?[0-9]{10,15}$/)) {
            return res.status(400).json({ error: "Format de numéro invalide" });
        }

        const { user, otpCode } = await otpService.sendOtp(cleanPhone);

        // [SÉCU] Le code OTP est uniquement visible dans les logs serveur (jamais renvoyé au client)
        // En développement : consultez les logs du serveur pour voir le code
        if (process.env.NODE_ENV !== 'production') {
            console.log(`📩 [DEV ONLY] OTP pour ${cleanPhone} : ${otpCode}`);
        }

        return res.json({
            message: "Code OTP envoyé",
            user: {
                id: user.id,
                phone: user.phone
            }
        });

    } catch (e) {
        console.error("Erreur send-otp:", e);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

/**
 * Vérifie le code OTP et retourne un token JWT
 */
exports.verifyOtp = async (req, res) => {
    try {
        const { phone, otpCode } = req.body;

        if (!phone || !otpCode) {
            return res.status(400).json({ error: "Téléphone et code OTP requis" });
        }

        console.log("🔐 VERIFY OTP:", phone, otpCode);

        const result = await otpService.verifyOtp(phone, otpCode);

        if (!result) {
            return res.status(401).json({ error: "Code invalide ou expiré" });
        }

        // ✅ Lire le solde réel depuis wallets.balance (source de vérité)
        let walletBalance = 0;
        try {
            const wRes = await pool.query(
                'SELECT balance FROM wallets WHERE user_id = $1', [result.user.id]
            );
            if (wRes.rows.length > 0) {
                walletBalance = parseFloat(wRes.rows[0].balance);
            } else {
                // Fallback sur users.wallet si pas de wallet encore créé
                walletBalance = parseFloat(result.user.wallet || 0);
            }
        } catch (e) {
            walletBalance = parseFloat(result.user.wallet || 0);
        }

        // Générer le token JWT
        const token = jwt.sign(
            {
                id: result.user.id,
                phone: result.user.phone,
                is_admin: result.user.is_admin || false,
                is_seller: result.user.is_seller || false,
                is_deliverer: result.user.is_deliverer || false
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );

        console.log("🔑 Token généré pour", phone, ":", token.substring(0, 20) + "...");
        console.log("💰 Wallet balance retourné:", walletBalance, "FC");

        return res.json({
            message: "Connexion réussie",
            user: imageService.formatUserImages({
                id: result.user.id,
                phone: result.user.phone,
                name: result.user.name,
                id_oli: result.user.id_oli,
                avatar_url: result.user.avatar_url,
                wallet: walletBalance.toFixed(2),  // ✅ Depuis wallets.balance
                is_admin: result.user.is_admin || false,
                is_seller: result.user.is_seller || false,
                is_deliverer: result.user.is_deliverer || false,
            }),
            token
        });

    } catch (e) {
        console.error("Erreur verify-otp:", e);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

/**
 * Met à jour le profil utilisateur
 */
exports.updateProfile = async (req, res) => {
    const { name, username, bio, city } = req.body;

    // req.user est injecté par le middleware requireAuth
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        // 2. Mettre à jour le profil via le service
        const userService = require('../services/user.service');
        const user = await userService.updateProfile(req.user.phone, name, username, bio, city);

        if (!user) {
            return res.status(404).json({ error: "Utilisateur non trouvé" });
        }

        res.json({
            message: "Profil mis à jour",
            user: user
        });
    } catch (e) {
        console.error("Erreur update-profile:", e);
        if (e.message && e.message.includes("déjà pris")) {
             return res.status(400).json({ error: e.message });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

/**
 * Récupère le profil de l'utilisateur connecté
 */
exports.getMe = async (req, res) => {
    try {
        // ✅ Jointure avec wallets pour avoir le solde réel
        const result = await pool.query(
            `SELECT u.id, u.phone, u.name, u.username, u.bio, u.city, u.loyalty_tier, u.id_oli, u.avatar_url,
                  u.is_seller, u.is_deliverer, u.rating, u.reward_points,
                  u.is_verified, u.account_type, u.has_certified_shop,
                  COALESCE(w.balance, u.wallet::DECIMAL, 0) as wallet
           FROM users u
           LEFT JOIN wallets w ON w.user_id = u.id
           WHERE u.phone = $1`,
            [req.user.phone]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Utilisateur non trouvé" });
        }

        const user = result.rows[0];
        res.json({
            user: imageService.formatUserImages({
                ...user,
                wallet: parseFloat(user.wallet || 0).toFixed(2),  // ✅ Depuis wallets.balance
                initial: user.name ? user.name[0].toUpperCase() : "?"
            })
        });
    } catch (err) {
        console.error("Erreur /auth/me:", err);
        res.status(500).json({ error: "Erreur base de données" });
    }
};

/**
 * Upload de l'avatar utilisateur
 */
exports.uploadAvatar = async (req, res) => {
    console.log("=".repeat(60));
    console.log("🔍 AVATAR UPLOAD (v2 with History & Sync) - START");
    console.log("=".repeat(60));

    // STEP 1: Vérifier la réception du fichier
    if (!req.file) {
        return res.status(400).json({ error: "Pas de fichier" });
    }

    const avatarUrl = req.file.path; // URL Cloudinary ou Path local
    const userId = req.user ? req.user.id : null;
    const userPhone = req.user ? req.user.phone : null;

    if (!userId) {
        return res.status(401).json({ error: "Utilisateur non authentifié" });
    }

    console.log("   - User ID:", userId);
    console.log("   - Avatar URL:", avatarUrl);

    try {
        const avatarHistoryService = require('../services/avatar-history.service');

        // STEP 2: Utiliser le service d'historique (qui gère la limite de 30 et la sync boutique)
        // On passe les métadonnées du fichier
        const metadata = {
            storageProvider: req.file.path.includes('cloudinary') ? 'cloudinary' : 'local',
            fileSizeBytes: req.file.size,
            mimeType: req.file.mimetype
        };

        const result = await avatarHistoryService.saveAvatar(userId, avatarUrl, metadata);

        // STEP 3: Formatter et répondre
        const formattedUrl = imageService.formatImageUrl(result.avatar_url);

        console.log("✅ AVATAR UPLOAD SUCCESS");

        res.json({
            success: true,
            avatar_url: formattedUrl,
            message: "Avatar mis à jour avec succès (Boutique synchronisée)",
            changes_count: await avatarHistoryService.checkAvatarChangeLimit(userId) ? "OK" : "Limit Reached" // Info debug
        });

    } catch (err) {
        console.error("❌ ERREUR AVATAR UPLOAD:", err.message);

        // Gestion spécifique erreur limite
        if (err.message.includes("limite de 30 changements")) {
            return res.status(403).json({ error: err.message, code: "LIMIT_REACHED" });
        }

        res.status(500).json({ error: "Erreur lors de la sauvegarde de l'avatar" });
    }
};

