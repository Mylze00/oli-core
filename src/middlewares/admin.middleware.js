// Middleware pour protéger les routes admin
// Seuls les utilisateurs avec is_admin = true peuvent accéder

const requireAdmin = (req, res, next) => {
    // Vérifier authentification
    if (!req.user) {
        return res.status(401).json({
            error: "Non authentifié",
            message: "Veuillez vous connecter pour accéder au dashboard admin"
        });
    }

    // Vérifier rôle admin
    if (!req.user.is_admin) {
        console.log(`⚠️ [ADMIN] Accès refusé pour user ${req.user.id} (is_admin: ${req.user.is_admin})`);
        return res.status(403).json({
            error: "Accès refusé",
            message: "Cet accès est réservé aux administrateurs de la plateforme"
        });
    }

    console.log(`✅ [ADMIN] Accès autorisé pour admin ${req.user.id} (${req.user.phone})`);
    next();
};

module.exports = { requireAdmin };
