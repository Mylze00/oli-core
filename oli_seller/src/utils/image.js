export const getImageUrl = (path) => {
    if (!path) return null;

    // Si c'est déjà une URL complète (ex: Google Auth, ou déjà Cloudinary complet)
    if (path.startsWith('http')) return path;

    // Configuration Cloudinary
    const CLOUD_NAME = 'dbfpnxjmm';
    const BASE_URL = `https://res.cloudinary.com/${CLOUD_NAME}/image/upload`;

    // Si le path commence par un slash, on l'enlève pour éviter le double slash
    const cleanPath = path.startsWith('/') ? path.slice(1) : path;

    // Si le path commence par 'uploads/', c'est une image locale (fallback dev)
    if (cleanPath.startsWith('uploads/')) {
        const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';
        return `${API_URL}/${cleanPath}`;
    }

    return `${BASE_URL}/${cleanPath}`;
};
