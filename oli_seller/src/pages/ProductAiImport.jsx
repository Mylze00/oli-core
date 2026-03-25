import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Image as ImageIcon, Wand2, UploadCloud, CheckCircle2, AlertCircle } from 'lucide-react';
import { productAPI } from '../services/api';

export default function ProductAiImport() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);
    const [files, setFiles] = useState([]);
    const [previewUrls, setPreviewUrls] = useState([]);
    const [isAnalyzing, setIsAnalyzing] = useState(false);
    const [progress, setProgress] = useState(0);
    const [error, setError] = useState(null);

    const handleFileChange = (e) => {
        const selectedFiles = Array.from(e.target.files).filter(f => f.type.startsWith('image/')).slice(0, 5);
        if (selectedFiles.length > 0) {
            setFiles(selectedFiles);
            setPreviewUrls(selectedFiles.map(f => URL.createObjectURL(f)));
            setError(null);
        } else {
            setError("Veuillez sélectionner au moins une image valide (max 5).");
        }
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        e.stopPropagation();
    };

    const handleDrop = (e) => {
        e.preventDefault();
        e.stopPropagation();
        const droppedFiles = Array.from(e.dataTransfer.files).filter(f => f.type.startsWith('image/')).slice(0, 5);
        if (droppedFiles.length > 0) {
            setFiles(droppedFiles);
            setPreviewUrls(droppedFiles.map(f => URL.createObjectURL(f)));
            setError(null);
        } else {
            setError("Veuillez déposer des images valides (max 5).");
        }
    };

    const fileToBase64 = (file) => {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = (e) => {
                const img = new Image();
                img.onload = () => {
                    // Limiter la taille à 800px pour éviter les payload trop volumineux
                    const MAX_SIZE = 800;
                    let width = img.width;
                    let height = img.height;

                    if (width > height) {
                        if (width > MAX_SIZE) {
                            height *= MAX_SIZE / width;
                            width = MAX_SIZE;
                        }
                    } else {
                        if (height > MAX_SIZE) {
                            width *= MAX_SIZE / height;
                            height = MAX_SIZE;
                        }
                    }

                    const canvas = document.createElement('canvas');
                    canvas.width = width;
                    canvas.height = height;

                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);
                    
                    // Compresser en JPEG à 70% de qualité
                    resolve(canvas.toDataURL('image/jpeg', 0.7));
                };
                img.onerror = reject;
                img.src = e.target.result;
            };
            reader.onerror = error => reject(error);
        });
    };

    const handleAnalyze = async () => {
        if (files.length === 0) return;

        try {
            setIsAnalyzing(true);
            setProgress(0);
            setError(null);

            // Simulation de progression UX
            const progressInterval = setInterval(() => {
                setProgress(p => (p < 90 ? p + Math.floor(Math.random() * 10) + 5 : p));
            }, 500);

            const apiKey = import.meta.env.VITE_OPENROUTER_API_KEY;
            if (!apiKey) {
                setError("Clé API OpenRouter manquante dans l'environnement Frontend.");
                return;
            }

            const base64Images = await Promise.all(files.map(f => fileToBase64(f)));
            const imageMessages = base64Images.map(b64 => ({ type: "image_url", image_url: { url: b64 } }));

            const systemPrompt = `Tu es un expert mondial en e-commerce, spécialiste du sourcing depuis la Chine (Taobao, 1688, Alibaba) vers l'Afrique. 
Analyse attentivement ces captures d'écran. Chaque image représente potentiellement un produit différent.
Retourne STRICTEMENT et UNIQUEMENT un objet JSON valide, sans balises markdown, avec la structure suivante :
{
  "products": [
    {
      "name": "Traduis le nom du produit en français très commercial. Max 10 mots.",
      "description": "Description de vente PERCUTANTE en français avec accroche et liste de caractéristiques. Minimum 3 phrases.",
      "specifications": "SPECIFICATIONS TECHNIQUES FONCTIONNELLES OBLIGATOIRES en français. Format : 4 à 8 lignes, une par ligne, '• Clé : Valeur'. Concentre-toi UNIQUEMENT sur les caractéristiques techniques fonctionnelles : processeur, RAM, stockage, connectivité (WiFi/Bluetooth), résolution, capacité batterie, tension/ampérage, protocoles supportés, matière du boîtier, compatibilité système, certifications (CE/RoHS). INTERDIT d'inclure : poids, dimensions physiques, couleur ou variantes de taille (ces infos sont déjà dans d'autres champs). Exemple pour écouteurs : '• Codec audio : AAC, SBC\\n• Autonomie : 6h + 24h boîtier\\n• Bluetooth : 5.3\\n• Réduction de bruit : Oui (ANC)\\n• Résistance : IPX4'. Adapte les critères selon le type d'article.",
      "price_cny": montant_numerique,
      "weight_kg": poids_numerique,
      "category": "Choisis EXACTEMENT UNE clé: industry, home, vehicles, fashion, electronics, sports, beauty, toys, health, construction, tools, office, garden, pets, baby, food, security, other",
      "colors": ["Noir", "Blanc"],
      "sizes": ["M", "L"],
      "brand": "Marque visible sur l'image (OBLIGATOIRE si présente visible, sinon null)",
      "condition": "new",
      "product_type": "Identifie le type PRÉCIS: 'clothing' (vêtements/t-shirts/pantalons/robes), 'shoes' (chaussures/sandales/bottes/baskets), 'accessories' (sacs/ceintures/bijoux), 'electronics', 'furniture', 'other'",
      "variant_images": [
        {
          "label": "Nom court de la variante visible (ex: 'Noir mat', 'Rouge vif', 'Version Pro')",
          "variant_type": "color ou model ou style",
          "description": "Courte description de ce qui distingue visuellement cette variante"
        }
      ]
    }
  ]
}

RÈGLES CRITIQUES POUR LES TAILLES/SIZES:
- Pour les CHAUSSURES/SANDALES/BOTTES (product_type: "shoes"): Utilise UNIQUEMENT des pointures numériques ["36", "37", "38", "39", "40", "41", "42", "43", "44", "45"]
- Pour les VÊTEMENTS (product_type: "clothing"): Utilise UNIQUEMENT les tailles ["XS", "S", "M", "L", "XL", "XXL"]
- Pour les ACCESSOIRES/ÉLECTRONIQUE: Utilise ["Unique"] ou tailles spécifiques visibles (ex: "128GB", "256GB")
- NE MÉLANGE JAMAIS les tailles de vêtements (M, L, XL) avec des chaussures
- VÉRIFIE que product_type et sizes sont cohérents

IMPORTANT VARIANTES VISUELLES (variant_images):
- Regarde ATTENTIVEMENT la capture d'écran pour identifier les variantes visibles (couleurs, modèles, styles)
- Chaque petite image/thumbnail de variante sur la page produit = 1 entrée dans variant_images
- Si tu vois des pastilles de couleur ou des miniatures de variantes, liste-les TOUTES
- Si aucune variante n'est visible, retourne un tableau vide []

IMPORTANT MARQUE: Si une marque est clairement visible sur le produit ou l'emballage, tu DOIS la renseigner. C'est essentiel pour la confiance client.

IMPORTANT: Le nombre d'éléments dans le tableau "products" DOIT EXACTEMENT CORRESPONDRE au nombre d'images fournies. L'index 0 = première image, l'index 1 = deuxième image, etc.`;

            const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${apiKey}`,
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    model: "gpt-4o-mini",
                    response_format: { type: "json_object" },
                    messages: [
                        { role: "system", content: systemPrompt },
                        {
                            role: "user",
                            content: [
                                { type: "text", text: "Analyse ces images de produit et fournis les informations globales en JSON." },
                                ...imageMessages
                            ]
                        }
                    ]
                })
            });

            if (!response.ok) {
                const errData = await response.json();
                throw new Error(errData.error?.message || "Erreur lors de l'appel à OpenRouter");
            }

            const result = await response.json();
            const extractedData = JSON.parse(result.choices[0].message.content);
            const aiProducts = extractedData.products || [];

            // --- Logique de Calcul des prix et du fret pour chaque produit ---
            const freightConfig = {
                aerien: { prix_par_kg: 24, delai_jours: '10 jours (fret aérien)', methodId: 'oli_standard' },
                maritime: { prix_par_m3: 700, delai_jours: '60 jours (fret maritime)', methodId: 'maritime' },
                CNY_to_USD: 0.138,
                marge: 0.43
            };

            const enrichedBatchProducts = aiProducts.map((prod, index) => {
                const priceCny = parseFloat(prod.price_cny) || 0;
                const weightKg = parseFloat(prod.weight_kg) || 0.1;

                // 1. Conversion CNY vers USD
                const priceUsdSource = priceCny * freightConfig.CNY_to_USD;

                // 2. Calcul du Fret Aérien
                const effectiveWeightAir = Math.max(weightKg, 0.02);
                let freightCostAirUsd = effectiveWeightAir * freightConfig.aerien.prix_par_kg;
                // Ajouter 2$ de frais si le fret est inférieur à 5$
                if (freightCostAirUsd < 5) freightCostAirUsd += 2;
                
                // 3. Fret Maritime: calcul basé sur le volume → $700/m³
                const volumeM3 = Math.max(weightKg / 167, 0.005);
                const freightCostSeaUsd = volumeM3 * freightConfig.maritime.prix_par_m3;
                
                const shippingOptions = [
                    {
                        methodId: freightConfig.aerien.methodId,
                        cost: parseFloat(freightCostAirUsd.toFixed(2)),
                        time: freightConfig.aerien.delai_jours
                    },
                    {
                        methodId: freightConfig.maritime.methodId,
                        cost: parseFloat(freightCostSeaUsd.toFixed(2)),
                        time: freightConfig.maritime.delai_jours
                    }
                ];

                // 4. Prix final du produit
                const finalPriceUsd = priceUsdSource * (1 + freightConfig.marge);

                // 5. Validation des tailles selon product_type
                let validatedSizes = prod.sizes || [];
                const productType = prod.product_type || 'other';
                
                if (productType === 'shoes') {
                    // Pour chaussures: garder uniquement les pointures numériques
                    validatedSizes = validatedSizes.filter(size => /^\d+$/.test(size));
                    // Si vide, mettre des tailles par défaut
                    if (validatedSizes.length === 0) {
                        validatedSizes = ['39', '40', '41', '42', '43'];
                    }
                } else if (productType === 'clothing') {
                    // Pour vêtements: garder uniquement XS, S, M, L, XL, XXL
                    const clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
                    validatedSizes = validatedSizes.filter(size => clothingSizes.includes(size.toUpperCase()));
                    if (validatedSizes.length === 0) {
                        validatedSizes = ['M', 'L', 'XL'];
                    }
                }

                return {
                    ...prod,
                    price: parseFloat(finalPriceUsd.toFixed(2)),
                    originalPriceCny: priceCny,
                    weight_kg: weightKg,
                    brand: prod.brand || null,
                    brand_certified: !!prod.brand,
                    brand_display_name: prod.brand || '',
                    specifications: prod.specifications || '',
                    shippingOptions: shippingOptions,
                    description: prod.description,
                    sizes: validatedSizes,
                    product_type: productType,
                    variant_images: prod.variant_images || [],
                    aiImageIndex: index
                };
            });

            clearInterval(progressInterval);
            setProgress(100);

            // Navigation vers Publication en Lot (Batch)
            navigate('/products/new/batch', {
                state: {
                    aiBatchProducts: enrichedBatchProducts,
                    aiImages: base64Images
                }
            });
            // PAS D'ACTION SUR LE STATE ICI
        } catch (err) {
            console.error('Analysis error:', err);
            setError(err.message || "Une erreur s'est produite lors de la connexion à l'IA.");
            setIsAnalyzing(false); // On rétablit l'état uniquement en cas d'erreur
            setProgress(0);
        }
    };

    return (
        <div className="p-8 max-w-4xl mx-auto" translate="no">
            <button
                onClick={() => navigate('/products/new')}
                className="text-gray-500 flex items-center gap-2 mb-6 hover:text-gray-900 transition-colors"
                disabled={isAnalyzing}
            >
                <ArrowLeft size={16} /> Retour aux modes
            </button>

            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-8">
                <div className="text-center mb-8">
                    <div className="w-16 h-16 bg-purple-100 text-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Wand2 size={32} />
                    </div>
                    <h1 className="text-2xl font-bold text-gray-900 mb-2">
                        Importation Magique par IA
                    </h1>
                    <p className="text-gray-500">
                        Téléchargez une capture d'écran de l'article (depuis Alibaba, Amazon, ou autre). Notre IA va lire l'image et pré-remplir votre fiche produit complète !
                    </p>
                </div>

                {error && (
                    <div className="mb-6 p-4 bg-red-50 text-red-600 rounded-xl flex items-center gap-3">
                        <AlertCircle size={20} />
                        <p className="font-medium text-sm">{error}</p>
                    </div>
                )}

                <div
                    className={`border-2 border-dashed rounded-2xl p-8 text-center transition-all ${previewUrls.length > 0 ? 'border-purple-300 bg-purple-50' : 'border-gray-300 hover:border-purple-400 hover:bg-purple-50'}`}
                    onDragOver={handleDragOver}
                    onDrop={handleDrop}
                    onClick={() => !isAnalyzing && fileInputRef.current?.click()}
                >
                    <input
                        type="file"
                        ref={fileInputRef}
                        className="hidden"
                        accept="image/*"
                        multiple
                        onChange={handleFileChange}
                    />

                    {previewUrls.length > 0 ? (
                        <div className="flex flex-col items-center">
                            <div className="flex flex-wrap justify-center gap-4 mb-4">
                                {previewUrls.map((url, idx) => (
                                    <img
                                        key={idx}
                                        src={url}
                                        alt={`Aperçu ${idx + 1}`}
                                        className="h-32 w-auto rounded-lg shadow-sm object-cover border border-purple-200"
                                    />
                                ))}
                            </div>
                            <p className="text-sm text-gray-500">Cliquez ou glissez pour remplacer les images ({previewUrls.length}/5)</p>
                        </div>
                    ) : (
                        <div className="flex flex-col items-center py-8">
                            <UploadCloud size={48} className="text-purple-400 mb-4" />
                            <h3 className="text-lg font-semibold text-gray-900 mb-1">
                                Déposez vos captures ici (Max 5)
                            </h3>
                            <p className="text-gray-500 text-sm mb-4">
                                PNG, JPG ou WEBP (Max. 5 MB)
                            </p>
                            <button className="px-6 py-2 bg-purple-100 text-purple-700 font-medium rounded-lg hover:bg-purple-200 transition-colors">
                                Parcourir les fichiers
                            </button>
                        </div>
                    )}
                </div>

                <div className="mt-8 flex justify-end">
                    <button
                        onClick={handleAnalyze}
                        disabled={files.length === 0 || isAnalyzing}
                        className={`px-8 py-3 rounded-xl font-bold flex flex-col items-center gap-2 transition-all w-full md:w-auto ${(files.length === 0 || isAnalyzing) ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-purple-600 text-white hover:bg-purple-700 shadow-md hover:shadow-lg'}`}
                    >
                        {isAnalyzing ? (
                            <div className="flex flex-col items-center w-full min-w-[220px]">
                                <div className="flex items-center gap-2 mb-2">
                                    <div className="w-5 h-5 border-2 border-purple-400 border-t-purple-600 rounded-full animate-spin" />
                                    <span>Analyse en cours... {progress}%</span>
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-1.5">
                                    <div 
                                        className="bg-purple-600 h-1.5 rounded-full transition-all duration-300" 
                                        style={{ width: `${progress}%` }}
                                    ></div>
                                </div>
                            </div>
                        ) : (
                            <div className="flex items-center gap-2">
                                <Wand2 size={20} />
                                Analyser et Pré-remplir
                            </div>
                        )}
                    </button>
                </div>
            </div>

            <div className="mt-6 flex items-start gap-4 p-4 bg-gray-50 rounded-xl">
                <CheckCircle2 className="text-emerald-500 shrink-0 mt-1" size={24} />
                <div>
                    <h4 className="font-semibold text-gray-900">Que gardez-vous à faire ?</h4>
                    <p className="text-sm text-gray-600 mt-1">Vous aurez l'occasion de vérifier et modifier toutes les informations déduites par l'IA dans l'écran suivant avant de valider la publication de l'article.</p>
                </div>
            </div>
        </div>
    );
}
