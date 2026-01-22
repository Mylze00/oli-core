import axios from 'axios';

// En production, VITE_API_URL sera défini dans les variables d'environnement Vercel
// Par défaut pour le dev local, on peut laisser localhost ou l'URL Render directe
const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Intercepteur pour ajouter le token
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('seller_token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

export default api;
