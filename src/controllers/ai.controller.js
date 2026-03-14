const { OpenAI } = require('openai');

const analyzeProductImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Aucune image (capture d\'écran) fournie.' });
        }

        // Vérification de la clé API
        if (!process.env.OPENROUTER_API_KEY) {
            console.error('OPENROUTER_API_KEY manquante dans les variables d\'environnement.');
            return res.status(500).json({ error: 'Configuration IA non valide sur le serveur.' });
        }

        const openai = new OpenAI({ 
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: process.env.OPENROUTER_API_KEY 
        });
        
        const base64Image = req.file.buffer.toString('base64');
        const mimeType = req.file.mimetype;
        const dataUrl = `data:${mimeType};base64,${base64Image}`;

        const systemPrompt = `Tu es un expert assistant e-commerce. L'utilisateur va te fournir une capture d'écran d'un produit.
Ton but est d'extraire les informations pertinentes pour pré-remplir un formulaire d'ajout de produit sur une marketplace.
Tu dois répondre STRICTEMENT et UNIQUEMENT avec un objet JSON valide, sans balises markdown, ayant la structure suivante :
{
  "name": "Titre ou nom complet du produit",
  "description": "Description détaillée générée à partir du texte visible ou déduite de l'image. Minimum 2 phrases.",
  "price": montant_numerique (prix estimé ou lu sur l'image, sans devise),
  "currency": "Devise lue (USD, CDF, EUR) ou null",
  "category": "Catégorie suggérée la plus proche (ex: Electronique, Vêtements, Maison...)",
  "weight_kg": poids_estime_en_kg (number, optionnel),
  "condition": "new" ou "used" (neuf ou occasion, "new" par défaut),
  "tags": ["tag1", "tag2", "tag3"]
}`;

        const response = await openai.chat.completions.create({
            model: 'gpt-4o-mini',
            messages: [
                {
                    role: 'system',
                    content: systemPrompt
                },
                {
                    role: 'user',
                    content: [
                        { type: 'text', text: 'Analyse cette annonce/produit et fournis les informations en JSON.' },
                        { type: 'image_url', image_url: { url: dataUrl } }
                    ]
                }
            ],
            response_format: { type: 'json_object' },
            max_tokens: 800
        });

        const responseContent = response.choices[0].message.content;
        const extractedData = JSON.parse(responseContent);

        res.json({
            success: true,
            data: extractedData
        });

    } catch (error) {
        console.error('Erreur AI Vision:', error);
        res.status(500).json({ 
            error: 'Erreur lors de l\'analyse de l\'image par l\'IA.',
            details: error.message 
        });
    }
};

module.exports = {
    analyzeProductImage
};
