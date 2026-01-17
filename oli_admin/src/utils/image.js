export const getImageUrl = (path) => {
    if (!path) return null;

    // Si c'est déjà une URL complète (ex: Google Auth, ou déjà Cloudinary complet)
    if (path.startsWith('http')) return path;

    // Configuration Cloudinary
    const CLOUD_NAME = 'dbfpnxjmm';
    const BASE_URL = `https://res.cloudinary.com/${CLOUD_NAME}/image/upload`;

    // Si le path commence par un slash, on l'enlève pour éviter le double slash
    const cleanPath = path.startsWith('/') ? path.slice(1) : path;

    return `${BASE_URL}/${cleanPath}`;
};
