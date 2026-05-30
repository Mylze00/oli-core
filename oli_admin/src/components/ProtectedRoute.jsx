import { Navigate, Outlet } from 'react-router-dom';
import { getToken } from '../utils/auth';

// Décode le payload JWT sans vérifier la signature (côté client uniquement)
function isTokenValid(token) {
    if (!token) return false;
    try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        // Vérifier l'expiration (exp est en secondes)
        if (payload.exp && Date.now() / 1000 > payload.exp) {
            console.warn('[Auth] Token expiré côté client');
            return false;
        }
        return true;
    } catch {
        return false;
    }
}

export default function ProtectedRoute() {
    const token = getToken();
    if (!isTokenValid(token)) {
        return <Navigate to="/login" replace />;
    }
    return <Outlet />;
}
