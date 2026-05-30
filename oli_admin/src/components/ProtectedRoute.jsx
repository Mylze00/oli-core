import { Navigate, Outlet } from 'react-router-dom';
import { getToken, removeToken } from '../utils/auth';

/**
 * Décode le payload JWT sans vérifier la signature (côté client uniquement).
 * Retourne null si le token est absent, malformé ou expiré.
 */
function decodeToken(token) {
    if (!token) return null;
    try {
        const parts = token.split('.');
        if (parts.length !== 3) return null;
        // Padding base64 correct
        const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
        const padded = base64 + '=='.slice(0, (4 - base64.length % 4) % 4);
        return JSON.parse(atob(padded));
    } catch {
        return null;
    }
}

function isTokenValid(token) {
    const payload = decodeToken(token);
    if (!payload) return false;

    // Vérifier l'expiration avec une marge de 60 secondes
    if (payload.exp) {
        const nowSec = Date.now() / 1000;
        if (nowSec > payload.exp - 60) {
            console.warn('[Auth] Token expiré (ou expire dans < 60s) — déconnexion.');
            removeToken();
            return false;
        }
    }
    return true;
}

export default function ProtectedRoute() {
    const token = getToken();

    if (!isTokenValid(token)) {
        return <Navigate to="/login" replace />;
    }

    return <Outlet />;
}
