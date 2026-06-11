import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Image as ImageIcon, Wand2, UploadCloud, CheckCircle2, AlertCircle, FileText } from 'lucide-react';
import { productAPI } from '../services/api';

export default function ProductAiImport() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);
    const [files, setFiles] = useState([]);
    const [csvFile, setCsvFile] = useState(null);
    const [previewUrls, setPreviewUrls] = useState([]);
    const [isAnalyzing, setIsAnalyzing] = useState(false);
    const [progress, setProgress] = useState(0);
    const [error, setError] = useState(null);

    const handleFileChange = (e) => {
        const selectedFiles = Array.from(e.target.files);
        if (selectedFiles.length === 0) return;

        const firstFile = selectedFiles[0];
        if (firstFile.name.toLowerCase().endsWith('.csv')) {
            setCsvFile(firstFile);
            setFiles([]);
            setPreviewUrls([]);
            setError(null);
            return;
        }

        const imageFiles = selectedFiles.filter(f => f.type.startsWith('image/')).slice(0, 5);
        if (imageFiles.length > 0) {
            setFiles(imageFiles);
            setCsvFile(null);
            setPreviewUrls(imageFiles.map(f => URL.createObjectURL(f)));
            setError(null);
        } else {
            setError("Veuillez sélectionner des images valides (max 5) ou un fichier CSV.");
        }
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        e.stopPropagation();
    };

    const handleDrop = (e) => {
        e.preventDefault();
        e.stopPropagation();
        const droppedFiles = Array.from(e.dataTransfer.files);
        if (droppedFiles.length === 0) return;

        const firstFile = droppedFiles[0];
        if (firstFile.name.toLowerCase().endsWith('.csv')) {
            setCsvFile(firstFile);
            setFiles([]);
            setPreviewUrls([]);
            setError(null);
            return;
        }

        const imageFiles = droppedFiles.filter(f => f.type.startsWith('image/')).slice(0, 5);
        if (imageFiles.length > 0) {
            setFiles(imageFiles);
            setCsvFile(null);
            setPreviewUrls(imageFiles.map(f => URL.createObjectURL(f)));
            setError(null);
        } else {
            setError("Veuillez déposer des images valides (max 5) ou un fichier CSV.");
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
        if (files.length === 0 && !csvFile) return;

        try {
            setIsAnalyzing(true);
            setProgress(0);
            setError(null);

            const progressInterval = setInterval(() => {
                setProgress(p => (p < 90 ? p + Math.floor(Math.random() * 10) + 5 : p));
            }, 500);

            const apiKey = import.meta.env.VITE_OPENROUTER_API_KEY;
            if (!apiKey) {
                setError("Clé API OpenRouter manquante dans l'environnement.");
                setIsAnalyzing(false);
                clearInterval(progressInterval);
                return;
            }

            let aiProducts = [];
            let generatedBase64Images = [];

            if (csvFile) {
                // LOGIQUE CSV
                const text = await csvFile.text();
                const systemPromptCsv = `Tu es un expert en e-commerce. Tu vas recevoir un CSV contenant des produits bruts.
Analyse chaque ligne et retourne STRICTEMENT un JSON ayant cette structure :
{
  "products": [
    {
      "name": "Titre traduit en français très commercial",
      "description": "Description de vente percutante en français",
      "price_cny": prix_numerique_extrait,
      "weight_kg": 0.5,
      "category": "industry, home, vehicles, fashion, electronics, sports, beauty, toys, health, construction, tools, office, garden, pets, baby, food, security, ou other",
      "product_type": "clothing, shoes, accessories, electronics, furniture, ou other",
      "brand": "Marque si présente, sinon null",
      "colors": ["Couleur1", "Couleur2"],
      "sizes": ["Taille1", "Taille2"],
      "images_sources": ["URL1.jpg", "URL2.jpg"]
    }
  ]
}
Extrais TOUS les produits trouvés dans le CSV (max 20). Ne filtre rien.
Pour "images_sources", retourne un tableau d'URL directes d'images (max 6). Cherche dans toutes les colonnes contenant des URLs (notamment la colonne 'images' ou 'imageUrl' qui peut contenir plusieurs URLs séparées par des points-virgules).
Pour "colors" et "sizes", essaie de les déduire des titres/descriptions, ou laisse vide.
Convertis toujours les prix CNY en format numérique. Retourne STRICTEMENT un JSON valide.`;

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
                            { role: "system", content: systemPromptCsv },
                            { role: "user", content: `Voici le CSV :\n${text}` }
                        ]
                    })
                });

                if (!response.ok) throw new Error("Erreur IA lors de la lecture du CSV.");
                
                const result = await response.json();
                const extractedData = JSON.parse(result.choices[0].message.content);
                aiProducts = extractedData.products || [];
                console.log("Produits extraits par l'IA :", aiProducts);

                if (aiProducts.length === 0) {
                    throw new Error("L'IA n'a trouvé aucun produit valide dans ce fichier. Vérifiez le format du CSV.");
                }

                // Upload Cloudinary pour chaque produit
                for (let i = 0; i < aiProducts.length; i++) {
                    const prod = aiProducts[i];
                    prod.aiImageIndex = -1;
                    prod.additionalImageIndexes = [];

                    let urlsToFetch = [];
                    if (prod.images_sources && Array.isArray(prod.images_sources)) {
                        urlsToFetch = prod.images_sources.slice(0, 6); // Max 6 images
                    } else if (prod.image_url_source && prod.image_url_source.trim() !== "") {
                        urlsToFetch = [prod.image_url_source];
                    }

                    if (urlsToFetch.length > 0) {
                        for (const url of urlsToFetch) {
                            if (!url || url.trim() === "") continue;
                            console.log(`Tentative d'upload de l'image pour ${prod.name}: ${url}`);
                            try {
                                const uploadRes = await productAPI.uploadImageFromUrl(url);
                                if (uploadRes.success && uploadRes.secure_url) {
                                    const imgRes = await fetch(uploadRes.secure_url);
                                    const blob = await imgRes.blob();
                                    const reader = new FileReader();
                                    const b64 = await new Promise(res => {
                                        reader.onloadend = () => res(reader.result);
                                        reader.readAsDataURL(blob);
                                    });
                                    generatedBase64Images.push(b64);
                                    const newIndex = generatedBase64Images.length - 1;
                                    
                                    if (prod.aiImageIndex === -1) {
                                        prod.aiImageIndex = newIndex;
                                    } else {
                                        prod.additionalImageIndexes.push(newIndex);
                                    }
                                } else {
                                    console.warn("Upload backend failed for", url);
                                }
                            } catch (e) {
                                console.error("Erreur upload Cloudinary/Backend", e);
                            }
                        }
                    } else {
                        console.warn(`Aucune image trouvée par l'IA pour ${prod.name}`);
                    }
                }

            } else {
                // LOGIQUE IMAGES
                generatedBase64Images = await Promise.all(files.map(f => fileToBase64(f)));
                const imageMessages = generatedBase64Images.map(b64 => ({ type: "image_url", image_url: { url: b64 } }));

                const systemPromptImg = `Tu es un expert mondial en e-commerce. Analyse ces captures d'écran et retourne STRICTEMENT un JSON valide :
{
  "products": [
    {
      "name": "Traduis le nom du produit en français très commercial. Max 10 mots.",
      "description": "Description de vente PERCUTANTE en français avec accroche et caractéristiques.",
      "specifications": "Spécifications techniques...",
      "price_cny": montant_numerique,
      "weight_kg": poids_numerique,
      "category": "industry, home, vehicles, fashion, electronics, sports, beauty, toys, health, construction, tools, office, garden, pets, baby, food, security, other",
      "colors": ["Noir", "Blanc"],
      "sizes": ["M", "L"],
      "brand": "Marque visible sur l'image ou null",
      "condition": "new",
      "product_type": "clothing, shoes, accessories, electronics, furniture, other",
      "variant_images": []
    }
  ]
}
IMPORTANT: Le nombre d'éléments dans "products" DOIT EXACTEMENT CORRESPONDRE au nombre d'images. Index 0 = image 1, etc.`;

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
                            { role: "system", content: systemPromptImg },
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

                if (!response.ok) throw new Error("Erreur IA sur les images.");
                const result = await response.json();
                const extractedData = JSON.parse(result.choices[0].message.content);
                aiProducts = extractedData.products || [];
                
                // Mappage index IA avec Base64
                aiProducts.forEach((p, idx) => {
                    p.aiImageIndex = idx;
                });
            }

            // --- Logique de Calcul des prix et du fret pour chaque produit ---
            const freightConfig = {
                aerien: { prix_par_kg: 24, delai_jours: '10 jours (fret aérien)', methodId: 'oli_standard' },
                maritime: { prix_par_m3: 700, delai_jours: '60 jours (fret maritime)', methodId: 'maritime' },
                CNY_to_USD: 0.138,
                marge: 0.35 // Marge de 35% comme demandée
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
                const freightCostSeaUsdRaw = volumeM3 * freightConfig.maritime.prix_par_m3;
                // Garantir un coût maritime minimum de $1 pour les petits articles
                const freightCostSeaUsd = Math.max(freightCostSeaUsdRaw, 1.0);
                
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
                    brand_certified: !!prod.brand,         // toujours boolean (true si marque détectée)
                    brand_display_name: prod.brand || '',
                    specifications: prod.specifications || '',
                    shippingOptions: shippingOptions,
                    description: prod.description,
                    sizes: validatedSizes,
                    product_type: productType,
                    variant_images: prod.variant_images || [],
                    aiImageIndex: prod.aiImageIndex !== undefined ? prod.aiImageIndex : index,
                    additionalImageIndexes: prod.additionalImageIndexes || []
                };
            });

            clearInterval(progressInterval);
            setProgress(100);

            // Navigation vers Publication en Lot (Batch)
            navigate('/products/new/batch', {
                state: {
                    aiBatchProducts: enrichedBatchProducts,
                    aiImages: generatedBase64Images
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
                    className={`border-2 border-dashed rounded-2xl p-8 text-center transition-all ${(previewUrls.length > 0 || csvFile) ? 'border-purple-300 bg-purple-50' : 'border-gray-300 hover:border-purple-400 hover:bg-purple-50'}`}
                    onDragOver={handleDragOver}
                    onDrop={handleDrop}
                    onClick={() => !isAnalyzing && fileInputRef.current?.click()}
                >
                    <input
                        type="file"
                        ref={fileInputRef}
                        className="hidden"
                        accept="image/*,.csv"
                        multiple
                        onChange={handleFileChange}
                    />

                    {csvFile ? (
                        <div className="flex flex-col items-center py-6">
                            <FileText size={48} className="text-purple-500 mb-4" />
                            <h3 className="text-lg font-semibold text-gray-900">
                                {csvFile.name}
                            </h3>
                            <p className="text-sm text-gray-500 mt-2">
                                Prêt pour l'analyse et le téléchargement des images via Cloudinary.
                            </p>
                        </div>
                    ) : previewUrls.length > 0 ? (
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
                                PNG, JPG, WEBP (Max 5) ou fichier .CSV
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
                        disabled={(files.length === 0 && !csvFile) || isAnalyzing}
                        className={`px-8 py-3 rounded-xl font-bold flex flex-col items-center gap-2 transition-all w-full md:w-auto ${((files.length === 0 && !csvFile) || isAnalyzing) ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-purple-600 text-white hover:bg-purple-700 shadow-md hover:shadow-lg'}`}
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
