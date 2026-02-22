import { useState, useEffect } from 'react';
import { Plus, Trash, ArrowLeft, Truck, Save, Loader2, X } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../services/api';
import { sellerAPI, productAPI } from '../services/api';

export default function ProductEditor() {
    const navigate = useNavigate();
    const { productId } = useParams(); // Si présent → mode édition
    const isEditMode = !!productId;

    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [loadError, setLoadError] = useState(null);

    const [b2bPricing, setB2bPricing] = useState([
        { min: 1, max: 50, price: '' }
    ]);

    // --- Modes de livraison disponibles ---
    const availableMethods = [
        { id: 'oli_express', label: 'Oli Express', time: '1-2h', description: 'Livraison rapide gérée par Oli' },
        { id: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', description: 'Livraison standard gérée par Oli' },
        { id: 'partner', label: 'Livreur Partenaire', time: 'Variable', description: 'Prix calculé automatiquement selon la distance' },
        { id: 'hand_delivery', label: 'Remise en Main Propre', time: 'À convenir', description: 'Le vendeur et l\'acheteur s\'arrangent' },
        { id: 'pick_go', label: 'Pick & Go', time: 'Retrait immédiat', description: 'L\'acheteur récupère au guérite du magasin' },
        { id: 'free', label: 'Livraison Gratuite', time: '3-7 jours', description: 'Offerte par le vendeur' }
    ];

    // --- État pour les options de livraison multiples ---
    const [shippingOptions, setShippingOptions] = useState([
        { methodId: 'oli_standard', cost: '', time: '2-5 jours' }
    ]);

    const addShippingOption = () => {
        setShippingOptions([...shippingOptions, { methodId: '', cost: '', time: '' }]);
    };

    const updateShippingOption = (index, field, value) => {
        const newOptions = [...shippingOptions];

        if (field === 'methodId') {
            if (value === 'free' || value === 'hand_delivery') {
                newOptions[index].cost = 0;
            } else if (value === 'partner') {
                newOptions[index].cost = '';
            }
            const method = availableMethods.find(m => m.id === value);
            if (method) newOptions[index].time = method.time;
        }

        newOptions[index][field] = value;
        setShippingOptions(newOptions);
    };

    const removeShippingOption = (index) => {
        setShippingOptions(shippingOptions.filter((_, i) => i !== index));
    };

    const [product, setProduct] = useState({
        name: '',
        category: '',
        basePrice: '',
        moq: 1,
        brand: '',
        unit: 'Pièce',
        weight: '',
        description: '',
        quantity: ''
    });
    const [images, setImages] = useState([]); // Nouvelles images (File objects)
    const [existingImages, setExistingImages] = useState([]); // Images existantes (URLs)
    const [removedImages, setRemovedImages] = useState([]); // Images à supprimer

    const units = [
        "Pièce", "Kg", "Litre", "Carton (6)", "Carton (12)", "Carton (24)",
        "Douzaine", "Paquet", "Sac (25kg)", "Sac (50kg)", "Palette"
    ];

    const categories = [
        { label: "Industrie", value: "industry" },
        { label: "Maison", value: "home" },
        { label: "Véhicules", value: "vehicles" },
        { label: "Mode", value: "fashion" },
        { label: "Électronique", value: "electronics" },
        { label: "Sports", value: "sports" },
        { label: "Beauté", value: "beauty" },
        { label: "Jouets", value: "toys" },
        { label: "Santé", value: "health" },
        { label: "Construction", value: "construction" },
        { label: "Outils", value: "tools" },
        { label: "Bureau", value: "office" },
        { label: "Jardin", value: "garden" },
        { label: "Animaux", value: "pets" },
        { label: "Bébé", value: "baby" },
        { label: "Alimentation", value: "food" },
        { label: "Sécurité", value: "security" },
        { label: "Autres", value: "other" }
    ];

    // --- Charger le produit en mode édition ---
    useEffect(() => {
        if (isEditMode) {
            loadProduct();
        }
    }, [productId]);

    const loadProduct = async () => {
        try {
            setLoading(true);
            setLoadError(null);
            const data = await sellerAPI.getProductById(productId);

            // Mapper les données du backend vers l'état local
            const p = data.product || data;
            setProduct({
                name: p.name || '',
                category: p.category || '',
                basePrice: p.price ? String(p.price) : '',
                moq: p.moq || 1,
                brand: p.brand || '',
                unit: p.unit || 'Pièce',
                weight: p.weight || '',
                description: p.description || '',
                quantity: p.quantity ? String(p.quantity) : ''
            });

            // Images existantes
            if (p.images && p.images.length > 0) {
                const CLOUD_NAME = 'dbfpnxjmm';
                const imageUrls = p.images.map(img => {
                    if (img.startsWith('http')) return img;
                    const cleanPath = img.startsWith('/') ? img.slice(1) : img;
                    if (cleanPath.startsWith('uploads/')) {
                        const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';
                        return `${API_URL}/${cleanPath}`;
                    }
                    return `https://res.cloudinary.com/${CLOUD_NAME}/image/upload/${cleanPath}`;
                });
                setExistingImages(imageUrls);
            }

            // B2B pricing
            if (p.b2b_pricing && Array.isArray(p.b2b_pricing) && p.b2b_pricing.length > 0) {
                setB2bPricing(p.b2b_pricing);
            }

            // Shipping options
            if (p.shipping_options && Array.isArray(p.shipping_options) && p.shipping_options.length > 0) {
                setShippingOptions(p.shipping_options.map(opt => ({
                    methodId: opt.methodId || opt.method_id || 'oli_standard',
                    cost: opt.cost || '',
                    time: opt.time || ''
                })));
            }

            // Discount
            if (p.discount_price) {
                setProduct(prev => ({
                    ...prev,
                    discount_price: String(p.discount_price),
                    discount_start_date: p.discount_start_date || '',
                    discount_end_date: p.discount_end_date || ''
                }));
            }
        } catch (err) {
            console.error("Erreur chargement produit:", err);
            setLoadError("Impossible de charger le produit. Vérifiez votre connexion.");
        } finally {
            setLoading(false);
        }
    };

    const addTier = () => {
        const lastMax = b2bPricing[b2bPricing.length - 1]?.max || 0;
        setB2bPricing([...b2bPricing, { min: lastMax + 1, max: '', price: '' }]);
    };

    const updateTier = (index, field, value) => {
        const newPricing = [...b2bPricing];
        newPricing[index][field] = value;
        setB2bPricing(newPricing);
    };

    const removeTier = (index) => {
        setB2bPricing(b2bPricing.filter((_, i) => i !== index));
    };

    const handleImageChange = (e) => {
        if (e.target.files) {
            setImages([...images, ...Array.from(e.target.files)]);
        }
    };

    const removeImage = (index) => {
        setImages(images.filter((_, i) => i !== index));
    };

    const removeExistingImage = (index) => {
        const url = existingImages[index];
        setRemovedImages([...removedImages, url]);
        setExistingImages(existingImages.filter((_, i) => i !== index));
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        // Validation : au moins 1 image
        if (images.length === 0 && existingImages.length === 0) {
            alert('Veuillez ajouter au moins une photo du produit.');
            return;
        }

        setSaving(true);

        try {
            const formData = new FormData();

            // Champs de base
            Object.keys(product).forEach(key => {
                if (product[key] !== '' && product[key] !== undefined) {
                    formData.append(key, product[key]);
                }
            });

            // Toujours envoyer 'price' explicitement pour le backend
            if (product.basePrice) {
                formData.set('price', product.basePrice);
            }

            // Nouvelles images
            images.forEach(image => {
                formData.append('images', image);
            });

            // B2B pricing
            formData.append('b2b_pricing', JSON.stringify(b2bPricing));

            // Shipping options
            formData.append('shipping_options', JSON.stringify(shippingOptions));

            if (isEditMode) {
                // Images existantes à conserver
                const keptImages = existingImages.filter(url => !removedImages.includes(url));
                formData.append('existing_images', JSON.stringify(keptImages));
                formData.append('removed_images', JSON.stringify(removedImages));

                // Mapper basePrice → price pour le backend
                formData.set('price', product.basePrice);

                await productAPI.update(productId, formData);
                alert("Produit mis à jour avec succès !");
            } else {
                await api.post('/products/upload', formData, {
                    headers: { 'Content-Type': 'multipart/form-data' }
                });
                alert("Produit publié avec succès !");
            }

            navigate('/products');
        } catch (err) {
            console.error("Erreur:", err);
            alert(isEditMode ? "Erreur lors de la mise à jour" : "Erreur lors de la publication");
        } finally {
            setSaving(false);
        }
    };

    // --- Loading / Error states ---
    if (loading) {
        return (
            <div className="flex justify-center items-center h-96">
                <div className="text-center">
                    <Loader2 size={40} className="animate-spin text-blue-600 mx-auto mb-4" />
                    <p className="text-gray-500">Chargement du produit...</p>
                </div>
            </div>
        );
    }

    if (loadError) {
        return (
            <div className="p-8 max-w-5xl mx-auto">
                <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
                    <p className="text-red-600 mb-4">{loadError}</p>
                    <button onClick={loadProduct} className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700">
                        Réessayer
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="p-8 max-w-5xl mx-auto">
            <button onClick={() => navigate('/products')} className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900">
                <ArrowLeft size={16} /> Retour
            </button>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">
                {isEditMode ? '✏️ Modifier le produit' : '➕ Ajouter un nouveau produit'}
            </h1>

            <form onSubmit={handleSubmit} className="space-y-8">
                {/* Basic Info */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h2 className="text-lg font-bold mb-4">Informations de base</h2>
                    <div className="grid grid-cols-2 gap-6">
                        <div className="col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">Nom du produit</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                                value={product.name}
                                onChange={e => setProduct({ ...product, name: e.target.value })}
                                required
                            />
                        </div>

                        {/* DESCRIPTION — NOUVEAU */}
                        <div className="col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Description du produit
                            </label>
                            <textarea
                                className="w-full border p-3 rounded focus:ring-2 focus:ring-blue-500 outline-none resize-y"
                                rows={5}
                                placeholder="Décrivez votre produit en détail : caractéristiques, matériaux, dimensions, conseils d'utilisation..."
                                value={product.description}
                                onChange={e => setProduct({ ...product, description: e.target.value })}
                            />
                            <p className="text-xs text-gray-400 mt-1 text-right">
                                {product.description.length} caractère{product.description.length > 1 ? 's' : ''}
                            </p>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Catégorie *</label>
                            <select
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                                value={product.category}
                                onChange={e => setProduct({ ...product, category: e.target.value })}
                                required
                            >
                                <option value="">Choisir une catégorie...</option>
                                {categories.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
                            </select>
                            <p className="text-xs text-gray-500 mt-1">Sélectionnez la catégorie principale du produit</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Marque</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded"
                                placeholder="ex: Coca-Cola, Samsung"
                                value={product.brand}
                                onChange={e => setProduct({ ...product, brand: e.target.value })}
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Prix Standard (1 unité)</label>
                            <input
                                type="number"
                                className="w-full border p-2 rounded"
                                value={product.basePrice}
                                onChange={e => setProduct({ ...product, basePrice: e.target.value })}
                                required
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Unité de vente</label>
                            <select
                                className="w-full border p-2 rounded"
                                value={product.unit}
                                onChange={e => setProduct({ ...product, unit: e.target.value })}
                            >
                                {units.map(u => <option key={u} value={u}>{u}</option>)}
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Poids / Volume</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded"
                                placeholder="ex: 500g, 1.5L"
                                value={product.weight}
                                onChange={e => setProduct({ ...product, weight: e.target.value })}
                            />
                        </div>

                        {/* QUANTITÉ — NOUVEAU */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Quantité en stock</label>
                            <input
                                type="number"
                                min="0"
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                                placeholder="ex: 100"
                                value={product.quantity}
                                onChange={e => setProduct({ ...product, quantity: e.target.value })}
                            />
                        </div>
                    </div>
                </div>

                {/* --- SECTION : MODES DE LIVRAISON MULTIPLES --- */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-bold text-blue-700 flex items-center gap-2">
                            <Truck size={20} /> Modes de livraison proposés
                        </h2>
                        <button
                            type="button"
                            onClick={addShippingOption}
                            className="text-sm bg-blue-50 text-blue-600 px-3 py-1 rounded-full hover:bg-blue-100 flex items-center gap-1 font-medium transition-colors"
                        >
                            <Plus size={14} /> Ajouter un mode
                        </button>
                    </div>

                    <p className="text-sm text-gray-500 mb-4 italic">
                        L'acheteur pourra choisir l'option qui convient le mieux à son budget et à son urgence.
                    </p>

                    <div className="space-y-3">
                        {shippingOptions.map((option, index) => {
                            const method = availableMethods.find(m => m.id === option.methodId);
                            const isCostDisabled = option.methodId === 'free' || option.methodId === 'hand_delivery' || option.methodId === 'partner';
                            return (
                                <div key={index} className="bg-gray-50 p-4 rounded-lg border border-gray-100 relative group">
                                    <div className="flex gap-4 items-end">
                                        <div className="flex-1">
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Mode de transport</label>
                                            <select
                                                className="w-full border p-2 rounded-md bg-white shadow-sm"
                                                value={option.methodId}
                                                onChange={(e) => updateShippingOption(index, 'methodId', e.target.value)}
                                                required
                                            >
                                                <option value="">Sélectionner...</option>
                                                {availableMethods.map(m => (
                                                    <option key={m.id} value={m.id}>{m.label} ({m.time})</option>
                                                ))}
                                            </select>
                                        </div>
                                        <div className="w-28">
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Délai</label>
                                            <input
                                                type="text"
                                                placeholder="ex: 1-2h"
                                                className="w-full border p-2 rounded-md bg-white shadow-sm text-sm"
                                                value={option.time || ''}
                                                onChange={(e) => updateShippingOption(index, 'time', e.target.value)}
                                            />
                                        </div>
                                        <div className="w-32">
                                            <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Coût ($)</label>
                                            <input
                                                type="number"
                                                min="0"
                                                step="0.01"
                                                placeholder={option.methodId === 'partner' ? 'Auto' : '0.00'}
                                                className={`w-full border p-2 rounded-md bg-white shadow-sm ${isCostDisabled ? 'bg-gray-200 text-gray-400' : ''}`}
                                                value={option.cost}
                                                onChange={(e) => updateShippingOption(index, 'cost', e.target.value)}
                                                disabled={isCostDisabled}
                                                required={!isCostDisabled}
                                            />
                                        </div>
                                        {shippingOptions.length > 1 && (
                                            <button
                                                type="button"
                                                onClick={() => removeShippingOption(index)}
                                                className="p-2 text-red-400 hover:text-red-600 transition-colors"
                                            >
                                                <Trash size={18} />
                                            </button>
                                        )}
                                    </div>
                                    {method && (
                                        <p className="text-xs text-gray-400 mt-2 italic">{method.description}</p>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>

                {/* Image Upload Section */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h2 className="text-lg font-bold mb-4">Photos du produit</h2>

                    {/* Images existantes (mode édition) */}
                    {existingImages.length > 0 && (
                        <div className="mb-4">
                            <p className="text-sm text-gray-500 mb-2">Photos actuelles :</p>
                            <div className="grid grid-cols-4 gap-4">
                                {existingImages.map((url, idx) => (
                                    <div key={`existing-${idx}`} className="relative group aspect-square rounded overflow-hidden border-2 border-green-200">
                                        <img
                                            src={url}
                                            alt={`Photo ${idx + 1}`}
                                            className="w-full h-full object-cover"
                                            onError={(e) => e.target.src = 'https://via.placeholder.com/100?text=Erreur'}
                                        />
                                        <button
                                            type="button"
                                            onClick={() => removeExistingImage(idx)}
                                            className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 shadow hover:bg-red-600 opacity-0 group-hover:opacity-100 transition-opacity"
                                        >
                                            <X size={14} />
                                        </button>
                                        <div className="absolute bottom-0 left-0 right-0 bg-green-600 text-white text-xs text-center py-0.5">
                                            En ligne
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center bg-gray-50 hover:bg-gray-100 transition-colors cursor-pointer relative">
                        <input
                            type="file"
                            multiple
                            accept="image/*"
                            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                            onChange={handleImageChange}
                        />
                        <div className="flex flex-col items-center justify-center text-gray-500">
                            <Plus size={32} className="mb-2 text-blue-500" />
                            <p className="font-medium">
                                {isEditMode ? 'Ajouter de nouvelles photos' : 'Cliquez ou glissez vos images ici'}
                            </p>
                            <p className="text-sm text-gray-400">Jusqu'à 8 photos (JPG, PNG)</p>
                        </div>
                    </div>

                    {/* New Image Previews */}
                    {images.length > 0 && (
                        <div className="mt-4">
                            {isEditMode && <p className="text-sm text-gray-500 mb-2">Nouvelles photos à ajouter :</p>}
                            <div className="grid grid-cols-4 gap-4">
                                {images.map((img, idx) => (
                                    <div key={idx} className="relative group aspect-square rounded overflow-hidden border border-blue-200">
                                        <img
                                            src={URL.createObjectURL(img)}
                                            alt="Preview"
                                            className="w-full h-full object-cover"
                                        />
                                        <button
                                            type="button"
                                            onClick={() => removeImage(idx)}
                                            className="absolute top-1 right-1 bg-white rounded-full p-1 shadow hover:text-red-600"
                                        >
                                            <Trash size={14} />
                                        </button>
                                        {isEditMode && (
                                            <div className="absolute bottom-0 left-0 right-0 bg-blue-600 text-white text-xs text-center py-0.5">
                                                Nouvelle
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}
                </div>

                {/* Promotions Section */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-bold text-orange-600 flex items-center gap-2">
                            <span className="text-xl">🏷️</span> Promotion & Offre Spéciale
                        </h2>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Prix Promotionnel ($)</label>
                            <input
                                type="number"
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-orange-500 outline-none"
                                placeholder="ex: 15"
                                value={product.discount_price || ''}
                                onChange={e => setProduct({ ...product, discount_price: e.target.value })}
                            />
                            <p className="text-xs text-gray-500 mt-1">Laisser vide pour aucune promo.</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Date de début</label>
                            <input
                                type="datetime-local"
                                className="w-full border p-2 rounded"
                                value={product.discount_start_date || ''}
                                onChange={e => setProduct({ ...product, discount_start_date: e.target.value })}
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Date de fin</label>
                            <input
                                type="datetime-local"
                                className="w-full border p-2 rounded"
                                value={product.discount_end_date || ''}
                                onChange={e => setProduct({ ...product, discount_end_date: e.target.value })}
                            />
                        </div>
                    </div>
                </div>

                {/* B2B Pricing Section */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-bold text-blue-900">Prix Dégressifs (B2B)</h2>
                        <button type="button" onClick={addTier} className="text-blue-600 text-sm font-medium hover:underline flex items-center gap-1">
                            <Plus size={16} /> Ajouter un palier
                        </button>
                    </div>

                    <div className="overflow-x-auto">
                        <table className="w-full text-left bg-blue-50/50 rounded-lg overflow-hidden">
                            <thead className="bg-blue-100 text-blue-800">
                                <tr>
                                    <th className="p-3 text-sm">Qté Min</th>
                                    <th className="p-3 text-sm">Qté Max</th>
                                    <th className="p-3 text-sm">Prix Unitaire ($)</th>
                                    <th className="p-3 text-sm w-10"></th>
                                </tr>
                            </thead>
                            <tbody>
                                {b2bPricing.map((tier, index) => (
                                    <tr key={index} className="border-b border-blue-100 last:border-0">
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-20 border p-1 rounded"
                                                value={tier.min}
                                                onChange={e => updateTier(index, 'min', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-20 border p-1 rounded"
                                                value={tier.max}
                                                placeholder="∞"
                                                onChange={e => updateTier(index, 'max', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-24 border p-1 rounded font-bold text-gray-900"
                                                value={tier.price}
                                                placeholder="0.00"
                                                onChange={e => updateTier(index, 'price', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3 text-center">
                                            {index > 0 && (
                                                <button
                                                    type="button"
                                                    onClick={() => removeTier(index)}
                                                    className="text-red-400 hover:text-red-600"
                                                >
                                                    <Trash size={16} />
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        <p className="text-xs text-gray-500 mt-2 italic">
                            * Le prix affiché aux clients dépendra de la quantité ajoutée au panier.
                        </p>
                    </div>
                </div>

                {/* Action Buttons */}
                <div className="flex justify-end gap-3">
                    <button
                        type="button"
                        onClick={() => navigate('/products')}
                        className="px-6 py-2 border rounded text-gray-600 hover:bg-gray-50"
                    >
                        Annuler
                    </button>
                    <button
                        type="submit"
                        disabled={saving}
                        className="px-6 py-2 bg-blue-600 text-white rounded font-bold hover:bg-blue-700 shadow-md flex items-center gap-2 disabled:opacity-50"
                    >
                        {saving ? (
                            <>
                                <Loader2 size={16} className="animate-spin" />
                                {isEditMode ? 'Sauvegarde...' : 'Publication...'}
                            </>
                        ) : (
                            <>
                                <Save size={16} />
                                {isEditMode ? 'Enregistrer les modifications' : 'Publier le produit'}
                            </>
                        )}
                    </button>
                </div>
            </form>
        </div>
    );
}
