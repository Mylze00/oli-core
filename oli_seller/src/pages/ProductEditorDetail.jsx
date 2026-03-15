import { useState, useEffect } from 'react';
import { ArrowLeft, Plus, Trash, Save, Loader2, X, HelpCircle, ShieldCheck, Camera, Tag, Palette, MapPin, Package, ChevronDown } from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';
import api from '../services/api';

// ══════════════════════════════════════════════════════════
//  CONSTANTES (identiques à l'app mobile)
// ══════════════════════════════════════════════════════════

const PHOTO_SLOTS = [
    { label: 'Face', icon: '📸' },
    { label: 'Dos / Côté', icon: '🔄' },
    { label: 'Étiquette', icon: '🏷️' },
    { label: 'Détail / Défaut', icon: '🔍' },
    { label: 'Autre', icon: '📷' },
];

const CONDITIONS = ['Neuf', 'Occasion', 'Fonctionnel', 'Pour pièce ou à réparer'];

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

const AVAILABLE_METHODS = [
    { id: 'oli_express', label: 'Oli Express', time: '1-2h', description: 'Livraison rapide gérée par Oli', icon: '⚡' },
    { id: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', description: 'Livraison standard gérée par Oli', icon: '📦' },
    { id: 'partner', label: 'Livreur Partenaire', time: 'Variable', description: 'Prix calculé automatiquement selon la distance', icon: '🏍️' },
    { id: 'hand_delivery', label: 'Remise en Main Propre', time: 'À convenir', description: 'Le vendeur et l\'acheteur s\'arrangent', icon: '🤝' },
    { id: 'pick_go', label: 'Pick & Go', time: 'Retrait immédiat', description: 'L\'acheteur récupère au guérite du magasin', icon: '🏪' },
    { id: 'free', label: 'Livraison Gratuite', time: '3-7 jours', description: 'Offerte par le vendeur', icon: '🎁' },
    { id: 'moto', label: 'Livraison Moto', time: 'Calculé/distance', description: 'Prix calculé selon la distance parcourue', icon: '🏍️', isDistanceBased: true },
    { id: 'maritime', label: 'Livraison Maritime', time: '60 jours', description: 'Transport par voie maritime pour grandes distances', icon: '🚢' },
];

// ── Variantes ─────────────────────────────────────────────────────────────────
const COLORS = [
    { name: 'Rouge', hex: '#ef4444' }, { name: 'Bleu', hex: '#3b82f6' },
    { name: 'Vert', hex: '#22c55e' }, { name: 'Jaune', hex: '#eab308' },
    { name: 'Orange', hex: '#f97316' }, { name: 'Violet', hex: '#a855f7' },
    { name: 'Rose', hex: '#ec4899' }, { name: 'Noir', hex: '#1f2937' },
    { name: 'Blanc', hex: '#f3f4f6' }, { name: 'Gris', hex: '#9ca3af' },
    { name: 'Marron', hex: '#92400e' }, { name: 'Beige', hex: '#d4a47a' },
    { name: 'Gold', hex: '#f59e0b' }, { name: 'Argent', hex: '#cbd5e1' },
];
const SIZES = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL',
    '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46',
];
const MATERIALS = ['Coton', 'Polyester', 'Cuir', 'Soie', 'Lin', 'Laine', 'Nylon', 'Velours', 'Denim', 'Plastique', 'Métal', 'Bois', 'Céramique', 'Caoutchouc'];

const RETURN_POLICIES = [
    'Garantie Oli (7 jours)',
    'Retour accepté (14 jours)',
    'Retour accepté (30 jours)',
    'Aucun retour',
];

// ══════════════════════════════════════════════════════════
//  COMPOSANT
// ══════════════════════════════════════════════════════════

