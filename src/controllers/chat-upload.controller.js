/**
 * Contrôleur pour l'upload de fichiers dans le chat (Cloudinary / Local)
 */
const { isCloudStorage } = require("../config/upload");
const { BASE_URL } = require("../config");

/**
 * Middleware d'upload injecté dans updates routes:
 * router.post('/upload', chatUpload.single('file'), chatController.uploadFile);
 * 
 * Donc ici on récupère juste le résultat.
 */
exports.uploadFile = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: "Aucun fichier fourni" });
        }

        const file = req.file;
        console.log(`📤 Upload file: ${file.originalname} (${file.size} bytes)`);

        // Multer-Cloudinary met l'URL dans `path` (ou `secure_url` dans raw)
        // Multer-DiskStorage met le chemin local dans `path`
        
        let mediaUrl = file.path;

        // Si stockage local, on doit construire l'URL complète
        if (!isCloudStorage && !mediaUrl.startsWith("http")) {
            // file.path ressemble à "uploads/chat/xyz.jpg"
            // On s'assure que les slashes sont bons pour l'URL
            const relativePath = file.path.replace(/\\/g, "/");
            mediaUrl = `${BASE_URL}/${relativePath}`;
        }

        // Détection basique du type
        const mediaType = file.mimetype.startsWith("image/") ? "image" : 
                          file.mimetype.startsWith("audio/") ? "audio" :
                          file.mimetype.startsWith("video/") ? "video" : "file";

        console.log(`✅ Upload réussi: ${mediaUrl}`);

        res.json({
            success: true,
            mediaUrl: mediaUrl,
            mediaType: mediaType,
            message: "Fichier uploadé avec succès"
        });

    } catch (error) {
        console.error("❌ Erreur Upload Controller:", error);
        res.status(500).json({ 
            error: "Erreur lors de l'upload",
            details: error.message 
        });
    }
};

// Note: On n'exporte plus 'uploadMiddleware' ici car on utilise celui de config/upload.js
