import { useState, useEffect, useRef } from 'react';
import { ArrowLeft, Plus, Trash2, Save, Loader2, X, HelpCircle, Camera, Tag, Package, ChevronDown, CheckCircle, AlertCircle, Layers, Palette, Ruler } from 'lucide-react';
import { useLocation, useNavigate } from 'react-router-dom';
import api from '../services/api';

// ══════════════════════════════════════════════════════════
//  CONSTANTES (identiques à ProductEditorDetail)
// ══════════════════════════════════════════════════════════

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

const CONDITIONS = ['Neuf', 'Occasion', 'Fonctionnel', 'Pour pièce ou à réparer'];

const AVAILABLE_METHODS = [
    { id: 'oli_express', label: 'Oli Express', time: '1-2h' },
    { id: 'oli_standard', label: 'Oli Standard', time: '2-5 jours' },
    { id: 'partner', label: 'Livreur Partenaire', time: 'Variable' },
    { id: 'hand_delivery', label: 'Remise en Main Propre', time: 'À convenir' },
    { id: 'pick_go', label: 'Pick & Go', time: 'Retrait immédiat' },
    { id: 'free', label: 'Livraison Gratuite', time: '3-7 jours' },
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

const PRESET_SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45'];

// Génère un produit vierge
const createEmptyProduct = () => ({
    name: '',
    price: '',
    description: '',
    category: 'electronics',
    condition: 'Neuf',
    quantity: '1',
    colors: [],          // string[]
    sizes: [],           // string[]
    location: '',
    images: [],          // File[]
    imagePreviews: [],   // string[] (object URLs)
    shippingMethod: '',
    shippingCost: '',
    shippingTime: '',
    certifyAuthenticity: false,
});

const MAX_PRODUCTS = 20;

// ══════════════════════════════════════════════════════════
//  COMPOSANT PRINCIPAL
// ══════════════════════════════════════════════════════════

export default function ProductBatchEditor() {
    const navigate = useNavigate();
    const routerLocation = useLocation();

    // --- State ---
    const [products, setProducts] = useState([createEmptyProduct()]);
    const [activeTab, setActiveTab] = useState(0);
    const [showCategoryOverlay, setShowCategoryOverlay] = useState(false);

    // Helper to run base64 to File
    const base64ToFile = (base64String, mimeType, index = 0) => {
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
            return new File([blob], `ai-screenshot-${index + 1}.jpg`, { type: mimeType });
        } catch (e) {
            console.error(e);
            return null;
        }
    };

    // --- Pre-fill from AI Import ---
    useEffect(() => {
        if (routerLocation.state?.aiBatchProducts && Array.isArray(routerLocation.state.aiBatchProducts)) {
            const aiProducts = routerLocation.state.aiBatchProducts;
            const aiImagesList = routerLocation.state.aiImages || [];
            
            const newMappedProducts = aiProducts.map((aiData, index) => {
                const emptyProd = createEmptyProduct();
                
                // Map basic fields
                emptyProd.name = aiData.name || '';
                emptyProd.price = aiData.price ? aiData.price.toString() : '';
                emptyProd.description = aiData.description || '';
                emptyProd.category = aiData.category || 'other';
                emptyProd.condition = aiData.condition === 'used' ? 'Occasion' : 'Neuf';
                emptyProd.colors = Array.isArray(aiData.colors) ? aiData.colors : [];
                emptyProd.sizes = Array.isArray(aiData.sizes) ? aiData.sizes : [];
                
                // Map shipping
                if (aiData.shippingOptions && aiData.shippingOptions.length > 0) {
                    const defaultShipping = aiData.shippingOptions[0]; // take the first (usually explicit air)
                    emptyProd.shippingMethod = defaultShipping.methodId;
                    emptyProd.shippingCost = defaultShipping.cost.toString();
                    emptyProd.shippingTime = defaultShipping.time;
                }
                
                // Map Image based on aiImageIndex
                const imgIndex = typeof aiData.aiImageIndex === 'number' ? aiData.aiImageIndex : index;
                if (aiImagesList[imgIndex]) {
                    const b64 = aiImagesList[imgIndex];
                    let mimeType = 'image/jpeg';
                    if (b64.startsWith('data:')) {
                        mimeType = b64.split(';')[0].split(':')[1];
                    }
                    const restoredFile = base64ToFile(b64, mimeType, imgIndex);
                    if (restoredFile) {
                        emptyProd.images = [restoredFile];
                        emptyProd.imagePreviews = [b64];
                    }
                }
                
                // Certification (require user to manually check it, so false by default)
                emptyProd.certifyAuthenticity = false;
                
                return emptyProd;
            });
            
            if (newMappedProducts.length > 0) {
                // Limit to MAX_PRODUCTS just in case
                setProducts(newMappedProducts.slice(0, MAX_PRODUCTS));
                setActiveTab(0);
            }
        }
    }, [routerLocation.state?.aiBatchProducts, routerLocation.state?.aiImages]);

    // --- Publishing state ---
    const [publishing, setPublishing] = useState(false);
    const [publishProgress, setPublishProgress] = useState(0);  // index courant
    const [publishTotal, setPublishTotal] = useState(0);
    const [publishResults, setPublishResults] = useState(null); // { success: number, errors: string[] }
    const [error, setError] = useState(null);

    // Ref pour scroll tabs
    const tabsRef = useRef(null);

    // ── Helpers ──

    const updateProduct = (index, field, value) => {
        setProducts(prev => {
            const updated = [...prev];
            updated[index] = { ...updated[index], [field]: value };
            return updated;
        });
    };

    const addProduct = () => {
        if (products.length >= MAX_PRODUCTS) return;
        setProducts(prev => [...prev, createEmptyProduct()]);
        setActiveTab(products.length);
        // Scroll tabs right
        setTimeout(() => {
            tabsRef.current?.scrollTo({ left: tabsRef.current.scrollWidth, behavior: 'smooth' });
        }, 50);
    };

    const removeProduct = (index) => {
        if (products.length <= 1) return;
        // Cleanup image previews
        products[index].imagePreviews.forEach(url => URL.revokeObjectURL(url));
        setProducts(prev => prev.filter((_, i) => i !== index));
        if (activeTab >= index && activeTab > 0) {
            setActiveTab(activeTab - 1);
        }
    };

    const duplicateProduct = (index) => {
        if (products.length >= MAX_PRODUCTS) return;
        const source = products[index];
        // Deep copy without images (can't duplicate File objects meaningfully)
        const dup = {
            ...source,
            name: source.name ? `${source.name} (copie)` : '',
            colors: [...source.colors],
            sizes: [...source.sizes],
            images: [],
            imagePreviews: [],
            certifyAuthenticity: false,
        };
        setProducts(prev => [...prev.slice(0, index + 1), dup, ...prev.slice(index + 1)]);
        setActiveTab(index + 1);
    };

    // ── Color/Size helpers ──

    const addColor = (productIndex, colorName) => {
        const p = products[productIndex];
        const trimmed = colorName.trim();
        if (!trimmed || p.colors.includes(trimmed)) return;
        updateProduct(productIndex, 'colors', [...p.colors, trimmed]);
    };

    const removeColor = (productIndex, colorIndex) => {
        const p = products[productIndex];
        updateProduct(productIndex, 'colors', p.colors.filter((_, i) => i !== colorIndex));
    };

    const addSize = (productIndex, sizeName) => {
        const p = products[productIndex];
        const trimmed = sizeName.trim();
        if (!trimmed || p.sizes.includes(trimmed)) return;
        updateProduct(productIndex, 'sizes', [...p.sizes, trimmed]);
    };

    const removeSize = (productIndex, sizeIndex) => {
        const p = products[productIndex];
        updateProduct(productIndex, 'sizes', p.sizes.filter((_, i) => i !== sizeIndex));
    };

    // ── Image handling ──

    const handleAddImages = (productIndex) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.multiple = true;
        input.onchange = (e) => {
            const files = Array.from(e.target.files);
            const p = products[productIndex];
            const remaining = 8 - p.images.length;
            const toAdd = files.slice(0, remaining);
            if (toAdd.length === 0) return;

            updateProduct(productIndex, 'images', [...p.images, ...toAdd]);
            updateProduct(productIndex, 'imagePreviews', [...p.imagePreviews, ...toAdd.map(f => URL.createObjectURL(f))]);
        };
        input.click();
    };

    const removeImage = (productIndex, imageIndex) => {
        const p = products[productIndex];
        URL.revokeObjectURL(p.imagePreviews[imageIndex]);
        updateProduct(productIndex, 'images', p.images.filter((_, i) => i !== imageIndex));
        updateProduct(productIndex, 'imagePreviews', p.imagePreviews.filter((_, i) => i !== imageIndex));
    };

    // Cleanup on unmount
    useEffect(() => {
        return () => {
            products.forEach(p => p.imagePreviews.forEach(url => URL.revokeObjectURL(url)));
        };
    }, []);

    // ── Shipping update ──
    const updateShipping = (productIndex, methodId) => {
        const isFree = methodId === 'free' || methodId === 'hand_delivery';
        setProducts(prev => {
            const updated = [...prev];
            updated[productIndex] = {
                ...updated[productIndex],
                shippingMethod: methodId,
                shippingCost: isFree ? '0' : updated[productIndex].shippingCost,
            };
            return updated;
        });
    };

    // ── Validation ──
    const getProductErrors = (p) => {
        const errors = [];
        if (!p.name.trim()) errors.push('Nom requis');
        if (!p.price.trim() || parseFloat(p.price) <= 0) errors.push('Prix requis');
        if (p.images.length === 0) errors.push('Photo requise');
        if (!p.certifyAuthenticity) errors.push('Certification requise');
        return errors;
    };

    const isProductValid = (p) => getProductErrors(p).length === 0;

    // ── Submit ──
    const handleBatchSubmit = async () => {
        setError(null);

        // Validate all
        const invalidIndexes = [];
        products.forEach((p, i) => {
            if (!isProductValid(p)) invalidIndexes.push(i);
        });

        if (invalidIndexes.length > 0) {
            setActiveTab(invalidIndexes[0]);
            setError(`${invalidIndexes.length} produit(s) incomplet(s). Vérifiez les onglets marqués en rouge.`);
            return;
        }

        setPublishing(true);
        setPublishTotal(products.length);
        setPublishProgress(0);

        const errors = [];
        let successCount = 0;

        for (let i = 0; i < products.length; i++) {
            setPublishProgress(i + 1);
            const p = products[i];

            try {
                const formData = new FormData();
                formData.append('name', p.name.trim());
                formData.append('price', p.price.trim());
                formData.append('description', p.description.trim());
                formData.append('condition', p.condition);
                formData.append('quantity', p.quantity || '1');
                formData.append('color', p.colors.join(', '));
                formData.append('colors', JSON.stringify(p.colors));
                formData.append('sizes', JSON.stringify(p.sizes));
                formData.append('category', p.category || 'other');
                formData.append('location', p.location.trim() || 'Non spécifiée');
                formData.append('is_negotiable', 'false');

                const shippingOptions = [{
                    methodId: p.shippingMethod,
                    cost: p.shippingCost || 0,
                    time: p.shippingTime,
                }];
                formData.append('delivery_price', p.shippingCost || 0);
                formData.append('delivery_time', p.shippingTime || '');
                formData.append('shipping_options', JSON.stringify(shippingOptions));

                p.images.forEach(image => {
                    formData.append('images', image);
                });

                await api.post('/products/upload', formData, {
                    headers: { 'Content-Type': 'multipart/form-data' }
                });

                successCount++;
            } catch (err) {
                console.error(`Erreur produit ${i + 1}:`, err);
                errors.push(`Produit ${i + 1} (${p.name || 'sans nom'}): ${err.response?.data?.error || 'Erreur'}`);
            }
        }

        setPublishResults({ success: successCount, errors });
        setPublishing(false);

        if (errors.length === 0) {
            // All succeeded → redirect after short delay
            setTimeout(() => navigate('/products'), 1500);
        }
    };

    // ── Current product shortcut ──
    const current = products[activeTab] || products[0];
    const selectedCategory = CATEGORIES.find(c => c.key === current.category);

    // ══════════════════════════════════════════════════════════
    //  RENDER
    // ══════════════════════════════════════════════════════════

    return (
        <div className="p-6 max-w-4xl mx-auto">
            {/* Back */}
            <button onClick={() => navigate('/products/new')} className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900 transition-colors">
                <ArrowLeft size={16} /> Retour au choix du mode
            </button>

            <div className="flex items-center gap-3 mb-6">
                <div className="w-10 h-10 rounded-xl bg-amber-100 flex items-center justify-center">
                    <Layers size={22} className="text-amber-600" />
                </div>
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Publication en Lot</h1>
                    <p className="text-gray-500 text-sm">Ajoutez jusqu'à {MAX_PRODUCTS} produits en une seule session</p>
                </div>
            </div>

            {/* Error global */}
            {error && (
                <div className="mb-4 bg-red-50 border border-red-200 text-red-700 rounded-lg p-3 flex items-start gap-2">
                    <AlertCircle size={16} className="mt-0.5 flex-shrink-0" />
                    <span className="text-sm">{error}</span>
                    <button onClick={() => setError(null)} className="ml-auto text-red-400 hover:text-red-600"><X size={14} /></button>
                </div>
            )}

            {/* ═══ PUBLISHING MODAL ═══ */}
            {(publishing || publishResults) && (
                <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl w-full max-w-md p-8 text-center">
                        {publishing ? (
                            <>
                                <Loader2 size={48} className="animate-spin text-amber-500 mx-auto mb-4" />
                                <h3 className="text-xl font-bold text-gray-900 mb-2">Publication en cours...</h3>
                                <p className="text-gray-500 mb-4">Produit {publishProgress} / {publishTotal}</p>
                                <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
                                    <div
                                        className="h-3 rounded-full bg-amber-500 transition-all duration-300"
                                        style={{ width: `${(publishProgress / publishTotal) * 100}%` }}
                                    />
                                </div>
                            </>
                        ) : publishResults ? (
                            <>
                                {publishResults.errors.length === 0 ? (
                                    <CheckCircle size={48} className="text-green-500 mx-auto mb-4" />
                                ) : (
                                    <AlertCircle size={48} className="text-amber-500 mx-auto mb-4" />
                                )}
                                <h3 className="text-xl font-bold text-gray-900 mb-2">
                                    {publishResults.errors.length === 0
                                        ? `${publishResults.success} produit(s) publié(s) ! 🎉`
                                        : `${publishResults.success} publié(s), ${publishResults.errors.length} erreur(s)`
                                    }
                                </h3>
                                {publishResults.errors.length > 0 && (
                                    <div className="text-left mt-4 max-h-40 overflow-y-auto">
                                        {publishResults.errors.map((err, i) => (
                                            <div key={i} className="text-sm text-red-600 bg-red-50 p-2 rounded mb-1">
                                                {err}
                                            </div>
                                        ))}
                                    </div>
                                )}
                                <button
                                    onClick={() => navigate('/products')}
                                    className="mt-6 w-full py-3 bg-amber-500 text-white rounded-xl font-bold hover:bg-amber-600 transition-colors"
                                >
                                    Voir mes produits
                                </button>
                            </>
                        ) : null}
                    </div>
                </div>
            )}

            {/* ═══ TABS (Product Selector) ═══ */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 mb-6">
                <div className="flex items-center border-b border-gray-100">
                    <div
                        ref={tabsRef}
                        className="flex-1 flex overflow-x-auto scrollbar-hide"
                        style={{ scrollbarWidth: 'none' }}
                    >
                        {products.map((p, i) => {
                            const errors = getProductErrors(p);
                            const isValid = errors.length === 0;
                            const isActive = i === activeTab;

                            return (
                                <button
                                    key={i}
                                    onClick={() => setActiveTab(i)}
                                    className={`relative flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-all border-b-2 ${isActive
                                        ? 'border-amber-500 text-amber-700 bg-amber-50/50'
                                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                                        }`}
                                >
                                    {/* Status dot */}
                                    <span className={`w-2 h-2 rounded-full flex-shrink-0 ${isValid ? 'bg-green-400' : (p.name || p.images.length > 0 ? 'bg-amber-400' : 'bg-gray-300')
                                        }`} />

                                    <span>Produit {i + 1}</span>

                                    {p.name && (
                                        <span className="text-xs text-gray-400 max-w-[80px] truncate">
                                            {p.name}
                                        </span>
                                    )}

                                    {/* Remove button */}
                                    {products.length > 1 && (
                                        <span
                                            onClick={(e) => { e.stopPropagation(); removeProduct(i); }}
                                            className="ml-1 text-gray-300 hover:text-red-500 transition-colors"
                                        >
                                            <X size={12} />
                                        </span>
                                    )}
                                </button>
                            );
                        })}
                    </div>

                    {/* Add button */}
                    <button
                        onClick={addProduct}
                        disabled={products.length >= MAX_PRODUCTS}
                        className="flex items-center gap-1 px-4 py-3 text-sm font-medium text-amber-600 hover:bg-amber-50 transition-colors border-l border-gray-100 disabled:opacity-30 disabled:cursor-not-allowed"
                    >
                        <Plus size={16} />
                        <span className="hidden sm:inline">Ajouter</span>
                    </button>
                </div>

                {/* Products count */}
                <div className="px-4 py-2 bg-gray-50/50 flex items-center justify-between text-xs text-gray-400">
                    <span>{products.length}/{MAX_PRODUCTS} produit(s)</span>
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => duplicateProduct(activeTab)}
                            disabled={products.length >= MAX_PRODUCTS}
                            className="text-blue-500 hover:text-blue-700 disabled:opacity-30 font-medium"
                        >
                            Dupliquer
                        </button>
                        {products.length > 1 && products.filter(p => isProductValid(p)).length > 0 && (
                            <span className="text-green-500">
                                ✓ {products.filter(p => isProductValid(p)).length} prêt(s)
                            </span>
                        )}
                    </div>
                </div>
            </div>

            {/* ═══ PRODUCT FORM (active tab) ═══ */}
            <div className="space-y-5">

                {/* ── Photos ── */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex items-center justify-between mb-3">
                        <h2 className="font-bold text-gray-900 flex items-center gap-2">
                            <Camera size={18} className="text-amber-500" /> Photos
                        </h2>
                        <span className="text-xs text-gray-400">{current.images.length}/8</span>
                    </div>

                    <div className="flex flex-wrap gap-2">
                        {current.imagePreviews.map((url, i) => (
                            <div key={i} className="relative w-20 h-20 rounded-lg overflow-hidden border border-gray-200 group">
                                <img src={url} alt="" className="w-full h-full object-cover" />
                                <button
                                    type="button"
                                    onClick={() => removeImage(activeTab, i)}
                                    className="absolute top-0.5 right-0.5 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity"
                                >
                                    <X size={10} />
                                </button>
                            </div>
                        ))}

                        {current.images.length < 8 && (
                            <button
                                type="button"
                                onClick={() => handleAddImages(activeTab)}
                                className="w-20 h-20 rounded-lg border-2 border-dashed border-amber-200 bg-amber-50/30 hover:bg-amber-50 flex flex-col items-center justify-center cursor-pointer transition-all"
                            >
                                <Plus size={18} className="text-amber-400" />
                                <span className="text-[9px] text-amber-400 mt-0.5">Photos</span>
                            </button>
                        )}
                    </div>
                </div>

                {/* ── Infos principales ── */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-4">
                    <h2 className="font-bold text-gray-900 flex items-center gap-2">
                        <Tag size={18} className="text-amber-500" /> Informations
                    </h2>

                    {/* Nom */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Nom du produit *</label>
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none"
                            placeholder="ex: iPhone 14 Pro Max 256GB"
                            value={current.name}
                            onChange={e => updateProduct(activeTab, 'name', e.target.value)}
                        />
                    </div>

                    {/* Prix + Quantité (2 cols) */}
                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Prix ($) *</label>
                            <input
                                type="number"
                                min="0"
                                className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none"
                                placeholder="ex: 250"
                                value={current.price}
                                onChange={e => updateProduct(activeTab, 'price', e.target.value)}
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Quantité</label>
                            <input
                                type="number"
                                min="1"
                                className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none"
                                placeholder="1"
                                value={current.quantity}
                                onChange={e => updateProduct(activeTab, 'quantity', e.target.value)}
                            />
                        </div>
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
                                <span className="text-gray-700">{selectedCategory?.label || 'Choisir...'}</span>
                            </span>
                            <ChevronDown size={16} className="text-gray-400" />
                        </button>
                    </div>

                    {/* État */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">État *</label>
                        <select
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none bg-white"
                            value={current.condition}
                            onChange={e => updateProduct(activeTab, 'condition', e.target.value)}
                        >
                            {CONDITIONS.map(c => <option key={c} value={c}>{c}</option>)}
                        </select>
                    </div>
                </div>

                {/* ── Couleurs & Tailles ── */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-5">
                    {/* Couleurs */}
                    <div>
                        <label className="text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
                            <Palette size={16} className="text-amber-500" /> Couleurs disponibles
                        </label>

                        {/* Selected colors */}
                        {current.colors.length > 0 && (
                            <div className="flex flex-wrap gap-2 mb-3">
                                {current.colors.map((c, i) => {
                                    const preset = PRESET_COLORS.find(pc => pc.name === c);
                                    return (
                                        <span
                                            key={i}
                                            className="inline-flex items-center gap-1.5 bg-gray-100 text-gray-700 text-sm px-3 py-1.5 rounded-full group"
                                        >
                                            {preset && (
                                                <span
                                                    className="w-3.5 h-3.5 rounded-full border border-gray-300 flex-shrink-0"
                                                    style={{ backgroundColor: preset.hex }}
                                                />
                                            )}
                                            {c}
                                            <button
                                                type="button"
                                                onClick={() => removeColor(activeTab, i)}
                                                className="text-gray-400 hover:text-red-500 transition-colors"
                                            >
                                                <X size={12} />
                                            </button>
                                        </span>
                                    );
                                })}
                            </div>
                        )}

                        {/* Preset color swatches */}
                        <div className="flex flex-wrap gap-2 mb-3">
                            {PRESET_COLORS.map(pc => {
                                const isSelected = current.colors.includes(pc.name);
                                return (
                                    <button
                                        key={pc.name}
                                        type="button"
                                        onClick={() => isSelected ? removeColor(activeTab, current.colors.indexOf(pc.name)) : addColor(activeTab, pc.name)}
                                        className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-full border text-xs font-medium transition-all ${isSelected
                                            ? 'border-amber-400 bg-amber-50 text-amber-700 shadow-sm'
                                            : 'border-gray-200 hover:border-gray-300 text-gray-600 hover:bg-gray-50'
                                            }`}
                                        title={pc.name}
                                    >
                                        <span
                                            className={`w-3.5 h-3.5 rounded-full border flex-shrink-0 ${isSelected ? 'border-amber-400' : 'border-gray-300'}`}
                                            style={{ backgroundColor: pc.hex }}
                                        />
                                        {pc.name}
                                    </button>
                                );
                            })}
                        </div>

                        {/* Custom color input */}
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-2.5 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none text-sm"
                            placeholder="Autre couleur + Entrée"
                            onKeyDown={e => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    addColor(activeTab, e.target.value);
                                    e.target.value = '';
                                }
                            }}
                        />
                    </div>

                    <hr className="border-gray-100" />

                    {/* Tailles */}
                    <div>
                        <label className="text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
                            <Ruler size={16} className="text-amber-500" /> Tailles disponibles
                        </label>

                        {/* Selected sizes */}
                        {current.sizes.length > 0 && (
                            <div className="flex flex-wrap gap-2 mb-3">
                                {current.sizes.map((s, i) => (
                                    <span
                                        key={i}
                                        className="inline-flex items-center gap-1.5 bg-gray-100 text-gray-700 text-sm px-3 py-1.5 rounded-full"
                                    >
                                        {s}
                                        <button
                                            type="button"
                                            onClick={() => removeSize(activeTab, i)}
                                            className="text-gray-400 hover:text-red-500 transition-colors"
                                        >
                                            <X size={12} />
                                        </button>
                                    </span>
                                ))}
                            </div>
                        )}

                        {/* Preset size chips */}
                        <div className="flex flex-wrap gap-2 mb-3">
                            {PRESET_SIZES.map(size => {
                                const isSelected = current.sizes.includes(size);
                                return (
                                    <button
                                        key={size}
                                        type="button"
                                        onClick={() => isSelected ? removeSize(activeTab, current.sizes.indexOf(size)) : addSize(activeTab, size)}
                                        className={`px-3 py-1.5 rounded-full border text-xs font-medium transition-all ${isSelected
                                            ? 'border-amber-400 bg-amber-50 text-amber-700 shadow-sm'
                                            : 'border-gray-200 hover:border-gray-300 text-gray-600 hover:bg-gray-50'
                                            }`}
                                    >
                                        {size}
                                    </button>
                                );
                            })}
                        </div>

                        {/* Custom size input */}
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-2.5 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none text-sm"
                            placeholder="Autre taille + Entrée (ex: 46, Unique, 128GB...)"
                            onKeyDown={e => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    addSize(activeTab, e.target.value);
                                    e.target.value = '';
                                }
                            }}
                        />
                    </div>

                    {/* Localisation */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Localisation</label>
                        <input
                            type="text"
                            className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none"
                            placeholder="ex: Kinshasa, Lubumbashi"
                            value={current.location}
                            onChange={e => updateProduct(activeTab, 'location', e.target.value)}
                        />
                    </div>
                </div>

                {/* ── Livraison ── */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 space-y-3">
                    <h2 className="font-bold text-gray-900 flex items-center gap-2">
                        <Package size={18} className="text-amber-500" /> Livraison
                    </h2>

                    <div className="grid grid-cols-3 gap-4">
                        <div>
                            <label className="block text-xs text-gray-500 mb-1">Mode de livraison *</label>
                            <select
                                className="w-full border border-gray-200 p-2.5 rounded-lg text-sm bg-white"
                                value={current.shippingMethod}
                                onChange={e => updateShipping(activeTab, e.target.value)}
                            >
                                <option value="">Choisir...</option>
                                {AVAILABLE_METHODS.map(m => (
                                    <option key={m.id} value={m.id}>{m.label}</option>
                                ))}
                            </select>
                        </div>
                        <div>
                            <label className="block text-xs text-gray-500 mb-1">Délai (jours) *</label>
                            <input
                                type="number"
                                min="1"
                                className="w-full border border-gray-200 p-2.5 rounded-lg text-sm"
                                placeholder="ex: 3"
                                value={current.shippingTime}
                                onChange={e => updateProduct(activeTab, 'shippingTime', e.target.value)}
                            />
                        </div>
                        <div>
                            <label className="block text-xs text-gray-500 mb-1">Coût ($)</label>
                            <input
                                type="number"
                                min="0"
                                step="0.01"
                                className={`w-full border border-gray-200 p-2.5 rounded-lg text-sm ${['free', 'hand_delivery', 'partner'].includes(current.shippingMethod) ? 'bg-gray-100 text-gray-400' : ''
                                    }`}
                                placeholder={current.shippingMethod === 'partner' ? 'Auto' : '0.00'}
                                value={current.shippingCost}
                                onChange={e => updateProduct(activeTab, 'shippingCost', e.target.value)}
                                disabled={['free', 'hand_delivery', 'partner'].includes(current.shippingMethod)}
                            />
                        </div>
                    </div>
                </div>

                {/* ── Description ── */}
                <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="font-bold text-gray-900 mb-3">📝 Description</h2>
                    <textarea
                        className="w-full border border-gray-200 p-3 rounded-lg focus:ring-2 focus:ring-amber-500 outline-none resize-y leading-relaxed text-sm"
                        rows={4}
                        placeholder="Décrivez votre produit..."
                        value={current.description}
                        onChange={e => updateProduct(activeTab, 'description', e.target.value)}
                    />
                </div>

                {/* ── Certification ── */}
                <label className="flex items-start gap-3 bg-white p-4 rounded-xl shadow-sm border border-gray-100 cursor-pointer group">
                    <input
                        type="checkbox"
                        checked={current.certifyAuthenticity}
                        onChange={e => updateProduct(activeTab, 'certifyAuthenticity', e.target.checked)}
                        className="mt-1 w-5 h-5 text-amber-600 rounded border-gray-300 focus:ring-amber-500"
                    />
                    <div>
                        <p className="text-sm font-medium text-gray-700 group-hover:text-gray-900 transition-colors">
                            Je certifie l'authenticité de cet article ✅
                        </p>
                        <p className="text-xs text-gray-400 mt-0.5">
                            Les informations sont exactes et le produit est conforme.
                        </p>
                    </div>
                </label>
            </div>

            {/* ═══ SUMMARY BAR ═══ */}
            <div className="mt-8 bg-white p-5 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <h3 className="font-bold text-gray-900">Résumé de la publication</h3>
                        <p className="text-sm text-gray-500">
                            {products.length} produit(s) — {products.filter(p => isProductValid(p)).length} prêt(s)
                        </p>
                    </div>
                    <div className="flex items-center gap-2">
                        {products.map((p, i) => (
                            <span
                                key={i}
                                onClick={() => setActiveTab(i)}
                                className={`w-3 h-3 rounded-full cursor-pointer transition-all ${isProductValid(p) ? 'bg-green-400' : 'bg-red-300'
                                    } ${i === activeTab ? 'ring-2 ring-offset-1 ring-amber-400' : ''}`}
                                title={`Produit ${i + 1}: ${p.name || 'sans nom'}`}
                            />
                        ))}
                    </div>
                </div>

                <button
                    onClick={handleBatchSubmit}
                    disabled={publishing || products.filter(p => isProductValid(p)).length === 0}
                    className="w-full py-4 bg-amber-500 text-white rounded-xl font-bold text-lg hover:bg-amber-600 shadow-lg hover:shadow-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-3"
                >
                    <Save size={20} />
                    Publier {products.length} produit{products.length > 1 ? 's' : ''}
                </button>
            </div>

            {/* ═══ CATEGORY OVERLAY ═══ */}
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
                                        onClick={() => {
                                            updateProduct(activeTab, 'category', cat.key);
                                            setShowCategoryOverlay(false);
                                        }}
                                        className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${current.category === cat.key
                                            ? 'border-amber-500 bg-amber-50 shadow-md'
                                            : 'border-gray-100 hover:border-amber-200 hover:bg-gray-50'
                                            }`}
                                    >
                                        <span className="text-2xl">{cat.emoji}</span>
                                        <span className={`text-xs font-medium text-center ${current.category === cat.key ? 'text-amber-700' : 'text-gray-600'}`}>
                                            {cat.label}
                                        </span>
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
