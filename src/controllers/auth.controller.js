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
    console.log("=".repeat(60));
    console.log("🔍 AVATAR UPLOAD DEBUG - START");
    console.log("=".repeat(60));

    // STEP 1: Vérifier la réception du fichier
    console.log("📥 STEP 1: Vérification du fichier reçu");
    if (!req.file) {
        console.error("❌ ERREUR: Aucun fichier reçu dans req.file");
        console.log("   req.body:", JSON.stringify(req.body, null, 2));
        return res.status(400).json({ error: "Pas de fichier" });
    }
    console.log("✅ Fichier reçu:");
    console.log("   - filename:", req.file.filename);
    console.log("   - originalname:", req.file.originalname);
    console.log("   - mimetype:", req.file.mimetype);
    console.log("   - size:", req.file.size, "bytes");
    console.log("   - path (Cloudinary):", req.file.path);

    // STEP 2: Extraire les informations
    const avatarUrl = req.file.path; // URL Cloudinary
    const userPhone = req.user ? req.user.phone : 'UNKNOWN';
    const userId = req.user ? req.user.id : 'UNKNOWN';

    console.log("\n📋 STEP 2: Informations extraites");
    console.log("   - User ID:", userId);
    console.log("   - User Phone:", userPhone);
    console.log("   - Avatar URL (brut):", avatarUrl);
    console.log("   - Type de path:",
        avatarUrl.startsWith('http') ? 'URL complète' :
            avatarUrl.startsWith('v') ? 'Cloudinary path relatif' :
                'Format inconnu'
    );

    try {
        // STEP 3: Sauvegarder dans la base de données
        console.log("\n💾 STEP 3: Sauvegarde dans la base de données");
        console.log("   - SQL: UPDATE users SET avatar_url = $1 WHERE phone = $2");
        console.log("   - Paramètre 1 (avatar_url):", avatarUrl);
        console.log("   - Paramètre 2 (phone):", userPhone);

        const userService = require('../services/user.service');
        const success = await userService.uploadAvatar(userPhone, avatarUrl);

        console.log("   - Résultat DB:", success ? "✅ SUCCESS" : "❌ FAILED");

        if (success) {
            // STEP 4: Vérifier la valeur sauvegardée
            console.log("\n🔎 STEP 4: Vérification de la valeur en base");
            const checkResult = await pool.query(
                "SELECT avatar_url FROM users WHERE phone = $1",
                [userPhone]
            );

            if (checkResult.rows.length > 0) {
                const savedAvatarUrl = checkResult.rows[0].avatar_url;
                console.log("   - Valeur en DB:", savedAvatarUrl);
                console.log("   - Match avec uploaded?", savedAvatarUrl === avatarUrl ? "✅ OUI" : "❌ NON");

                // STEP 5: Formatter avec imageService
                console.log("\n🎨 STEP 5: Formatage avec imageService");
                console.log("   - Input (DB value):", savedAvatarUrl);
                const formattedUrl = imageService.formatImageUrl(savedAvatarUrl);
                console.log("   - Output (formatted):", formattedUrl);
                console.log("   - Est une URL complète?", formattedUrl?.startsWith('http') ? "✅ OUI" : "❌ NON");

                // STEP 6: Retourner au client
                console.log("\n📤 STEP 6: Réponse au client");
                console.log("   - avatar_url retourné:", formattedUrl);

                console.log("\n" + "=".repeat(60));
                console.log("✅ AVATAR UPLOAD DEBUG - SUCCESS");
                console.log("=".repeat(60));

                res.json({
                    avatar_url: formattedUrl,
                    debug: {
                        raw_path: avatarUrl,
                        saved_in_db: savedAvatarUrl,
                        formatted_url: formattedUrl
                    }
                });
            } else {
                console.error("⚠️ ERREUR: Utilisateur non trouvé après update!");
                res.status(404).json({ error: "Utilisateur introuvable après update" });
            }
        } else {
            console.error("\n❌ ERREUR: Update DB a échoué");
            console.error("   - Aucune ligne modifiée pour phone:", userPhone);
            console.error("   - Vérifiez que ce numéro existe en base");
            console.log("\n" + "=".repeat(60));
            console.log("❌ AVATAR UPLOAD DEBUG - FAILED");
            console.log("=".repeat(60));
            res.status(404).json({ error: "Utilisateur non trouvé ou update échoué" });
        }
    } catch (err) {
        console.error("\n💥 STEP ERROR: Exception capturée");
        console.error("   - Message:", err.message);
        console.error("   - Stack:", err.stack);
        console.log("\n" + "=".repeat(60));
        console.log("❌ AVATAR UPLOAD DEBUG - EXCEPTION");
        console.log("=".repeat(60));
        res.status(500).json({ error: "Erreur lors de la sauvegarde" });
    }
};

