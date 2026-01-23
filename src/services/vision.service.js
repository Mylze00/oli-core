/**
 * Service de Vision par IA pour la recherche visuelle de produits
 * Utilise Google Cloud Vision API pour analyser les images
 */

const vision = require('@google-cloud/vision');

class VisionService {
    constructor() {
        // Initialiser le client Vision API
        // Support de plusieurs méthodes de configuration
        try {
            let clientConfig = {};

            // Méthode 1: JSON credentials dans variable d'environnement (pour Render)
            if (process.env.GOOGLE_CLOUD_CREDENTIALS_JSON) {
                console.log('📋 Utilisation des credentials depuis GOOGLE_CLOUD_CREDENTIALS_JSON');
                const credentials = JSON.parse(process.env.GOOGLE_CLOUD_CREDENTIALS_JSON);
                clientConfig = { credentials };
            }
            // Méthode 2: Fichier credentials (pour développement local)
            else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
                console.log('📋 Utilisation des credentials depuis fichier:', process.env.GOOGLE_APPLICATION_CREDENTIALS);
                // Le SDK utilisera automatiquement la variable d'environnement
                clientConfig = {};
            }
            // Méthode 3: Mode dégradé (désactivé)
            else {
                console.warn('⚠️ Aucun credentials Google Cloud trouvé');
                console.warn('   Définissez GOOGLE_CLOUD_CREDENTIALS_JSON ou GOOGLE_APPLICATION_CREDENTIALS');
                this.client = null;
                return;
            }

            this.client = new vision.ImageAnnotatorClient(clientConfig);
            console.log('✅ Google Cloud Vision API initialisé avec succès');
        } catch (error) {
            console.error('❌ Erreur initialisation Vision API:', error.message);
            this.client = null;
        }
    }

    /**
     * Analyse une image pour extraire des informations pertinentes
     * @param {Buffer} imageBuffer - Buffer de l'image à analyser
     * @returns {Promise<Object>} - Informations extraites (keywords, colors, text)
     */
    async analyzeImage(imageBuffer) {
        if (!this.client) {
            throw new Error('Vision API non initialisée. Vérifiez vos credentials Google Cloud.');
        }

        console.log('🔍 [VisionService] Analyse de l\'image démarrée');
        console.log(`   - Taille: ${imageBuffer.length} bytes`);

        try {
            // 1. Détection de labels (objets, concepts)
            const [labelResult] = await this.client.labelDetection({ image: { content: imageBuffer } });
            const labels = labelResult.labelAnnotations || [];

            console.log(`   - Labels détectés: ${labels.length}`);

            // Filtrer et extraire les labels les plus pertinents
            const keywords = labels
                .filter(label => label.score > 0.7) // Confiance > 70%
                .slice(0, 10) // Top 10
                .map(label => ({
                    text: label.description.toLowerCase(),
                    confidence: Math.round(label.score * 100)
                }));

            // 2. Détection des propriétés de l'image (couleurs dominantes)
            const [propsResult] = await this.client.imageProperties({ image: { content: imageBuffer } });
            const dominantColors = propsResult.imagePropertiesAnnotation?.dominantColors?.colors || [];

            const colors = dominantColors
                .slice(0, 3) // Top 3 couleurs
                .map(colorInfo => {
                    const color = colorInfo.color;
                    const colorName = this.rgbToColorName(color.red || 0, color.green || 0, color.blue || 0);
                    return {
                        name: colorName,
                        rgb: { r: color.red, g: color.green, b: color.blue },
                        score: Math.round(colorInfo.score * 100)
                    };
                });

            console.log(`   - Couleurs dominantes: ${colors.map(c => c.name).join(', ')}`);

            // 3. Détection de texte (marques, prix, etc.)
            const [textResult] = await this.client.textDetection({ image: { content: imageBuffer } });
            const textAnnotations = textResult.textAnnotations || [];
            const detectedText = textAnnotations.length > 0 ? textAnnotations[0].description : '';

            // Extraire des mots-clés du texte détecté
            const textKeywords = detectedText
                .split(/\s+/)
                .filter(word => word.length > 2) // Mots de plus de 2 caractères
                .slice(0, 5); // Max 5 mots

            console.log(`   - Texte détecté: "${detectedText.substring(0, 50)}..."`);

            // 4. Web Detection (optionnel mais utile)
            let bestGuess = null;
            try {
                const [webResult] = await this.client.webDetection({ image: { content: imageBuffer } });
                if (webResult.webDetection?.bestGuessLabels?.length > 0) {
                    bestGuess = webResult.webDetection.bestGuessLabels[0].label;
                    console.log(`   - Meilleure hypothèse: "${bestGuess}"`);
                }
            } catch (e) {
                console.log('   - Web detection non disponible');
            }

            const result = {
                keywords: keywords,
                colors: colors,
                text: detectedText.substring(0, 200), // Limiter à 200 caractères
                textKeywords: textKeywords,
                bestGuess: bestGuess,
                confidence: keywords.length > 0 ? keywords[0].confidence : 0
            };

            console.log('✅ [VisionService] Analyse terminée');
            console.log(`   - ${keywords.length} keywords, ${colors.length} couleurs`);

            return result;

        } catch (error) {
            console.error('❌ [VisionService] Erreur lors de l\'analyse:', error);
            throw new Error(`Erreur Vision API: ${error.message}`);
        }
    }

    /**
     * Convertit des valeurs RGB en nom de couleur
     * @param {number} r - Rouge (0-255)
     * @param {number} g - Vert (0-255)
     * @param {number} b - Bleu (0-255)
     * @returns {string} - Nom de la couleur en français
     */
    rgbToColorName(r, g, b) {
        // Algorithme simple de détection de couleur
        // Peut être amélioré avec une librairie dédiée

        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const diff = max - min;

        // Noir ou blanc
        if (max < 50) return 'noir';
        if (min > 200) return 'blanc';

        // Gris
        if (diff < 40) return 'gris';

        // Couleurs
        if (r > g && r > b) {
            if (g > 100) return 'orange';
            if (b > 100) return 'rose';
            return 'rouge';
        }
        if (g > r && g > b) {
            if (b > 100) return 'cyan';
            if (r > 100) return 'jaune';
            return 'vert';
        }
        if (b > r && b > g) {
            if (r > 100) return 'violet';
            return 'bleu';
        }

        return 'multicolore';
    }

    /**
     * Vérifie si le service est disponible
     */
    isAvailable() {
        return this.client !== null;
    }
}

module.exports = new VisionService();
