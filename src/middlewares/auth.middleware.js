/**
 * Middleware d'authentification JWT
 * Vérifie le token et attache l'utilisateur à req.user
 */
const jwt = require("jsonwebtoken");
const { JWT_SECRET } = require("../config");

/**
 * Middleware obligatoire - Bloque si pas de token valide
 */
const requireAuth = (req, res, next) => {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (!token) {
        return res.status(401).json({ error: "Accès refusé - Token requis" });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        console.log(`[AUTH] User identifié (Mandatory): ${decoded.id} (${decoded.phone})`);
        next();
    } catch (err) {
        console.error(`[AUTH] Échec requireAuth: ${err.message}`);
        if (err.name === "TokenExpiredError") {
            return res.status(401).json({ error: "Session expirée - Veuillez vous reconnecter" });
        }
        return res.status(403).json({ error: "Token invalide" });
    }
};

/**
 * Middleware optionnel - Peuple req.user si token présent, sinon continue
 * Utile pour les routes hybrides (ex: marketplace publique mais avec features privées)
 */
const optionalAuth = (req, res, next) => {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (token) {
        try {
            const decoded = jwt.verify(token, JWT_SECRET);
            req.user = decoded;
            console.log(`[AUTH] User identifié (Optional): ${decoded.id} (${decoded.phone})`);
        } catch (err) {
            // Token invalide mais on continue sans user
            console.warn(`[AUTH] Token optionnel invalide ignoré: ${err.message}`);
        }
    } else {
        console.log(`[AUTH] Requête anonyme (Optional) vers ${req.path}`);
    }
    next();
};

/**
 * Middleware pour vérifier le rôle (vendeur, livreur, admin)
 * Usage: requireRole('seller') ou requireRole(['seller', 'admin'])
 */
const requireRole = (roles) => {
    const allowedRoles = Array.isArray(roles) ? roles : [roles];

    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: "Authentification requise" });
        }

        // On vérifie les flags booléens selon le rôle
        const hasRole = allowedRoles.some(role => {
            if (role === 'seller') return req.user.is_seller === true;
            if (role === 'deliverer') return req.user.is_deliverer === true;
            if (role === 'admin') return req.user.is_admin === true;
            return false;
        });

        if (!hasRole) {
            return res.status(403).json({ error: "Accès non autorisé pour ce rôle" });
        }

        next();
    };
};

module.exports = {
    requireAuth,
    optionalAuth,
    requireRole,
};
