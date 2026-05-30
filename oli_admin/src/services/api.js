import axios from 'axios';
import { getToken, removeToken } from '../utils/auth';

const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Intercepteur pour ajouter le token JWT
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

// Intercepteur pour gérer les erreurs 401
// ⚠️ On ne déconnecte QUE si c'est explicitement un problème de token
// (pas pour les 401 de ressources protégées qui pourraient être temporaires)
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response && error.response.status === 401) {
            const errMsg = error.response.data?.error || '';
            const isTokenError = (
                errMsg.includes('Token') ||
                errMsg.includes('Session') ||
                errMsg.includes('expirée') ||
                errMsg.includes('invalide') ||
                errMsg.includes('requis') ||
                errMsg.includes('Accès refusé')
            );

            if (isTokenError) {
                console.warn('[API] Token invalide ou expiré — déconnexion.');
                removeToken();
                // Utiliser setTimeout pour éviter les redirections en cascade
                setTimeout(() => { window.location.href = '/login'; }, 100);
            }
            // Ne pas auto-déconnecter pour les autres 401 (ex: ressource non autorisée)
        }
        return Promise.reject(error);
    }
);

export default api;