export default function ProductEditorDetail() {
    const navigate = useNavigate();
    const routerLocation = useLocation();
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(null);
    const [showCategoryOverlay, setShowCategoryOverlay] = useState(false);

    // --- Champs ---
    const [name, setName] = useState('');
    const [price, setPrice] = useState('');
    const [description, setDescription] = useState('');
    const [category, setCategory] = useState('electronics');
    const [condition, setCondition] = useState('Neuf');
    const [quantity, setQuantity] = useState('');
    const [color, setColor] = useState('');
    const [location, setLocation] = useState('');
    const [images, setImages] = useState([]);
    const [imagePreviews, setImagePreviews] = useState([]);
    const [returnPolicy, setReturnPolicy] = useState('Garantie Oli (7 jours)');
    const [certifyAuthenticity, setCertifyAuthenticity] = useState(false);

    // Badge Original (Brand Certified)
    const [brandCertified, setBrandCertified] = useState(false);
    const [brandDisplayName, setBrandDisplayName] = useState('');

    // Variantes
    const [selectedColors, setSelectedColors] = useState([]);
    const [selectedSizes, setSelectedSizes] = useState([]);
    const [selectedMaterials, setSelectedMaterials] = useState([]);

    const toggleVariant = (list, setList, value) => {
        setList(prev => prev.includes(value) ? prev.filter(v => v !== value) : [...prev, value]);
    };

    // Shipping options
    const [shippingOptions, setShippingOptions] = useState([
        { methodId: 'oli_standard', cost: '', time: '2-5 jours' }
    ]);

    // ── Pre-fill with AI Import Data ──
    useEffect(() => {
        if (routerLocation.state?.aiProductData) {
            const data = routerLocation.state.aiProductData;
            if (data.name) setName(data.name);
            if (data.price !== undefined && data.price !== null) setPrice(data.price.toString());
            if (data.description) setDescription(data.description);
            if (data.condition) setCondition(data.condition === 'used' ? 'Occasion' : 'Neuf');
            
            // Variants & Brand
            if (data.colors && Array.isArray(data.colors)) {
                // Tente de matcher avec les couleurs définies
                const matchedColors = data.colors.filter(c => COLORS.some(definedColor => definedColor.name.toLowerCase() === c.toLowerCase()));
                if (matchedColors.length > 0) setSelectedColors(matchedColors);
                setColor(data.colors.join(', '));
            }
            if (data.sizes && Array.isArray(data.sizes)) {
                setSelectedSizes(Array.from(new Set(data.sizes.map(s => String(s).toUpperCase()))));
            }
            if (data.brand) {
                setBrandCertified(true);
                setBrandDisplayName(data.brand);
            }

            // Shipping prefill based on freight calculation
            if (data.shippingOptions && data.shippingOptions.length > 0) {
                setShippingOptions(data.shippingOptions);
            } else if (data.freightMethodId && data.freightCostUsd !== undefined) {
                setShippingOptions([
                    {
                        methodId: data.freightMethodId,
                        cost: data.freightCostUsd,
                        time: data.deliveryTime || '2-5 jours'
                    }
                ]);
            }

            // Check if any category roughly matches
            if (data.category) {
                const match = CATEGORIES.find(c => 
                    c.label.toLowerCase().includes(data.category.toLowerCase()) || 
                    data.category.toLowerCase().includes(c.label.toLowerCase()) ||
                    data.category.toLowerCase().includes(c.key.toLowerCase())
                );
                if (match) setCategory(match.key);
            }
        }
    }, [routerLocation.state?.aiProductData]);

    // Helper to run base64 to File
    const base64ToFile = (base64String, mimeType) => {
        try {
            const byteCharacters = atob(base64String.split(',')[1]);
            const byteArrays = [];
            for (let offset = 0; offset < byteCharacters.length; offset += 512) {
                const slice = byteCharacters.slice(offset, offset + 512);
                const byteNumbers = new Array(slice.length);
                for (let i = 0; i < slice.length; i++) {
                    byteNumbers[i] = slice.charCodeAt(i);
                }
                const byteArray = new Uint8Array(byteNumbers);
                byteArrays.push(byteArray);
            }
            const blob = new Blob(byteArrays, { type: mimeType });
            return new File([blob], "ai-screenshot.jpg", { type: mimeType });
        } catch (e) {
            console.error(e);
            return null;
        }
    };

    // Prefill the image file
    useEffect(() => {
        if (routerLocation.state?.aiImageBase64) {
            const restoredFile = base64ToFile(routerLocation.state.aiImageBase64, routerLocation.state.aiImageMimeType || 'image/jpeg');
            if (restoredFile) {
                setImages([restoredFile]);
                setImagePreviews([routerLocation.state.aiImageBase64]);
            }
        }
    }, [routerLocation.state?.aiImageBase64]);

    // ── Help dialogs ──
    const [showConditionHelp, setShowConditionHelp] = useState(false);
    const [showDeliveryHelp, setShowDeliveryHelp] = useState(false);

    // ══════════════════════════════════════════════════════════
    //  QUALITY SCORE (identique au mobile)
    // ══════════════════════════════════════════════════════════
    const qualityScore = (() => {
        let score = 0;
        if (name.trim()) score += 15;
        if (price.trim()) score += 15;
        if (images.length > 0) score += images.length >= 3 ? 25 : 15;
        if (description.trim()) score += 15;
        if (category) score += 10;
        if (location.trim()) score += 10;
        if (quantity.trim()) score += 10;
        return Math.min(score, 100);
    })();

    const qualityLabel = qualityScore >= 90
        ? 'Excellente annonce ! 🌟'
        : qualityScore >= 70
            ? 'Bonne annonce 👍'
            : qualityScore >= 40
                ? 'Ajoutez plus de détails'
                : 'Complétez votre annonce';

    const qualityColor = qualityScore >= 80
        ? '#4ade80'
        : qualityScore >= 50
            ? '#fb923c'
            : '#f87171';

    // ══════════════════════════════════════════════════════════
    //  IMAGE HANDLING
    // ══════════════════════════════════════════════════════════
    const handleImageSlot = (slotIndex) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.onchange = (e) => {
            const file = e.target.files[0];
            if (!file) return;

            const newImages = [...images];
            const newPreviews = [...imagePreviews];

            if (slotIndex < images.length) {
                // Replace existing
                URL.revokeObjectURL(newPreviews[slotIndex]);
                newImages[slotIndex] = file;
                newPreviews[slotIndex] = URL.createObjectURL(file);
            } else {
                // Add new
                newImages.push(file);
                newPreviews.push(URL.createObjectURL(file));
            }

            setImages(newImages);
            setImagePreviews(newPreviews);
        };
        input.click();
    };

    const handleMultipleImages = () => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.multiple = true;
        input.onchange = (e) => {
            const files = Array.from(e.target.files);
            const remaining = 8 - images.length;
            const toAdd = files.slice(0, remaining);

            setImages([...images, ...toAdd]);
            setImagePreviews([...imagePreviews, ...toAdd.map(f => URL.createObjectURL(f))]);
        };
        input.click();
    };

    const removeImage = (index) => {
        URL.revokeObjectURL(imagePreviews[index]);
        setImages(images.filter((_, i) => i !== index));
        setImagePreviews(imagePreviews.filter((_, i) => i !== index));
    };

    // Cleanup previews on unmount
    useEffect(() => {
        return () => imagePreviews.forEach(url => URL.revokeObjectURL(url));
    }, []);

    // ══════════════════════════════════════════════════════════
    //  SHIPPING OPTIONS
    // ══════════════════════════════════════════════════════════
    const addShippingOption = () => {
        setShippingOptions([...shippingOptions, { methodId: '', cost: '', time: '' }]);
    };

    const updateShippingOption = (index, field, value) => {
        const newOpts = [...shippingOptions];
        if (field === 'methodId') {
            const method = AVAILABLE_METHODS.find(m => m.id === value);
            if (method) newOpts[index].time = method.time;
            if (value === 'free' || value === 'hand_delivery') newOpts[index].cost = 0;
            else if (value === 'partner') newOpts[index].cost = '';
        }
        newOpts[index][field] = value;
        setShippingOptions(newOpts);
    };

    const removeShippingOption = (index) => {
        setShippingOptions(shippingOptions.filter((_, i) => i !== index));
    };

    // ══════════════════════════════════════════════════════════
    //  SUBMIT
    // ══════════════════════════════════════════════════════════
    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);

        // Validations (comme le mobile)
        if (images.length === 0) {
            setError('Ajoutez au moins une photo.');
            return;
        }
        if (shippingOptions.length === 0 || !shippingOptions[0].methodId) {
            setError('Sélectionnez au moins un mode de livraison.');
            return;
        }
        if (!certifyAuthenticity) {
            setError('Vous devez certifier l\'authenticité de votre article.');
            return;
        }

        setSaving(true);

        try {
            const formData = new FormData();

            // Champs identiques au mobile
            formData.append('name', name.trim());
            formData.append('price', price.trim());
            formData.append('description', description.trim());
            formData.append('condition', condition);
            formData.append('quantity', quantity || '1');
            formData.append('color', color.trim());
            formData.append('category', category || 'other');
            formData.append('location', location.trim() || 'Non spécifiée');
            formData.append('is_negotiable', 'false');

            // Shipping options
            const defaultOption = shippingOptions[0];
            formData.append('delivery_price', defaultOption.cost || 0);
            formData.append('delivery_time', defaultOption.time || '');
            formData.append('shipping_options', JSON.stringify(shippingOptions));

            // Badge Original
            formData.append('brand_certified', brandCertified ? 'true' : 'false');
            if (brandCertified && brandDisplayName.trim()) {
                formData.append('brand_display_name', brandDisplayName.trim());
            }

            // Variantes
            const variants = [
                ...selectedColors.map(v => ({ variant_type: 'color', variant_value: v })),
                ...selectedSizes.map(v => ({ variant_type: 'size', variant_value: v })),
                ...selectedMaterials.map(v => ({ variant_type: 'material', variant_value: v })),
            ];
            if (variants.length > 0) {
                formData.append('variants', JSON.stringify(variants));
            }

            // Images
            images.forEach(image => {
                formData.append('images', image);
            });

            await api.post('/products/upload', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });

            navigate('/products');
        } catch (err) {
            console.error('Erreur publication:', err);
            setError(err.response?.data?.detail || err.response?.data?.error || 'Erreur lors de la publication. Réessayez.');
            setSaving(false);
        }
    };

    // ══════════════════════════════════════════════════════════
    //  RENDER
    // ══════════════════════════════════════════════════════════

    const selectedCategory = CATEGORIES.find(c => c.key === category);

    return (
        <div className="p-8 max-w-3xl mx-auto" translate="no">
            {/* Back */}
            <button onClick={() => navigate('/products/new')} className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900 transition-colors">
                <ArrowLeft size={16} /> Retour au choix du mode
            </button>

            <h1 className="text-2xl font-bold text-gray-900 mb-2">📱 Publication Détail</h1>
            <p className="text-gray-500 mb-6">Formulaire identique à l'app mobile — remplissez chaque section pour une annonce de qualité.</p>

            {/* Error Banner */}
            {error && (
                <div className="mb-6 bg-red-50 border border-red-200 text-red-700 rounded-lg p-4 flex items-start gap-3">
                    <span className="text-red-400 mt-0.5">⚠️</span>
                    <div className="flex-1">
                        <p className="font-medium">Erreur</p>
                        <p className="text-sm">{error}</p>
                    </div>
                    <button onClick={() => setError(null)} className="text-red-400 hover:text-red-600"><X size={16} /></button>
                </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">

                {/* ═══ BARRE DE PROGRESSION ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex justify-between items-center mb-2">
                        <span className="text-sm text-gray-500">Qualité de votre annonce</span>
                        <span className="text-sm font-bold" style={{ color: qualityColor }}>{qualityScore}%</span>
                    </div>
                    <div className="w-full bg-gray-100 rounded-full h-2.5 overflow-hidden">
                        <div
                            className="h-2.5 rounded-full transition-all duration-500"
                            style={{ width: `${qualityScore}%`, background: qualityColor }}
                        />
                    </div>
                    <p className="text-xs mt-2" style={{ color: qualityColor }}>{qualityLabel}</p>
                </div>

                {/* ═══ GRILLE PHOTOS (5 SLOTS) ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex items-center justify-between mb-4">
                        <h2 className="font-bold text-gray-900 flex items-center gap-2">
                            <Camera size={18} className="text-blue-500" /> Photos du produit
                        </h2>
                        <div className="flex items-center gap-3">
                            <span className="text-xs text-gray-400">{images.length}/8</span>
                            <button
                                type="button"
                                onClick={handleMultipleImages}
                                className="text-xs bg-blue-50 text-blue-600 px-3 py-1.5 rounded-full hover:bg-blue-100 flex items-center gap-1.5 font-medium transition-colors"
                            >
                                <Plus size={12} /> Charger toutes les photos
                            </button>
                        </div>
                    </div>

                    <div className="flex flex-wrap gap-3">
                        {PHOTO_SLOTS.map((slot, i) => {
                            const hasImage = i < images.length;
                            return (
                                <div
                                    key={i}
                                    onClick={() => handleImageSlot(i)}
                                    className={`relative w-[100px] h-[100px] rounded-xl border-2 ${hasImage
                                        ? 'border-green-300 bg-green-50'
                                        : 'border-dashed border-blue-200 bg-blue-50/30 hover:bg-blue-50'
                                        } flex items-center justify-center cursor-pointer transition-all group overflow-hidden`}
                                >
                                    {hasImage ? (
                                        <>
                                            <img src={imagePreviews[i]} alt={slot.label} className="w-full h-full object-cover rounded-lg" />
                                            <button
                                                type="button"
                                                onClick={(e) => { e.stopPropagation(); removeImage(i); }}
                                                className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity shadow"
                                            >
                                                <X size={12} />
                                            </button>
                                            <div className="absolute bottom-0 left-0 right-0 bg-black/50 text-white text-[9px] text-center py-0.5">
                                                {slot.label}
                                            </div>
                                        </>
                                    ) : (
                                        <div className="text-center">
                                            <span className="text-xl">{slot.icon}</span>
                                            <p className="text-[9px] text-gray-400 mt-1">{slot.label}</p>
                                        </div>
                                    )}
                                </div>
                            );
                        })}

                        {/* Bouton + Pour plus de photos */}
                        {images.length >= 5 && images.length < 8 && (
                            <div
                                onClick={handleMultipleImages}
                                className="w-[100px] h-[100px] rounded-xl border-2 border-dashed border-blue-200 bg-blue-50/30 hover:bg-blue-50 flex flex-col items-center justify-center cursor-pointer transition-all"
                            >
                                <Plus size={20} className="text-blue-400" />
                                <p className="text-[10px] text-blue-400 mt-1">Plus</p>
                            </div>
                        )}
                    </div>

                    {/* Extra images beyond 5 */}
                    {images.length > 5 && (
                        <div className="flex gap-2 mt-3 overflow-x-auto">
                            {images.slice(5).map((_, i) => (
                                <div key={i + 5} className="relative w-16 h-16 rounded-lg overflow-hidden flex-shrink-0 border border-gray-200">
                                    <img src={imagePreviews[i + 5]} alt={`Extra ${i + 1}`} className="w-full h-full object-cover" />
                                    <button
                                        type="button"
                                        onClick={() => removeImage(i + 5)}
                                        className="absolute top-0.5 right-0.5 bg-red-500 text-white rounded-full p-0.5"
                                    >
                                        <X size={10} />
                                    </button>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* ═══ INFOS PRINCIPALES ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-4">
                    <h2 className="font-bold text-gray-900 flex items-center gap-2">
                        <Tag size={18} className="text-blue-500" /> Informations principales
                    </h2>

                    {/* Nom */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Nom du produit *</label>
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="ex: iPhone 14 Pro Max 256GB"
                            value={name}
                            onChange={e => setName(e.target.value)}
                            required
                        />
                    </div>

                    {/* Prix */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Prix de vente ($) *</label>
                        <input
                            type="number"
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="ex: 250"
                            value={price}
                            onChange={e => setPrice(e.target.value)}
                            required
                            min="0"
                            step="0.01"
                        />
                    </div>

                    {/* Catégorie */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Catégorie *</label>
                        <button
                            type="button"
                            onClick={() => setShowCategoryOverlay(true)}
                            className="w-full flex items-center justify-between border border-gray-200 p-3 rounded-lg bg-white hover:bg-gray-50 transition-colors"
                        >
                            <span className="flex items-center gap-2">
                                <span className="text-lg">{selectedCategory?.emoji}</span>
                                <span className="text-gray-700">{selectedCategory?.label || 'Choisir une catégorie...'}</span>
                            </span>
                            <ChevronDown size={16} className="text-gray-400" />
                        </button>
                    </div>

                    {/* État du produit */}
                    <div>
                        <div className="flex items-center gap-2 mb-1">
                            <label className="text-sm font-medium text-gray-700">État du produit *</label>
                            <button type="button" onClick={() => setShowConditionHelp(true)}
                                className="w-5 h-5 rounded-full border border-blue-300 text-blue-400 flex items-center justify-center hover:bg-blue-50 transition-colors">
                                <HelpCircle size={12} />
                            </button>
                        </div>
                        <select
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none bg-white"
                            value={condition}
                            onChange={e => setCondition(e.target.value)}
                        >
                            {CONDITIONS.map(c => <option key={c} value={c}>{c}</option>)}
                        </select>
                    </div>
                </div>

                {/* ═══ OPTIONS DE LIVRAISON ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-2">
                            <h2 className="font-bold text-gray-900 flex items-center gap-2">
                                <Package size={18} className="text-blue-500" /> Options de livraison
                            </h2>
                            <button type="button" onClick={() => setShowDeliveryHelp(true)}
                                className="w-5 h-5 rounded-full border border-blue-300 text-blue-400 flex items-center justify-center hover:bg-blue-50 transition-colors">
                                <HelpCircle size={12} />
                            </button>
                        </div>
                        <button
                            type="button"
                            onClick={addShippingOption}
                            className="text-xs bg-blue-50 text-blue-600 px-3 py-1.5 rounded-full hover:bg-blue-100 flex items-center gap-1 font-medium transition-colors"
                        >
                            <Plus size={12} /> Ajouter
                        </button>
                    </div>

                    <div className="space-y-3">
                        {shippingOptions.map((option, index) => {
                            const method = AVAILABLE_METHODS.find(m => m.id === option.methodId);
                            const isCostDisabled = option.methodId === 'free' || option.methodId === 'hand_delivery' || option.methodId === 'partner' || option.methodId === 'moto';

                            return (
                                <div key={index} className="bg-gray-50 p-4 rounded-lg border border-gray-100 relative">
                                    <div className="flex items-center justify-between mb-2">
                                        <span className="text-xs text-blue-500 font-medium">Option #{index + 1}</span>
                                        {shippingOptions.length > 1 && (
                                            <button type="button" onClick={() => removeShippingOption(index)} className="text-red-400 hover:text-red-600 transition-colors">
                                                <Trash size={14} />
                                            </button>
                                        )}
                                    </div>

                                    <div className="grid grid-cols-3 gap-3">
                                        <div className="col-span-1">
                                            <label className="block text-xs text-gray-500 mb-1">Mode</label>
                                            <select
                                                className="w-full border border-gray-200 p-2 rounded-lg text-sm bg-white"
                                                value={option.methodId}
                                                onChange={e => updateShippingOption(index, 'methodId', e.target.value)}
                                                required
                                            >
                                                <option value="">Choisir...</option>
                                                {AVAILABLE_METHODS.map(m => (
                                                    <option key={m.id} value={m.id}>{m.label}</option>
                                                ))}
                                            </select>
                                        </div>
                                        <div>
                                            <label className="block text-xs text-gray-500 mb-1">Délai</label>
                                            <input
                                                type="text"
                                                className="w-full border border-gray-200 p-2 rounded-lg text-sm"
                                                placeholder="ex: 1-2h"
                                                value={option.time || ''}
                                                onChange={e => updateShippingOption(index, 'time', e.target.value)}
                                            />
                                        </div>
                                        <div>
                                            <label className="block text-xs text-gray-500 mb-1">Coût ($)</label>
                                            <input
                                                type="number"
                                                min="0"
                                                step="0.01"
                                                className={`w-full border border-gray-200 p-2 rounded-lg text-sm ${isCostDisabled ? 'bg-gray-100 text-gray-400' : ''}`}
                                                placeholder={option.methodId === 'partner' ? 'Auto' : '0.00'}
                                                value={option.cost}
                                                onChange={e => updateShippingOption(index, 'cost', e.target.value)}
                                                disabled={isCostDisabled}
                                            />
                                        </div>
                                    </div>

                                    {method && (
                                        <p className="text-[11px] text-gray-400 mt-2 italic">{method.description}</p>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>

                {/* ═══ DESCRIPTION ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
                        📝 Description du produit
                    </h2>
                    <textarea
                        className="w-full border border-gray-200 p-4 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-y leading-relaxed"
                        rows={6}
                        placeholder={"Décrivez votre produit en détail :\n• Caractéristiques principales\n• Matériaux / composition\n• Dimensions ou taille\n• Conseils d'utilisation"}
                        value={description}
                        onChange={e => setDescription(e.target.value)}
                    />
                    <div className="flex items-center justify-between mt-2">
                        <div className="flex items-center gap-1.5">
                            {description.length >= 100 ? (
                                <span className="text-green-500 text-xs">✅ Bonne description !</span>
                            ) : (
                                <span className="text-gray-400 text-xs">Ajoutez au moins 100 caractères</span>
                            )}
                        </div>
                        <span className={`text-xs font-medium ${description.length > 100 ? 'text-green-500' : 'text-gray-400'}`}>
                            {description.length}
                        </span>
                    </div>
                </div>

                {/* ═══ DÉTAILS SUPPLÉMENTAIRES ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-4">
                    <h2 className="font-bold text-gray-900 flex items-center gap-2">
                        📋 Détails supplémentaires
                    </h2>
                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                <span className="flex items-center gap-1.5"><Package size={14} /> Quantité en stock</span>
                            </label>
                            <input
                                type="number"
                                min="1"
                                className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                                placeholder="ex: 1"
                                value={quantity}
                                onChange={e => setQuantity(e.target.value)}
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                <span className="flex items-center gap-1.5"><Palette size={14} /> Couleur(s)</span>
                            </label>
                            <input
                                type="text"
                                className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                                placeholder="ex: Noir, Blanc"
                                value={color}
                                onChange={e => setColor(e.target.value)}
                            />
                        </div>
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                            <span className="flex items-center gap-1.5"><MapPin size={14} /> Localisation</span>
                        </label>
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="ex: Kinshasa, Lubumbashi"
                            value={location}
                            onChange={e => setLocation(e.target.value)}
                        />
                    </div>
                </div>

                {/* ═══ BADGE ORIGINAL ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-amber-100">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="w-9 h-9 bg-amber-50 rounded-full flex items-center justify-center">
                            <span className="text-amber-500 text-lg">⭐</span>
                        </div>
                        <div>
                            <h2 className="font-bold text-gray-900">Badge Original</h2>
                            <p className="text-xs text-gray-400">Réservé aux produits de marque authentique — soumis à vérification admin</p>
                        </div>
                    </div>

                    <label className="flex items-center justify-between cursor-pointer mb-4">
                        <div>
                            <p className="text-sm font-medium text-gray-700">Ce produit est un article de marque authentique</p>
                            <p className="text-xs text-gray-400 mt-0.5">En activant ceci, vous déclarez que ce produit est un original certifié</p>
                        </div>
                        <button
                            type="button"
                            onClick={() => setBrandCertified(v => !v)}
                            className={`w-12 h-6 rounded-full transition-colors flex-shrink-0 ml-4 ${brandCertified ? 'bg-amber-500' : 'bg-gray-200'}`}
                        >
                            <div className={`w-4 h-4 bg-white rounded-full shadow m-1 transition-transform ${brandCertified ? 'translate-x-6' : 'translate-x-0'}`} />
                        </button>
                    </label>

                    {brandCertified && (
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Nom de la marque (affiché sur le badge)</label>
                            <input
                                type="text"
                                className="w-full border border-amber-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-400 outline-none bg-amber-50/30"
                                placeholder="ex: Nike, Samsung, Adidas..."
                                value={brandDisplayName}
                                onChange={e => setBrandDisplayName(e.target.value)}
                            />
                        </div>
                    )}
                </div>

                {/* ═══ VARIANTES ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="font-bold text-gray-900 flex items-center gap-2 mb-4">
                        <span>🎨</span> Variantes du produit
                        <span className="text-xs font-normal text-gray-400 ml-1">(facultatif)</span>
                    </h2>

                    {/* Couleurs */}
                    <div className="mb-4">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Couleurs disponibles</p>
                        <div className="flex flex-wrap gap-2">
                            {COLORS.map(c => {
                                const active = selectedColors.includes(c.name);
                                return (
                                    <button key={c.name} type="button"
                                        onClick={() => toggleVariant(selectedColors, setSelectedColors, c.name)}
                                        title={c.name}
                                        className={`relative w-8 h-8 rounded-full border-2 transition-transform hover:scale-110 ${active ? 'border-blue-500 scale-110 shadow-md' : 'border-gray-200'}`}
                                        style={{ backgroundColor: c.hex }}>
                                        {active && <span className="absolute inset-0 flex items-center justify-center text-white text-xs font-bold drop-shadow">✓</span>}
                                    </button>
                                );
                            })}
                        </div>
                        {selectedColors.length > 0 && (
                            <div className="flex flex-wrap gap-1 mt-2">
                                {selectedColors.map(v => (
                                    <span key={v} className="text-xs bg-gray-100 px-2 py-0.5 rounded-full text-gray-600">{v}</span>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Tailles */}
                    <div className="mb-4">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Tailles disponibles</p>
                        <div className="flex flex-wrap gap-2">
                            {SIZES.map(s => {
                                const active = selectedSizes.includes(s);
                                return (
                                    <button key={s} type="button"
                                        onClick={() => toggleVariant(selectedSizes, setSelectedSizes, s)}
                                        className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition
                                            ${active ? 'bg-blue-600 text-white border-blue-600 shadow-sm' : 'text-gray-600 border-gray-200 hover:border-blue-300 hover:text-blue-600'}`}>
                                        {s}
                                    </button>
                                );
                            })}
                        </div>
                    </div>

                    {/* Matières */}
                    <div>
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Matières</p>
                        <div className="flex flex-wrap gap-2">
                            {MATERIALS.map(m => {
                                const active = selectedMaterials.includes(m);
                                return (
                                    <button key={m} type="button"
                                        onClick={() => toggleVariant(selectedMaterials, setSelectedMaterials, m)}
                                        className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition
                                            ${active ? 'bg-purple-600 text-white border-purple-600 shadow-sm' : 'text-gray-600 border-gray-200 hover:border-purple-300 hover:text-purple-600'}`}>
                                        {m}
                                    </button>
                                );
                            })}
                        </div>
                    </div>
                </div>

                {/* ═══ CONDITIONS DE VENTE ═══ */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-4">
                    <h2 className="font-bold text-gray-900">📜 Conditions de vente</h2>

                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Politique de retour</label>
                        <select
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none bg-white"
                            value={returnPolicy}
                            onChange={e => setReturnPolicy(e.target.value)}
                        >
                            {RETURN_POLICIES.map(p => <option key={p} value={p}>{p}</option>)}
                        </select>
                    </div>

                    <label className="flex items-start gap-3 cursor-pointer group">
                        <input
                            type="checkbox"
                            checked={certifyAuthenticity}
                            onChange={e => setCertifyAuthenticity(e.target.checked)}
                            className="mt-1 w-5 h-5 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                        />
                        <div>
                            <p className="text-sm font-medium text-gray-700 group-hover:text-gray-900 transition-colors">
                                Je certifie l'authenticité de cet article ✅
                            </p>
                            <p className="text-xs text-gray-400 mt-0.5">
                                En cochant cette case, vous confirmez que les informations sont exactes et que le produit est conforme à la description.
                            </p>
                        </div>
                    </label>
                </div>

                {/* ═══ OLI TRUST SHIELD ═══ */}
                <div className="bg-gradient-to-r from-blue-50 to-indigo-50 p-5 rounded-xl border border-blue-100">
                    <div className="flex items-center gap-3 mb-3">
                        <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                            <ShieldCheck size={20} className="text-blue-600" />
                        </div>
                        <div>
                            <h3 className="font-bold text-blue-900">Oli Trust Shield</h3>
                            <p className="text-xs text-blue-600">Protection acheteur & vendeur</p>
                        </div>
                    </div>
                    <div className="space-y-2">
                        {[
                            { icon: '🔒', text: 'Paiement sécurisé via Oli Pay' },
                            { icon: '🏠', text: 'Restez sur la plateforme Oli pour être protégé' },
                            { icon: '📦', text: 'Livraison suivie avec numéro de tracking' },
                        ].map((item, i) => (
                            <div key={i} className="flex items-center gap-2 text-sm text-blue-800">
                                <span>{item.icon}</span>
                                <span>{item.text}</span>
                            </div>
                        ))}
                    </div>
                </div>

                {/* ═══ BOUTON PUBLIER ═══ */}
                <button
                    type="submit"
                    disabled={saving}
                    className="w-full py-4 bg-blue-600 text-white rounded-xl font-bold text-lg hover:bg-blue-700 shadow-lg hover:shadow-xl transition-all disabled:opacity-50 flex items-center justify-center gap-3"
                >
                    {saving ? (
                        <>
                            <Loader2 size={20} className="animate-spin" />
                            Publication en cours...
                        </>
                    ) : (
                        <>
                            <Save size={20} />
                            Publier l'article
                        </>
                    )}
                </button>
            </form>

            {/* ══════════════════════════════════════════════════════════ */}
            {/*  OVERLAYS                                                 */}
            {/* ══════════════════════════════════════════════════════════ */}

            {/* ── Category Overlay ── */}
            {showCategoryOverlay && (
                <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowCategoryOverlay(false)}>
                    <div className="bg-white rounded-2xl w-full max-w-lg max-h-[80vh] overflow-hidden" onClick={e => e.stopPropagation()}>
                        <div className="p-5 border-b border-gray-100 flex justify-between items-center">
                            <h3 className="font-bold text-lg text-gray-900">Choisir une catégorie</h3>
                            <button onClick={() => setShowCategoryOverlay(false)} className="text-gray-400 hover:text-gray-600">
                                <X size={20} />
                            </button>
                        </div>
                        <div className="p-4 overflow-y-auto max-h-[60vh]">
                            <div className="grid grid-cols-3 gap-3">
                                {CATEGORIES.map(cat => (
                                    <button
                                        key={cat.key}
                                        type="button"
                                        onClick={() => { setCategory(cat.key); setShowCategoryOverlay(false); }}
                                        className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${category === cat.key
                                            ? 'border-blue-500 bg-blue-50 shadow-md'
                                            : 'border-gray-100 hover:border-blue-200 hover:bg-gray-50'
                                            }`}
                                    >
                                        <span className="text-2xl">{cat.emoji}</span>
                                        <span className={`text-xs font-medium text-center ${category === cat.key ? 'text-blue-700' : 'text-gray-600'}`}>
                                            {cat.label}
                                        </span>
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* ── Condition Help Dialog ── */}
            {showConditionHelp && (
                <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowConditionHelp(false)}>
                    <div className="bg-white rounded-2xl w-full max-w-md p-6" onClick={e => e.stopPropagation()}>
                        <div className="flex items-center gap-2 mb-5">
                            <HelpCircle size={20} className="text-blue-500" />
                            <h3 className="font-bold text-lg text-gray-900">État du produit</h3>
                        </div>
                        <div className="space-y-4">
                            {[
                                { emoji: '✨', title: 'Neuf', desc: 'Article jamais utilisé, dans son emballage d\'origine.' },
                                { emoji: '👍', title: 'Occasion', desc: 'Article déjà utilisé mais en bon état général.' },
                                { emoji: '⚙️', title: 'Fonctionnel', desc: 'Article qui fonctionne correctement malgré des signes d\'usure.' },
                                { emoji: '🔧', title: 'Pour pièce ou à réparer', desc: 'Article endommagé, vendu pour récupération de pièces ou réparation.' },
                            ].map((item, i) => (
                                <div key={i} className="flex gap-3">
                                    <span className="text-xl">{item.emoji}</span>
                                    <div>
                                        <p className="font-medium text-gray-900 text-sm">{item.title}</p>
                                        <p className="text-xs text-gray-500">{item.desc}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <button onClick={() => setShowConditionHelp(false)} className="mt-5 w-full py-2.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors">
                            Compris
                        </button>
                    </div>
                </div>
            )}

            {/* ── Delivery Help Dialog ── */}
            {showDeliveryHelp && (
                <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowDeliveryHelp(false)}>
                    <div className="bg-white rounded-2xl w-full max-w-md p-6" onClick={e => e.stopPropagation()}>
                        <div className="flex items-center gap-2 mb-5">
                            <HelpCircle size={20} className="text-blue-500" />
                            <h3 className="font-bold text-lg text-gray-900">Modes de livraison</h3>
                        </div>
                        <div className="space-y-3">
                            {[
                                { emoji: '🚀', title: 'Oli Express', desc: 'Livraison rapide en 1-2h dans votre ville.' },
                                { emoji: '📦', title: 'Oli Standard', desc: 'Livraison classique en 2-5 jours.' },
                                { emoji: '🏍️', title: 'Livreur Partenaire', desc: 'Un livreur indépendant récupère le colis.' },
                                { emoji: '🤝', title: 'Remise en Main Propre', desc: 'Rencontre directe avec l\'acheteur.' },
                                { emoji: '📍', title: 'Pick & Go', desc: 'L\'acheteur retire en point relais.' },
                                { emoji: '🎁', title: 'Livraison Gratuite', desc: 'Vous offrez la livraison.' },
                            ].map((item, i) => (
                                <div key={i} className="flex gap-3">
                                    <span className="text-lg">{item.emoji}</span>
                                    <div>
                                        <p className="font-medium text-gray-900 text-sm">{item.title}</p>
                                        <p className="text-xs text-gray-500">{item.desc}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <button onClick={() => setShowDeliveryHelp(false)} className="mt-5 w-full py-2.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors">
                            Compris
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
