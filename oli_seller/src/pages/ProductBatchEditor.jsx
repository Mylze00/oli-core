import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
    ArrowLeft, Save, Loader2, X, CheckCircle, AlertTriangle,
    Plus, Trash, Truck, Layers, ChevronDown, ChevronUp, Image as ImageIcon
} from 'lucide-react';
import api from '../services/api';

// ── Constantes ──────────────────────────────────────────────

const CATEGORIES = [
    { key: 'industry', label: 'Industrie', emoji: '🏭' },
    { key: 'home', label: 'Maison', emoji: '🏠' },
    { key: 'vehicles', label: 'Véhicules', emoji: '🚗' },
    { key: 'fashion', label: 'Mode', emoji: '👗' },
    { key: 'electronics', label: 'Électronique', emoji: '📱' },
    { key: 'sports', label: 'Sports', emoji: '⚽' },
    { key: 'beauty', label: 'Beauté', emoji: '💄' },
    { key: 'toys', label: 'Jouets', emoji: '🧸' },
    { key: 'health', label: 'Santé', emoji: '🏥' },
    { key: 'construction', label: 'Construction', emoji: '🏗️' },
    { key: 'tools', label: 'Outils', emoji: '🔧' },
    { key: 'office', label: 'Bureau', emoji: '🖥️' },
    { key: 'garden', label: 'Jardin', emoji: '🌿' },
    { key: 'pets', label: 'Animaux', emoji: '🐾' },
    { key: 'baby', label: 'Bébé', emoji: '👶' },
    { key: 'food', label: 'Alimentation', emoji: '🍎' },
    { key: 'security', label: 'Sécurité', emoji: '🔒' },
    { key: 'other', label: 'Autres', emoji: '📦' },
];

const PRESET_COLORS = [
    { name: 'Noir', hex: '#1a1a1a' },
    { name: 'Blanc', hex: '#f5f5f5' },
    { name: 'Rouge', hex: '#ef4444' },
    { name: 'Bleu', hex: '#3b82f6' },
    { name: 'Vert', hex: '#22c55e' },
    { name: 'Jaune', hex: '#eab308' },
    { name: 'Rose', hex: '#ec4899' },
    { name: 'Orange', hex: '#f97316' },
    { name: 'Violet', hex: '#a855f7' },
    { name: 'Gris', hex: '#9ca3af' },
    { name: 'Marron', hex: '#92400e' },
    { name: 'Beige', hex: '#d4a574' },
];

