/**
 * Middleware d'authentification JWT
 * Vérifie le token et attache l'utilisateur à req.user
 */
const jwt = require("jsonwebtoken");
const { JWT_SECRET } = require("../config");
const pool = require("../config/db");

// ── Compte actif ? ─────────────────────────────────────────────────────────
// Un compte supprimé (users.deleted_at renseigné) ne doit plus utiliser son JWT,
// même si celui-ci est encore valide (durée de vie : 30 jours).
// Résultat mis en cache 60 s pour ne pas ajouter une requête SQL à chaque appel.
const ACCOUNT_CACHE_TTL_MS = 60 * 1000;
const accountCache = new Map(); // userId -> { active, at }

async function isAccountActive(userId) {
    const key = String(userId);
    const hit = accountCache.get(key);
    if (hit && Date.now() - hit.at < ACCOUNT_CACHE_TTL_MS) return hit.active;

    let rows;
    try {
        ({ rows } = await pool.query(
            "SELECT deleted_at FROM users WHERE id = $1",
            [userId]
        ));
    } catch (err) {
        // Colonne absente (migration 044 pas encore appliquée) : on ne bloque pas
        // toutes les routes authentifiées ; le contrôle de suppression est désactivé.
        if (err.code === "42703") {
            console.warn("[AUTH] users.deleted_at absent : contrôle de suppression ignoré (migration 044 à appliquer).");
            return true;
        }
        throw err;
    }
    const active = rows.length > 0 && !rows[0].deleted_at;
    accountCache.set(key, { active, at: Date.now() });
    return active;
}

/** À appeler après une suppression de compte (effet immédiat sur ce processus). */
function invalidateAccountCache(userId) {
    accountCache.delete(String(userId));
}

/**
 * Middleware obligatoire - Bloque si pas de token valide
 */
const requireAuth = async (req, res, next) => {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (!token) {
        return res.status(401).json({ error: "Token requis", message: "Aucun token d'authentification fourni" });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;

        try {
            const active = await isAccountActive(decoded.id);
            if (!active) {
                return res.status(401).json({
                    error: "Compte supprimé ou introuvable",
                    code: "ACCOUNT_DELETED",
                });
            }
        } catch (dbErr) {
            console.error("[AUTH] Vérification du compte impossible:", dbErr.message);
            return res.status(503).json({ error: "Service temporairement indisponible" });
        }

        console.log(`[AUTH] User identifié (Mandatory): ${decoded.id} (${decoded.phone})`);
        next();
    } catch (err) {
        console.error(`[AUTH] Échec requireAuth:`, err);
        if (err.name === "TokenExpiredError") {
            return res.status(401).json({ error: "Session expirée - Veuillez vous reconnecter" });
        }
        // Retourner l'erreur exacte pour le débug
        return res.status(403).json({
            error: "Token invalide",
            details: err.message,
            name: err.name
        });
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
    invalidateAccountCache,
    authenticateToken: requireAuth,
};
