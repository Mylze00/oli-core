const express = require('express');
const router = express.Router();
const multer = require('multer');
const aiController = require('../controllers/ai.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

// Configuration Multer : stockage en mémoire (MemoryStorage)
// Indispensable pour récupérer "req.file.buffer" et l'encoder en base64 pour OpenAI
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024 // Limite à 5 MB
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Le fichier doit être une image.'));
        }
    }
});

// Route POST /api/ai/analyze-screenshot
router.post('/analyze-screenshot', requireAuth, upload.single('image'), aiController.analyzeProductImage);

module.exports = router;