const AVAILABLE_METHODS = [
    { id: 'oli_express', label: 'Oli Express', time: '1-2h', icon: '⚡' },
    { id: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', icon: '📦' },
    { id: 'partner', label: 'Livreur Partenaire', time: 'Variable', icon: '🏍️' },
    { id: 'hand_delivery', label: 'Remise en Main Propre', time: 'À convenir', icon: '🤝' },
    { id: 'pick_go', label: 'Pick & Go', time: 'Retrait immédiat', icon: '🏪' },
    { id: 'free', label: 'Livraison Gratuite', time: '3-7 jours', icon: '🎁' },
    { id: 'maritime', label: 'Livraison Maritime', time: '60 jours', icon: '🚢' },
];

const PHOTO_SLOTS = [
    { label: 'Face', icon: '📸' },
    { label: 'Dos / Côté', icon: '🔄' },
    { label: 'Étiquette', icon: '🏷️' },
    { label: 'Détail / Défaut', icon: '🔍' },
    { label: 'Autre', icon: '📷' },
];

// ── Composant principal ─────────────────────────────────────

export default function ProductBatchEditor() {
    const navigate = useNavigate();
    const location = useLocation();
    const [products, setProducts] = useState([]);
    const [aiImages, setAiImages] = useState([]);
    const [expandedIndex, setExpandedIndex] = useState(0);
    const [publishing, setPublishing] = useState(null); // index du produit en cours
    const [publishedIds, setPublishedIds] = useState([]); // indices publiés
    const [errors, setErrors] = useState({}); // erreurs par index
    const [globalError, setGlobalError] = useState(null);

    // ── Initialiser depuis les données AI ──
    useEffect(() => {
        const state = location.state;
        if (!state?.aiBatchProducts || !Array.isArray(state.aiBatchProducts)) {
            setGlobalError("Aucune donnée produit reçue. Retournez à l'import IA.");
            return;
        }

        const enriched = state.aiBatchProducts.map((prod, i) => {
            // Convertir l'image AI initiale en un vrai File/Preview
            const aiB64 = state.aiImages[prod.aiImageIndex ?? i];
            const initialFiles = [];
            const initialPreviews = [];
            if (aiB64) {
                const f = base64ToFileUtil(aiB64, i);
                if (f) {
                    initialFiles.push(f);
                    initialPreviews.push(URL.createObjectURL(f));
                }
            }

            return {
                ...prod,
                selectedColors: prod.colors || [],
                selectedSizes: prod.sizes || [],
                customColorInput: '',
                customSizeInput: '',
                selectedVariantImages: (prod.variant_images || []).map((_, idx) => idx), // all selected by default
                shippingOptions: prod.shippingOptions || [
                    { methodId: 'oli_standard', cost: 0, time: '10 jours (fret aérien)' }
                ],
                // On ajoute les vrais fichiers à envoyer au lieu d'utiliser l'index
                images: initialFiles,
                imagePreviews: initialPreviews,
            };
        });

        setProducts(enriched);
        setAiImages(state.aiImages || []);

        return () => {
            // Nettoyer les blob URLs au démontage
            enriched.forEach(p => p.imagePreviews.forEach(url => URL.revokeObjectURL(url)));
        };
    }, [location.state]);

    // Outil utilitaire pour l'initialisation (hoisted)
    const base64ToFileUtil = (base64String, index = 0) => {
        try {
            let mimeType = 'image/jpeg';
            if (base64String.startsWith('data:')) {
                mimeType = base64String.split(';')[0].split(':')[1];
            }
            const byteCharacters = atob(base64String.split(',')[1]);
            const byteArrays = [];
            for (let offset = 0; offset < byteCharacters.length; offset += 512) {
                const slice = byteCharacters.slice(offset, offset + 512);
                const byteNumbers = new Array(slice.length);
                for (let j = 0; j < slice.length; j++) {
                    byteNumbers[j] = slice.charCodeAt(j);
                }
                byteArrays.push(new Uint8Array(byteNumbers));
            }
            const blob = new Blob(byteArrays, { type: mimeType });
            return new File([blob], `ai-product-${index + 1}.jpg`, { type: mimeType });
        } catch (e) {
            console.error('base64ToFile error:', e);
            return null;
        }
    };

    // ── Mise à jour d'un produit ──
    const updateProduct = (index, field, value) => {
        setProducts(prev => prev.map((p, i) => i === index ? { ...p, [field]: value } : p));
    };

    // ── Variantes couleurs ──
    const toggleColor = (index, color) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== index) return p;
            const has = p.selectedColors.includes(color);
            return {
                ...p,
                selectedColors: has
                    ? p.selectedColors.filter(c => c !== color)
                    : [...p.selectedColors, color]
            };
        }));
    };

    const addCustomColor = (index) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== index) return p;
            const v = (p.customColorInput || '').trim();
            if (!v || p.selectedColors.includes(v)) return { ...p, customColorInput: '' };
            return { ...p, selectedColors: [...p.selectedColors, v], customColorInput: '' };
        }));
    };

    // ── Variantes tailles ──
    const toggleSize = (index, size) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== index) return p;
            const has = p.selectedSizes.includes(size);
            return {
                ...p,
                selectedSizes: has
                    ? p.selectedSizes.filter(s => s !== size)
                    : [...p.selectedSizes, size]
            };
        }));
    };

    const addCustomSize = (index) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== index) return p;
            const v = (p.customSizeInput || '').trim();
            if (!v || p.selectedSizes.includes(v)) return { ...p, customSizeInput: '' };
            return { ...p, selectedSizes: [...p.selectedSizes, v], customSizeInput: '' };
        }));
    };

    // ── Variantes images ──
    const toggleVariantImage = (prodIndex, variantIndex) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== prodIndex) return p;
            const has = p.selectedVariantImages.includes(variantIndex);
            return {
                ...p,
                selectedVariantImages: has
                    ? p.selectedVariantImages.filter(vi => vi !== variantIndex)
                    : [...p.selectedVariantImages, variantIndex]
            };
        }));
    };

    // ── Shipping ──
    const addShippingOption = (index) => {
        setProducts(prev => prev.map((p, i) =>
            i === index
                ? { ...p, shippingOptions: [...p.shippingOptions, { methodId: '', cost: '', time: '' }] }
                : p
        ));
    };

    const updateShippingOption = (prodIndex, optionIndex, field, value) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== prodIndex) return p;
            const opts = [...p.shippingOptions];
            if (field === 'methodId') {
                const method = AVAILABLE_METHODS.find(m => m.id === value);
                if (method) opts[optionIndex].time = method.time;
                if (value === 'free' || value === 'hand_delivery') opts[optionIndex].cost = 0;
            }
            opts[optionIndex][field] = value;
            return { ...p, shippingOptions: opts };
        }));
    };

    const removeShippingOption = (prodIndex, optionIndex) => {
        setProducts(prev => prev.map((p, i) =>
            i === prodIndex
                ? { ...p, shippingOptions: p.shippingOptions.filter((_, j) => j !== optionIndex) }
                : p
        ));
    };

    // ── Base64 → File ──
    const base64ToFile = (base64String, index = 0) => {
        try {
            let mimeType = 'image/jpeg';
            if (base64String.startsWith('data:')) {
                mimeType = base64String.split(';')[0].split(':')[1];
            }
            const byteCharacters = atob(base64String.split(',')[1]);
            const byteArrays = [];
            for (let offset = 0; offset < byteCharacters.length; offset += 512) {
                const slice = byteCharacters.slice(offset, offset + 512);
                const byteNumbers = new Array(slice.length);
                for (let j = 0; j < slice.length; j++) {
                    byteNumbers[j] = slice.charCodeAt(j);
                }
                byteArrays.push(new Uint8Array(byteNumbers));
            }
            const blob = new Blob(byteArrays, { type: mimeType });
            return new File([blob], `ai-product-${index + 1}.jpg`, { type: mimeType });
        } catch (e) {
            console.error('base64ToFile error:', e);
            return null;
        }
    };

    // ── Gestion personnalisée des images prêtes à publier ──
    const handleImageSlot = (prodIndex, slotIndex) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.onchange = (e) => {
            const file = e.target.files[0];
            if (!file) return;

            setProducts(prev => prev.map((p, i) => {
                if (i !== prodIndex) return p;
                
                const newImages = [...p.images];
                const newPreviews = [...p.imagePreviews];

                if (slotIndex < p.images.length) {
                    URL.revokeObjectURL(newPreviews[slotIndex]);
                    newImages[slotIndex] = file;
                    newPreviews[slotIndex] = URL.createObjectURL(file);
                } else {
                    newImages.push(file);
                    newPreviews.push(URL.createObjectURL(file));
                }

                return { ...p, images: newImages, imagePreviews: newPreviews };
            }));
        };
        input.click();
    };

    const handleMultipleImages = (prodIndex) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.multiple = true;
        input.onchange = (e) => {
            const files = Array.from(e.target.files);
            
            setProducts(prev => prev.map((p, i) => {
                if (i !== prodIndex) return p;
                
                const remaining = 8 - p.images.length;
                if (remaining <= 0) return p; // full

                const toAdd = files.slice(0, remaining);
                return {
                    ...p,
                    images: [...p.images, ...toAdd],
                    imagePreviews: [...p.imagePreviews, ...toAdd.map(f => URL.createObjectURL(f))]
                };
            }));
        };
        input.click();
    };

    const removeImage = (prodIndex, imgIndex) => {
        setProducts(prev => prev.map((p, i) => {
            if (i !== prodIndex) return p;

            URL.revokeObjectURL(p.imagePreviews[imgIndex]);

            return {
                ...p,
                images: p.images.filter((_, idx) => idx !== imgIndex),
                imagePreviews: p.imagePreviews.filter((_, idx) => idx !== imgIndex)
            };
        }));
    };

    // ── Validation ──
    const validateProduct = (prod, index) => {
        const issues = [];
        if (!prod.images || prod.images.length === 0) issues.push('Ajoutez au moins une photo');
        if (!prod.name || !prod.name.trim()) issues.push('Nom du produit requis');
        if (!prod.price || prod.price <= 0) issues.push('Prix invalide');
        if (prod.selectedColors.length === 0 && prod.selectedSizes.length === 0) {
            issues.push('⚠️ Ajoutez au moins une variante (couleur ou taille) pour publier');
        }
        if (prod.shippingOptions.length === 0 || !prod.shippingOptions[0].methodId) {
            issues.push('Sélectionnez au moins un mode de livraison');
        }
        return issues;
    };

    // ── Publication d'un produit ──
    const publishProduct = async (index) => {
        const prod = products[index];
        const issues = validateProduct(prod, index);
        if (issues.length > 0) {
            setErrors(prev => ({ ...prev, [index]: issues }));
            return;
        }

        setErrors(prev => ({ ...prev, [index]: null }));
        setPublishing(index);

        try {
            const formData = new FormData();
            formData.append('name', prod.name);
            formData.append('price', prod.price);
            formData.append('description', prod.description || '');
            formData.append('category', prod.category || 'other');
            formData.append('condition', prod.condition || 'new');
            formData.append('quantity', '1');
            formData.append('weight', prod.weight_kg || '');

            // Brand — toujours envoyé pour que le backend l'écrive correctement en DB
            formData.append('brand_certified', prod.brand_certified ? 'true' : 'false');
            if (prod.brand) {
                formData.append('brand_display_name', prod.brand);
            }

            // Specifications
            if (prod.specifications) {
                formData.append('specifications', prod.specifications);
            }

            // Shipping options
            formData.append('shipping_options', JSON.stringify(prod.shippingOptions));

            // Variantes
            const variants = [
                ...prod.selectedColors.map(v => ({ variant_type: 'color', variant_value: v })),
                ...prod.selectedSizes.map(v => ({ variant_type: 'size', variant_value: v })),
            ];
            if (variants.length > 0) {
                formData.append('variants', JSON.stringify(variants));
            }

            // Images validées (modifiées, rajoutées ou originales par le vendeur)
            if (prod.images && prod.images.length > 0) {
                prod.images.forEach(img => {
                    formData.append('images', img);
                });
            }

            await api.post('/products/upload', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });

            setPublishedIds(prev => [...prev, index]);
        } catch (err) {
            console.error('Publish error:', err);
            setErrors(prev => ({
                ...prev,
                [index]: [`Erreur: ${err.response?.data?.error || err.message}`]
            }));
        } finally {
            setPublishing(null);
        }
    };

    // ── Publication en lot ──
    const publishAll = async () => {
        // Valider tous d'abord
        let hasError = false;
        const newErrors = {};
        products.forEach((prod, i) => {
            if (publishedIds.includes(i)) return;
            const issues = validateProduct(prod, i);
            if (issues.length > 0) {
                newErrors[i] = issues;
                hasError = true;
            }
        });

        if (hasError) {
            setErrors(newErrors);
            return;
        }

        // Publier séquentiellement
        for (let i = 0; i < products.length; i++) {
            if (publishedIds.includes(i)) continue;
            await publishProduct(i);
        }
    };

    // ── Tailles preset par product_type ──
    const getSizesForType = (productType) => {
        if (productType === 'shoes') {
            return ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45'];
        }
        if (productType === 'clothing') {
            return ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
        }
        return ['Unique'];
    };

    // ── Rendu ──
    if (globalError) {
        return (
            <div className="p-8 max-w-4xl mx-auto">
                <div className="bg-red-50 border border-red-200 rounded-xl p-8 text-center">
                    <AlertTriangle size={48} className="text-red-400 mx-auto mb-4" />
                    <p className="text-red-600 font-medium mb-4">{globalError}</p>
                    <button
                        onClick={() => navigate('/products/new/ai-import')}
                        className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                    >
                        Retour à l'import IA
                    </button>
                </div>
            </div>
        );
    }

    if (products.length === 0) {
        return (
            <div className="flex items-center justify-center h-96">
                <Loader2 className="animate-spin text-purple-600" size={32} />
            </div>
        );
    }

    const allPublished = products.every((_, i) => publishedIds.includes(i));

    return (
        <div className="p-6 max-w-5xl mx-auto" translate="no">
            {/* Header */}
            <button
                onClick={() => navigate('/products/new/ai-import')}
                className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900 transition-colors"
            >
                <ArrowLeft size={16} /> Retour à l'import IA
            </button>

            <div className="flex justify-between items-start mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">📦 Publication en Lot</h1>
                    <p className="text-gray-500 text-sm mt-1">
                        {products.length} produit(s) détecté(s) — Vérifiez et complétez chaque fiche avant publication.
                    </p>
                </div>
                {!allPublished && (
                    <button
                        onClick={publishAll}
                        disabled={publishing !== null}
                        className="flex items-center gap-2 px-5 py-2.5 bg-purple-600 text-white font-semibold rounded-xl hover:bg-purple-700 transition-colors disabled:opacity-50"
                    >
                        {publishing !== null ? (
                            <Loader2 className="animate-spin" size={16} />
                        ) : (
                            <Save size={16} />
                        )}
                        Publier tout ({products.length - publishedIds.length})
                    </button>
                )}
                {allPublished && (
                    <button
                        onClick={() => navigate('/products')}
                        className="flex items-center gap-2 px-5 py-2.5 bg-green-600 text-white font-semibold rounded-xl hover:bg-green-700"
                    >
                        <CheckCircle size={16} /> Voir mes produits
                    </button>
                )}
            </div>

            {/* Product Cards */}
            <div className="space-y-4">
                {products.map((prod, index) => {
                    const isExpanded = expandedIndex === index;
                    const isPublished = publishedIds.includes(index);
                    const isPublishing = publishing === index;
                    const prodErrors = errors[index];
                    const hasVariants = prod.selectedColors.length > 0 || prod.selectedSizes.length > 0;
                    const presetSizes = getSizesForType(prod.product_type);
                    const catObj = CATEGORIES.find(c => c.key === prod.category);

                    return (
                        <div
                            key={index}
                            className={`bg-white rounded-xl shadow-sm border transition-all ${
                                isPublished
                                    ? 'border-green-300 bg-green-50/50'
                                    : !hasVariants
                                        ? 'border-amber-300'
                                        : 'border-gray-100'
                            }`}
                        >
                            {/* Collapsed Header */}
                            <div
                                className="flex items-center gap-4 p-4 cursor-pointer hover:bg-gray-50/50 transition-colors"
                                onClick={() => setExpandedIndex(isExpanded ? -1 : index)}
                            >
                                {/* Thumbnail (la première image disponible) */}
                                {prod.imagePreviews && prod.imagePreviews.length > 0 && (
                                    <img
                                        src={prod.imagePreviews[0]}
                                        alt={prod.name}
                                        className="w-14 h-14 rounded-lg object-cover border border-gray-200 flex-shrink-0"
                                    />
                                )}

                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-2">
                                        <h3 className="font-semibold text-gray-900 truncate">{prod.name || 'Sans nom'}</h3>
                                        {isPublished && (
                                            <span className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-medium flex-shrink-0">
                                                ✅ Publié
                                            </span>
                                        )}
                                        {!hasVariants && !isPublished && (
                                            <span className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full font-medium flex-shrink-0">
                                                ⚠️ Variantes requises
                                            </span>
                                        )}
                                    </div>
                                    <div className="flex items-center gap-3 text-sm text-gray-500 mt-0.5">
                                        <span className="font-semibold text-purple-600">${prod.price}</span>
                                        <span>{catObj?.emoji} {catObj?.label || prod.category}</span>
                                        <span>{prod.weight_kg}kg</span>
                                        {prod.brand && <span className="text-amber-600">⭐ {prod.brand}</span>}
                                    </div>
                                </div>

                                <div className="flex items-center gap-2">
                                    {!isPublished && (
                                        <button
                                            onClick={(e) => { e.stopPropagation(); publishProduct(index); }}
                                            disabled={isPublishing}
                                            className="px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 disabled:opacity-50 flex items-center gap-1.5"
                                        >
                                            {isPublishing ? <Loader2 className="animate-spin" size={14} /> : <Save size={14} />}
                                            Publier
                                        </button>
                                    )}
                                    {isExpanded ? <ChevronUp size={20} className="text-gray-400" /> : <ChevronDown size={20} className="text-gray-400" />}
                                </div>
                            </div>

                            {/* Errors */}
                            {prodErrors && (
                                <div className="mx-4 mb-3 p-3 bg-red-50 border border-red-200 rounded-lg">
                                    {prodErrors.map((err, ei) => (
                                        <p key={ei} className="text-sm text-red-600 flex items-center gap-1.5">
                                            <AlertTriangle size={13} /> {err}
                                        </p>
                                    ))}
                                </div>
                            )}

                            {/* Expanded Content */}
                            {isExpanded && !isPublished && (
                                <div className="border-t border-gray-100 p-5 space-y-5">
                                    
                                    {/* ═══ Grille Photos du Produit (5+ Slots) ═══ */}
                                    <div className="bg-white rounded-xl">
                                        <div className="flex items-center justify-between mb-3">
                                            <h3 className="font-bold text-gray-900 text-sm flex items-center gap-2">
                                                <ImageIcon size={16} className="text-blue-500" />
                                                Photos du produit <span className="text-red-500">*</span>
                                            </h3>
                                            <div className="flex items-center gap-3">
                                                <span className="text-xs text-gray-400">{(prod.images || []).length}/8</span>
                                                <button
                                                    type="button"
                                                    onClick={() => handleMultipleImages(index)}
                                                    className="text-xs bg-blue-50 text-blue-600 px-3 py-1.5 rounded-full hover:bg-blue-100 flex items-center gap-1.5 font-medium transition-colors"
                                                >
                                                    <Plus size={12} /> Charger photos
                                                </button>
                                            </div>
                                        </div>

                                        <div className="flex flex-wrap gap-2">
                                            {PHOTO_SLOTS.map((slot, si) => {
                                                const hasImage = si < (prod.images || []).length;
                                                return (
                                                    <div
                                                        key={si}
                                                        onClick={() => handleImageSlot(index, si)}
                                                        className={`relative w-20 h-20 sm:w-24 sm:h-24 rounded-xl border-2 ${hasImage
                                                            ? 'border-green-300 bg-green-50'
                                                            : 'border-dashed border-blue-200 bg-blue-50/30 hover:bg-blue-50'
                                                        } flex items-center justify-center cursor-pointer transition-all group overflow-hidden`}
                                                    >
                                                        {hasImage ? (
                                                            <>
                                                                <img src={prod.imagePreviews[si]} alt={slot.label} className="w-full h-full object-cover" />
                                                                <button
                                                                    type="button"
                                                                    onClick={(e) => { e.stopPropagation(); removeImage(index, si); }}
                                                                    className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity shadow"
                                                                >
                                                                    <X size={12} />
                                                                </button>
                                                                <div className="absolute bottom-0 left-0 right-0 bg-black/50 text-white text-[9px] text-center py-0.5 truncate px-1">
                                                                    {slot.label}
                                                                </div>
                                                            </>
                                                        ) : (
                                                            <div className="text-center">
                                                                <span className="text-lg">{slot.icon}</span>
                                                                <p className="text-[9px] text-gray-400 mt-1">{slot.label}</p>
                                                            </div>
                                                        )}
                                                    </div>
                                                );
                                            })}

                                            {/* Extra images beyond 5 */}
                                            {(prod.images || []).length > 5 && (prod.images || []).slice(5).map((_, extraI) => (
                                                <div key={extraI + 5} className="relative w-20 h-20 sm:w-24 sm:h-24 rounded-xl border-2 border-green-300 bg-green-50 flex items-center justify-center cursor-pointer transition-all group overflow-hidden">
                                                    <img src={prod.imagePreviews[extraI + 5]} className="w-full h-full object-cover" />
                                                    <button
                                                        type="button"
                                                        onClick={(e) => { e.stopPropagation(); removeImage(index, extraI + 5); }}
                                                        className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity shadow"
                                                    >
                                                        <X size={12} />
                                                    </button>
                                                </div>
                                            ))}
                                        </div>
                                    </div>

                                    {/* ═══ Infos de base ═══ */}
                                    <div className="grid grid-cols-2 gap-4 border-t border-gray-100 pt-5 mt-5">
                                        <div className="col-span-2">
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Nom du produit</label>
                                            <input
                                                type="text"
                                                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-purple-400 outline-none"
                                                value={prod.name}
                                                onChange={e => updateProduct(index, 'name', e.target.value)}
                                            />
                                        </div>
                                        <div>
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Prix ($)</label>
                                            <input
                                                type="number"
                                                step="0.01"
                                                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-purple-400 outline-none"
                                                value={prod.price}
                                                onChange={e => updateProduct(index, 'price', parseFloat(e.target.value) || 0)}
                                            />
                                        </div>
                                        <div>
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Catégorie</label>
                                            <select
                                                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white focus:ring-2 focus:ring-purple-400 outline-none"
                                                value={prod.category}
                                                onChange={e => updateProduct(index, 'category', e.target.value)}
                                            >
                                                {CATEGORIES.map(c => (
                                                    <option key={c.key} value={c.key}>{c.emoji} {c.label}</option>
                                                ))}
                                            </select>
                                        </div>
                                        <div className="col-span-2">
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Description</label>
                                            <textarea
                                                rows={3}
                                                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-purple-400 outline-none resize-y"
                                                value={prod.description || ''}
                                                onChange={e => updateProduct(index, 'description', e.target.value)}
                                            />
                                        </div>
                                        {prod.specifications && (
                                            <div className="col-span-2">
                                                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Spécifications techniques</label>
                                                <textarea
                                                    rows={3}
                                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono bg-gray-50 focus:ring-2 focus:ring-purple-400 outline-none resize-y"
                                                    value={prod.specifications}
                                                    onChange={e => updateProduct(index, 'specifications', e.target.value)}
                                                />
                                            </div>
                                        )}
                                    </div>

                                    {/* ═══ VARIANTES OBLIGATOIRES ═══ */}
                                    <div className={`rounded-xl p-4 border-2 ${
                                        hasVariants
                                            ? 'border-green-200 bg-green-50/30'
                                            : 'border-amber-300 bg-amber-50'
                                    }`}>
                                        <div className="flex items-center gap-2 mb-3">
                                            <Layers size={18} className={hasVariants ? 'text-green-600' : 'text-amber-600'} />
                                            <h3 className="font-bold text-gray-900 text-sm">
                                                Variantes du produit
                                                <span className="text-red-500 ml-1">*</span>
                                            </h3>
                                            {!hasVariants && (
                                                <span className="text-xs bg-amber-200 text-amber-800 px-2 py-0.5 rounded-full font-medium ml-auto">
                                                    Obligatoire — ajoutez au moins une variante
                                                </span>
                                            )}
                                            {hasVariants && (
                                                <span className="text-xs bg-green-200 text-green-800 px-2 py-0.5 rounded-full font-medium ml-auto">
                                                    ✓ {prod.selectedColors.length} couleur(s), {prod.selectedSizes.length} taille(s)
                                                </span>
                                            )}
                                        </div>

                                        {/* Variantes images (de l'IA) */}
                                        {prod.variant_images && prod.variant_images.length > 0 && (
                                            <div className="mb-4">
                                                <label className="text-xs font-semibold text-gray-600 mb-2 block flex items-center gap-1.5">
                                                    <ImageIcon size={13} /> Variantes détectées par l'IA — Cliquez pour sélectionner
                                                </label>
                                                <div className="flex flex-wrap gap-2">
                                                    {prod.variant_images.map((vi, viIdx) => {
                                                        const isSelected = prod.selectedVariantImages.includes(viIdx);
                                                        return (
                                                            <button
                                                                key={viIdx}
                                                                type="button"
                                                                onClick={() => toggleVariantImage(index, viIdx)}
                                                                className={`relative flex items-center gap-2 px-3 py-2 rounded-lg border-2 text-sm transition-all ${
                                                                    isSelected
                                                                        ? 'border-purple-400 bg-purple-50 shadow-sm'
                                                                        : 'border-gray-200 bg-white hover:border-gray-300'
                                                                }`}
                                                            >
                                                                {/* Colored dot if color variant */}
                                                                {vi.variant_type === 'color' && (
                                                                    <span
                                                                        className="w-4 h-4 rounded-full border border-gray-300 flex-shrink-0"
                                                                        style={{
                                                                            backgroundColor: PRESET_COLORS.find(c =>
                                                                                c.name.toLowerCase() === (vi.label || '').toLowerCase()
                                                                            )?.hex || '#ccc'
                                                                        }}
                                                                    />
                                                                )}
                                                                <span className="font-medium text-gray-700">{vi.label}</span>
                                                                {vi.description && (
                                                                    <span className="text-xs text-gray-400">({vi.description})</span>
                                                                )}
                                                                {isSelected && (
                                                                    <CheckCircle size={14} className="text-purple-500 flex-shrink-0" />
                                                                )}
                                                            </button>
                                                        );
                                                    })}
                                                </div>
                                            </div>
                                        )}

                                        {/* Couleurs */}
                                        <div className="mb-3">
                                            <label className="text-xs font-semibold text-gray-600 mb-1.5 block">🎨 Couleurs</label>
                                            <div className="flex flex-wrap gap-1.5 mb-2">
                                                {PRESET_COLORS.map(c => {
                                                    const sel = prod.selectedColors.includes(c.name);
                                                    return (
                                                        <button
                                                            key={c.name}
                                                            type="button"
                                                            onClick={() => toggleColor(index, c.name)}
                                                            className={`flex items-center gap-1 px-2.5 py-1 rounded-full border text-xs font-medium transition-all ${
                                                                sel
                                                                    ? 'border-purple-400 bg-purple-50 text-purple-800'
                                                                    : 'border-gray-200 text-gray-600 hover:border-gray-300'
                                                            }`}
                                                        >
                                                            <span
                                                                className="w-3 h-3 rounded-full border border-gray-300 flex-shrink-0"
                                                                style={{ backgroundColor: c.hex }}
                                                            />
                                                            {c.name}
                                                            {sel && <CheckCircle size={10} className="text-purple-500" />}
                                                        </button>
                                                    );
                                                })}
                                            </div>
                                            {/* Custom colors */}
                                            {prod.selectedColors.filter(c => !PRESET_COLORS.find(p => p.name === c)).map(c => (
                                                <span key={c} className="inline-flex items-center gap-1 mr-1.5 mb-1.5 px-2.5 py-1 rounded-full border border-purple-400 bg-purple-50 text-purple-800 text-xs font-medium">
                                                    {c}
                                                    <button onClick={() => toggleColor(index, c)} className="text-purple-400 hover:text-red-500 ml-0.5">×</button>
                                                </span>
                                            ))}
                                            <div className="flex gap-2 mt-1.5">
                                                <input
                                                    type="text"
                                                    placeholder="Autre couleur..."
                                                    value={prod.customColorInput || ''}
                                                    onChange={e => updateProduct(index, 'customColorInput', e.target.value)}
                                                    onKeyDown={e => e.key === 'Enter' && addCustomColor(index)}
                                                    className="flex-1 border border-gray-200 rounded-lg px-3 py-1.5 text-xs focus:ring-2 focus:ring-purple-400 outline-none"
                                                />
                                                <button
                                                    type="button"
                                                    onClick={() => addCustomColor(index)}
                                                    className="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-xs font-medium"
                                                >
                                                    + Ajouter
                                                </button>
                                            </div>
                                        </div>

                                        {/* Tailles */}
                                        <div>
                                            <label className="text-xs font-semibold text-gray-600 mb-1.5 block">📐 Tailles</label>
                                            <div className="flex flex-wrap gap-1.5 mb-2">
                                                {presetSizes.map(s => {
                                                    const sel = prod.selectedSizes.includes(s);
                                                    return (
                                                        <button
                                                            key={s}
                                                            type="button"
                                                            onClick={() => toggleSize(index, s)}
                                                            className={`px-2.5 py-1 rounded-full border text-xs font-medium transition-all ${
                                                                sel
                                                                    ? 'border-purple-400 bg-purple-50 text-purple-800'
                                                                    : 'border-gray-200 text-gray-600 hover:border-gray-300'
                                                            }`}
                                                        >
                                                            {s}
                                                        </button>
                                                    );
                                                })}
                                            </div>
                                            {/* Custom sizes */}
                                            {prod.selectedSizes.filter(s => !presetSizes.includes(s)).map(s => (
                                                <span key={s} className="inline-flex items-center gap-1 mr-1.5 mb-1.5 px-2.5 py-1 rounded-full border border-purple-400 bg-purple-50 text-purple-800 text-xs font-medium">
                                                    {s}
                                                    <button onClick={() => toggleSize(index, s)} className="text-purple-400 hover:text-red-500 ml-0.5">×</button>
                                                </span>
                                            ))}
                                            <div className="flex gap-2 mt-1.5">
                                                <input
                                                    type="text"
                                                    placeholder="Autre taille..."
                                                    value={prod.customSizeInput || ''}
                                                    onChange={e => updateProduct(index, 'customSizeInput', e.target.value)}
                                                    onKeyDown={e => e.key === 'Enter' && addCustomSize(index)}
                                                    className="flex-1 border border-gray-200 rounded-lg px-3 py-1.5 text-xs focus:ring-2 focus:ring-purple-400 outline-none"
                                                />
                                                <button
                                                    type="button"
                                                    onClick={() => addCustomSize(index)}
                                                    className="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-xs font-medium"
                                                >
                                                    + Ajouter
                                                </button>
                                            </div>
                                        </div>
                                    </div>

                                    {/* ═══ LIVRAISON ═══ */}
                                    <div className="bg-gray-50 rounded-xl p-4 border border-gray-100">
                                        <div className="flex items-center justify-between mb-3">
                                            <h3 className="font-bold text-gray-900 text-sm flex items-center gap-2">
                                                <Truck size={16} className="text-blue-500" /> Options de livraison
                                            </h3>
                                            <button
                                                type="button"
                                                onClick={() => addShippingOption(index)}
                                                className="text-xs bg-blue-50 text-blue-600 px-2.5 py-1 rounded-full hover:bg-blue-100 flex items-center gap-1 font-medium"
                                            >
                                                <Plus size={12} /> Ajouter
                                            </button>
                                        </div>

                                        <div className="space-y-2">
                                            {prod.shippingOptions.map((opt, si) => {
                                                const method = AVAILABLE_METHODS.find(m => m.id === opt.methodId);
                                                const isCostDisabled = opt.methodId === 'free' || opt.methodId === 'hand_delivery';
                                                const isPartnerMode = opt.methodId === 'partner';

                                                return (
                                                    <div key={si} className="flex items-center gap-2 bg-white p-2.5 rounded-lg border border-gray-100">
                                                        <div className="flex-1">
                                                            <select
                                                                className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white"
                                                                value={opt.methodId}
                                                                onChange={e => updateShippingOption(index, si, 'methodId', e.target.value)}
                                                            >
                                                                <option value="">Choisir...</option>
                                                                {AVAILABLE_METHODS.map(m => (
                                                                    <option key={m.id} value={m.id}>{m.icon} {m.label}</option>
                                                                ))}
                                                            </select>
                                                        </div>
                                                        <div className="w-24">
                                                            <input
                                                                type="text"
                                                                className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs"
                                                                placeholder="Délai"
                                                                value={opt.time || ''}
                                                                onChange={e => updateShippingOption(index, si, 'time', e.target.value)}
                                                            />
                                                        </div>
                                                        <div className="w-20">
                                                            {isPartnerMode ? (
                                                                <span className="text-xs text-amber-600 bg-amber-50 px-2 py-1.5 rounded-lg border border-amber-200 block text-center font-medium">Auto/km</span>
                                                            ) : (
                                                                <input
                                                                    type="number"
                                                                    min="0"
                                                                    step="0.01"
                                                                    className={`w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs ${isCostDisabled ? 'bg-gray-100 text-gray-400' : ''}`}
                                                                    placeholder="0.00"
                                                                    value={opt.cost ?? ''}
                                                                    onChange={e => updateShippingOption(index, si, 'cost', e.target.value)}
                                                                    disabled={isCostDisabled}
                                                                />
                                                            )}
                                                        </div>
                                                        {prod.shippingOptions.length > 1 && (
                                                            <button
                                                                type="button"
                                                                onClick={() => removeShippingOption(index, si)}
                                                                className="text-red-400 hover:text-red-600 p-1"
                                                            >
                                                                <Trash size={14} />
                                                            </button>
                                                        )}
                                                    </div>
                                                );
                                            })}
                                        </div>

                                        {/* Résumé fret calculé */}
                                        {prod.shippingOptions.length > 0 && (
                                            <div className="mt-2 text-xs text-gray-500 bg-blue-50/50 rounded-lg p-2">
                                                💡 Fret calculé : Aérien = <strong>${prod.shippingOptions.find(o => o.methodId === 'oli_standard')?.cost || '—'}</strong>
                                                {prod.shippingOptions.find(o => o.methodId === 'maritime') && (
                                                    <> | Maritime = <strong>${prod.shippingOptions.find(o => o.methodId === 'maritime')?.cost || '—'}</strong></>
                                                )}
                                                {' '}(poids: {prod.weight_kg}kg)
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}
                        </div>
                    );
                })}
            </div>

            {/* Info footer */}
            <div className="mt-6 p-4 bg-purple-50 border border-purple-100 rounded-xl text-sm text-purple-800">
                <p className="font-semibold mb-1">💡 Conseils</p>
                <ul className="space-y-0.5 text-purple-700 text-xs">
                    <li>• Cliquez sur un produit pour développer et modifier ses détails</li>
                    <li>• <strong>Les variantes sont obligatoires</strong> — ajoutez au moins une couleur ou une taille pour pouvoir publier</li>
                    <li>• Le fret est calculé automatiquement : Aérien $24/kg, Maritime $700/m³</li>
                    <li>• Vous pouvez publier les produits un par un ou tous en même temps</li>
                </ul>
            </div>
        </div>
    );
}
