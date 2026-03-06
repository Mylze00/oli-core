const mult = require("multer");
const cloudinary = require("cloudinary").v2;
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const path = require("path");
const fs = require("fs");

// Configurer Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

const isCloudConfigured = process.env.CLOUDINARY_CLOUD_NAME &&
    process.env.CLOUDINARY_API_KEY &&
    process.env.CLOUDINARY_API_SECRET;

// --- STRATÉGIE DE STOCKAGE ---
let storage;

if (isCloudConfigured) {
    console.log("☁️  CLOUDINARY: Configuré et prêt");
    storage = new CloudinaryStorage({
        cloudinary: cloudinary,
        params: {
            folder: "oli_app",
            allowed_formats: ["jpg", "jpeg", "png", "webp", "mp4", "mp3", "wav"],
            resource_type: "auto", // Auto-détection (image, video, audio)
        },
    });
} else {
    // 🚨 SÉCURITÉ : En PRODUCTION (Render), on ne PEUT PAS utiliser le stockage local
    // car les fichiers disparaissent à chaque redémarrage.
    if (process.env.NODE_ENV === 'production') {
        const missingKeys = [];
        if (!process.env.CLOUDINARY_CLOUD_NAME) missingKeys.push('CLOUDINARY_CLOUD_NAME');
        if (!process.env.CLOUDINARY_API_KEY) missingKeys.push('CLOUDINARY_API_KEY');
        if (!process.env.CLOUDINARY_API_SECRET) missingKeys.push('CLOUDINARY_API_SECRET');

        console.error("❌ ERREUR CRITIQUE : Cloudinary non configuré en PRODUCTION !");
        console.error(`   Clés manquantes: ${missingKeys.join(', ')}`);
        // Throw pour empêcher le démarrage avec une config cassée
        // throw new Error("Cloudinary configuration required in production");
    } else {
        console.warn("⚠️  CLOUDINARY: Clés manquantes (Fallback LOCAL activé pour le dev)");
    }

    console.log("- CLOUD_NAME:", process.env.CLOUDINARY_CLOUD_NAME ? `${process.env.CLOUDINARY_CLOUD_NAME.substring(0, 3)}...` : "MANQUANT");
    console.log("- API_KEY:", process.env.CLOUDINARY_API_KEY ? "Défini" : "MANQUANT");
    console.log("- API_SECRET:", process.env.CLOUDINARY_API_SECRET ? "Défini" : "MANQUANT");

    // Créer les dossiers locaux si nécessaire
    const uploadDirs = ['uploads', 'uploads/products', 'uploads/avatars', 'uploads/chat', 'uploads/videos'];
    uploadDirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    });

    storage = mult.diskStorage({
        destination: (req, file, cb) => {
            let folder = "uploads/";
            if (file.fieldname === "images" || file.fieldname === "image") folder += "products/";
            else if (file.fieldname === "avatar") folder += "avatars/";
            else if (file.fieldname === "chat_file") folder += "chat/";
            else if (file.fieldname === "video") folder += "videos/";

            // Si le dossier spécifique n'existe pas, on le crée
            if (!fs.existsSync(folder)) {
                fs.mkdirSync(folder, { recursive: true });
            }
            cb(null, folder);
        },
        filename: (req, file, cb) => {
            const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
            cb(null, uniqueSuffix + path.extname(file.originalname));
        },
    });
}

// --- FILTRES ET LIMITES ---
const fileFilter = (req, file, cb) => {
    const allowedTypes = [
        "image/jpeg", "image/png", "image/webp", "image/jpg",
        "audio/mpeg", "audio/mp3", "audio/wav", "audio/agg", // Audio
        "video/mp4", "video/mpeg" // Video
    ];

    if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new Error("Type de fichier non supporté"), false);
    }
};

const limits = {
    fileSize: 50 * 1024 * 1024, // 50MB max (vidéos courtes de vente)
};

const upload = mult({
    storage: storage,
    fileFilter: fileFilter,
    limits: limits
});

// --- EXPORTS SPÉCIFIQUES (Pour compatibilité avec le code existant) ---
// On utilise la même instance 'upload' car Cloudinary gère tout via 'folder' ou 'resource_type: auto'
// Si on voulait des dossiers séparés sur Cloudinary, on aurait besoin de plusieurs instances Storage.
// Pour simplifier, tout va dans 'oli_app'.

module.exports = {
    productUpload: upload,
    avatarUpload: upload,
    chatUpload: upload,
    videoUpload: upload,
    genericUpload: upload,
    isCloudStorage: isCloudConfigured
};

