import axios from 'axios';
import { getToken, removeToken } from '../utils/auth';

// URL de base (adapter selon environnement)
// En dev local, on tape sur le backend local (proxy ou direct)
// En prod, sur l'URL de Render
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

// Intercepteur pour gérer les erreurs 401 (Expire)
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response && error.response.status === 401) {
            // Si 401 Unauthorized, on déconnecte
            removeToken();
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

export default api;
