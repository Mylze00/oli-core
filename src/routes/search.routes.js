/**
 * Routes de Recherche Visuelle
 * Permet aux utilisateurs de chercher des produits en uploadant une photo
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const visionService = require('../services/vision.service');
const productRepository = require('../repositories/product.repository');
const imageService = require('../services/image.service');

// Configuration multer pour stocker en mémoire
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024 // Limit 5MB
    },
    fileFilter: (req, file, cb) => {
        // Accepter uniquement les images
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Seules les images sont acceptées'));
        }
    }
});

/**
 * POST /search/visual
 * Recherche de produits par image
 */
router.post('/visual', upload.single('image'), async (req, res) => {
    console.log('============================================================');
    console.log('🔍 RECHERCHE VISUELLE - START');
    console.log('============================================================');

    try {
        // Vérifier si une image a été fournie
        if (!req.file) {
            console.error('❌ Aucune image fournie');
            return res.status(400).json({
                error: 'Aucune image fournie',
                message: 'Veuillez uploader une image'
            });
        }

        console.log('📥 STEP 1: Image reçue');
        console.log(`   - Nom: ${req.file.originalname}`);
        console.log(`   - Type: ${req.file.mimetype}`);
        console.log(`   - Taille: ${req.file.size} bytes`);

        // Vérifier que le service Vision est disponible
        if (!visionService.isAvailable()) {
            console.error('❌ Vision API non disponible');
            console.error('   - Vérifiez la variable GOOGLE_APPLICATION_CREDENTIALS');
            return res.status(503).json({
                error: 'Service de recherche visuelle temporairement indisponible',
                message: 'Veuillez réessayer plus tard'
            });
        }

        // Analyser l'image avec Google Vision
        console.log('\n🤖 STEP 2: Analyse de l\'image avec IA');
        const analysis = await visionService.analyzeImage(req.file.buffer);

        console.log('   - Keywords détectés:', analysis.keywords.map(k => `${k.text} (${k.confidence}%)`).join(', '));
        console.log('   - Couleurs:', analysis.colors.map(c => c.name).join(', '));
        if (analysis.bestGuess) {
            console.log('   - Meilleure hypothèse:', analysis.bestGuess);
        }

        // Construire la liste de termes de recherche
        const searchTerms = [
            ...analysis.keywords.map(k => k.text),
            ...analysis.colors.map(c => c.name),
            ...analysis.textKeywords,
            ...(analysis.bestGuess ? analysis.bestGuess.split(/\s+/) : [])
        ].filter(term => term && term.length > 2); // Filtrer les termes courts

        // Dédupliquer
        const uniqueTerms = [...new Set(searchTerms)];

        console.log('\n🔎 STEP 3: Recherche dans la base de données');
        console.log(`   - Termes de recherche: ${uniqueTerms.slice(0, 10).join(', ')}`);

        // Rechercher les produits correspondants
        const products = await productRepository.searchByKeywords(uniqueTerms, 50);

        console.log(`   - Produits trouvés: ${products.length}`);

        // Formater les produits avec les URLs d'images complètes
        const formattedProducts = products.map(product => {
            return imageService.formatProductImages(product);
        });

        console.log('\n📤 STEP 4: Réponse au client');
        console.log(`   - Renvoi de ${formattedProducts.length} produits`);
        console.log('============================================================');
        console.log('✅ RECHERCHE VISUELLE - SUCCESS');
        console.log('============================================================\n');

        res.json({
            success: true,
            analysis: {
                keywords: analysis.keywords.slice(0, 5), // Top 5 keywords
                colors: analysis.colors,
                confidence: analysis.confidence,
                bestGuess: analysis.bestGuess
            },
            searchTerms: uniqueTerms.slice(0, 10),
            productsCount: formattedProducts.length,
            products: formattedProducts.slice(0, 20) // Top 20 résultats
        });

    } catch (error) {
        console.error('\n💥 ERREUR RECHERCHE VISUELLE');
        console.error('   - Message:', error.message);
        console.error('   - Stack:', error.stack);
        console.log('============================================================');
        console.log('❌ RECHERCHE VISUELLE - FAILED');
        console.log('============================================================\n');

        res.status(500).json({
            success: false,
            error: 'Erreur lors de l\'analyse',
            message: error.message
        });
    }
});

/**
 * GET /search/visual/status
 * Vérifie si le service de recherche visuelle est disponible
 */
router.get('/visual/status', (req, res) => {
    const available = visionService.isAvailable();

    res.json({
        available,
        message: available
            ? 'Service de recherche visuelle opérationnel'
            : 'Service temporairement indisponible'
    });
});

module.exports = router;
