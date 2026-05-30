import axios from 'axios';
import { getToken, removeToken } from '../utils/auth';

const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

const api = axios.create({
    baseURL: API_URL,
    headers: { 'Content-Type': 'application/json' },
    timeout: 30000, // 30s — important pour Render cold start
});

// ── Intercepteur REQUEST : ajoute le token JWT ──
api.interceptors.request.use(
    (config) => {
        const token = getToken();
        if (token) {
            config.headers['Authorization'] = `Bearer ${token}`;
        }
        return config;
    },
    (error) => Promise.reject(error)
);

// ── Intercepteur RESPONSE : déconnecte UNIQUEMENT si le token JWT lui-même est invalide/expiré ──
// ⚠️  NE PAS déconnecter sur un 401 générique ou un 403 "Accès refusé"
// car cela peut arriver lors d'un cold start Render ou d'une route partiellement restreinte
api.interceptors.response.use(
    (response) => response,
    (error) => {
        // Ignorer les erreurs réseau / timeout (Render cold start)
        if (!error.response) {
            console.warn('[API] Erreur réseau ou timeout — session conservée');
            return Promise.reject(error);
        }

        const status = error.response.status;
        const errMsg = (error.response.data?.error || '').toLowerCase();

        // Déconnecter UNIQUEMENT si le JWT est explicitement rejeté par le backend
        // et UNIQUEMENT sur HTTP 401 (pas 403 qui = "pas admin" pas "token invalide")
        const isRealTokenError = (
            status === 401 &&
            (
                errMsg.includes('jwt') ||
                errMsg.includes('expiré') ||
                errMsg.includes('token invalide') ||
                errMsg.includes('token requis') ||
                errMsg === 'non authentifié'
            )
        );

        if (isRealTokenError) {
            console.warn('[API] JWT expiré ou invalide — déconnexion propre.');
            removeToken();
            // Délai pour éviter les redirections en cascade pendant le chargement initial
            setTimeout(() => {
                if (window.location.pathname !== '/login') {
                    window.location.href = '/login';
                }
            }, 300);
        }

        return Promise.reject(error);
    }
);

export default api;
