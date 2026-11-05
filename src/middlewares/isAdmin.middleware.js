const pool = require('../config/db');

/**
 * Middleware pour l'administrateur principal (Master Admin)
 * Vérifie le numéro de téléphone spécifique ou le flag is_admin
 */
const isAdmin = async (req, res, next) => {
    try {
        const userId = req.user.id; // Supposant que authMiddleware a déjà décodé le token

        // Optimisation: On pourrait stocker le rôle dans le token pour éviter la requête DB
        // Mais pour la sécurité maximale, on vérifie la DB
        const { rows } = await pool.query('SELECT is_admin, phone FROM users WHERE id = $1', [userId]);

        if (rows.length === 0) {
            return res.status(404).json({ message: "Utilisateur introuvable" });
        }

        const user = rows[0];

        // [SÉCU C7] Droits admin uniquement via le flag en base (plus de correspondance
        // par sous-chaîne sur le numéro de téléphone)
        if (user.is_admin === true) {
            next();
        } else {
            return res.status(403).json({ message: "Accès refusé. Réservé aux administrateurs." });
        }

    } catch (error) {
        console.error("Admin Middleware Error:", error);
        res.status(500).json({ message: "Erreur serveur vérification admin" });
    }
};

module.exports = isAdmin;
