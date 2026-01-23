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

        console.log("📩 SEND OTP:", cleanPhone);
        const { user, otpCode } = await otpService.sendOtp(cleanPhone);

        // ⚡ Afficher le code en réponse pour les tests
        console.log(`✅ OTP GÉNÉRÉ: ${otpCode} pour ${cleanPhone}`);

        return res.json({
            message: "Code OTP envoyé",
            otp: otpCode,  // 👈 Retourner le code pour les tests
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

        // Générer le token JWT avec toutes les infos utiles (dont is_admin !)
        const token = jwt.sign(
            {
                id: result.user.id,
                phone: result.user.phone,
                is_admin: result.user.is_admin || false, // ✨ AJOUTÉ
                is_seller: result.user.is_seller || false,
                is_deliverer: result.user.is_deliverer || false
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );

        // DEBUG: Afficher le token généré
        console.log("🔑 Token généré pour", phone, ":", token.substring(0, 20) + "...");

        return res.json({
            message: "Connexion réussie",
            user: imageService.formatUserImages({
                id: result.user.id,
                phone: result.user.phone,
                name: result.user.name,
                id_oli: result.user.id_oli,
                avatar_url: result.user.avatar_url,
                wallet: parseFloat(result.user.wallet || 0).toFixed(2),
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
    const { name } = req.body;

    // req.user est injecté par le middleware requireAuth
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        // 2. Mettre à jour le profil via le service
        const userService = require('../services/user.service');
        const user = await userService.updateProfile(req.user.phone, name);

        if (!user) {
            return res.status(404).json({ error: "Utilisateur non trouvé" });
        }

        res.json({
            message: "Profil mis à jour",
            user: user
        });
    } catch (e) {
        console.error("Erreur update-profile:", e);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

/**
 * Récupère le profil de l'utilisateur connecté
 */
exports.getMe = async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, phone, name, id_oli, wallet, avatar_url, 
                  is_seller, is_deliverer, rating, reward_points,
                  is_verified, account_type, has_certified_shop 
           FROM users WHERE phone = $1`,
            [req.user.phone]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Utilisateur non trouvé" });
        }

        const user = result.rows[0];
        res.json({
            user: imageService.formatUserImages({
                ...user,
                wallet: parseFloat(user.wallet || 0).toFixed(2),
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
    if (!req.file) {
        console.error("❌ Upload Avatar: Aucun fichier reçu dans req.file");
        return res.status(400).json({ error: "Pas de fichier" });
    }

    const avatarUrl = req.file.path; // URL Cloudinary
    const userPhone = req.user ? req.user.phone : 'UNKNOWN';

    console.log(`📸 START Avatar Update for ${userPhone}`);
    console.log(`   - File URL: ${avatarUrl}`);

    try {
        const userService = require('../services/user.service');
        const success = await userService.uploadAvatar(userPhone, avatarUrl);

        if (success) {
            console.log(`✅ Avatar Update SUCCESS in DB for ${userPhone}`);
            res.json({ avatar_url: avatarUrl });
        } else {
            console.error(`⚠️ Avatar Update FAILED: Aucune ligne modifiée pour ${userPhone}`);
            console.error(`   - Est-ce que le numéro de téléphone en base est exactement "${userPhone}" ?`);
            res.status(404).json({ error: "Utilisateur non trouvé ou update échoué" });
        }
    } catch (err) {
        console.error("❌ Erreur CRITIQUE upload-avatar:", err);
        res.status(500).json({ error: "Erreur lors de la sauvegarde" });
    }
};
