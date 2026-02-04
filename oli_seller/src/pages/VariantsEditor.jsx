import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Plus, Trash, Package, Save, RefreshCw } from 'lucide-react';
import { sellerAPI } from '../services/api';

export default function VariantsEditor() {
    const { productId } = useParams();
    const navigate = useNavigate();

    const [variants, setVariants] = useState([]);
    const [suggestions, setSuggestions] = useState({ types: [] });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(null);

    // Pour le formulaire d'ajout
    const [newVariant, setNewVariant] = useState({
        variant_type: '',
        variant_value: '',
        sku: '',
        price_adjustment: 0,
        stock_quantity: 0
    });

    useEffect(() => {
        loadData();
    }, [productId]);

    const loadData = async () => {
        try {
            setLoading(true);
            const [variantsData, suggestionsData] = await Promise.all([
                sellerAPI.getVariants(productId),
                sellerAPI.getVariantSuggestions()
            ]);
            setVariants(variantsData);
            setSuggestions(suggestionsData);
        } catch (err) {
            console.error('Erreur chargement variantes:', err);
            setError('Erreur lors du chargement des variantes');
        } finally {
            setLoading(false);
        }
    };

    const handleAddVariant = async () => {
        if (!newVariant.variant_type || !newVariant.variant_value) {
            alert('Type et valeur de variante requis');
            return;
        }

        try {
            setSaving(true);
            const result = await sellerAPI.addVariant(productId, newVariant);
            setVariants([...variants, result]);
            setNewVariant({
                variant_type: '',
                variant_value: '',
                sku: '',
                price_adjustment: 0,
                stock_quantity: 0
            });
        } catch (err) {
            console.error('Erreur ajout variante:', err);
            alert(err.response?.data?.error || 'Erreur lors de l\'ajout');
        } finally {
            setSaving(false);
        }
    };

    const handleDeleteVariant = async (variantId) => {
        if (!confirm('Supprimer cette variante ?')) return;

        try {
            await sellerAPI.deleteVariant(variantId);
            setVariants(variants.filter(v => v.id !== variantId));
        } catch (err) {
            console.error('Erreur suppression:', err);
            alert('Erreur lors de la suppression');
        }
    };

    const handleUpdateVariant = async (variantId, field, value) => {
        try {
            await sellerAPI.updateVariant(variantId, { [field]: value });
            setVariants(variants.map(v =>
                v.id === variantId ? { ...v, [field]: value } : v
            ));
        } catch (err) {
            console.error('Erreur mise à jour:', err);
        }
    };

    const groupVariantsByType = () => {
        const grouped = {};
        variants.forEach(v => {
            if (!grouped[v.variant_type]) {
                grouped[v.variant_type] = [];
            }
            grouped[v.variant_type].push(v);
        });
        return grouped;
    };

    const getTypeLabel = (type) => {
        const typeInfo = suggestions.types?.find(t => t.value === type);
        return typeInfo?.label || type;
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-screen">
                <RefreshCw className="animate-spin text-blue-600" size={32} />
            </div>
        );
    }

    const groupedVariants = groupVariantsByType();

    return (
        <div className="p-8 max-w-5xl mx-auto">
            <button
                onClick={() => navigate('/products')}
                className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900"
            >
                <ArrowLeft size={16} /> Retour aux produits
            </button>

            <div className="flex justify-between items-start mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Variantes du Produit</h1>
                    <p className="text-gray-500">Gérez les tailles, couleurs et autres options</p>
                </div>
                <span className="text-sm text-gray-400">Produit #{productId}</span>
            </div>

            {error && (
                <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded-lg mb-6">
                    {error}
                </div>
            )}

            {/* Formulaire d'ajout de variante */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <Plus size={20} className="text-blue-600" />
                    Ajouter une variante
                </h2>

                <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
                    {/* Type de variante */}
                    <div className="md:col-span-2">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
                        <select
                            className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
                            value={newVariant.variant_type}
                            onChange={(e) => setNewVariant({ ...newVariant, variant_type: e.target.value })}
                        >
                            <option value="">Sélectionner...</option>
                            {suggestions.types?.map(type => (
                                <option key={type.value} value={type.value}>
                                    {type.label}
                                </option>
                            ))}
                            <option value="custom">Autre (personnalisé)</option>
                        </select>
                    </div>

                    {/* Valeur */}
                    <div className="md:col-span-2">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Valeur</label>
                        <input
                            type="text"
                            className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="ex: XL, Rouge, 128GB..."
                            value={newVariant.variant_value}
                            onChange={(e) => setNewVariant({ ...newVariant, variant_value: e.target.value })}
                        />
                        {newVariant.variant_type && suggestions.types?.find(t => t.value === newVariant.variant_type) && (
                            <div className="flex flex-wrap gap-1 mt-2">
                                {suggestions.types.find(t => t.value === newVariant.variant_type)?.examples?.map(ex => (
                                    <button
                                        key={ex}
                                        type="button"
                                        onClick={() => setNewVariant({ ...newVariant, variant_value: ex })}
                                        className="px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded hover:bg-gray-200"
                                    >
                                        {ex}
                                    </button>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* SKU */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">SKU</label>
                        <input
                            type="text"
                            className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="Optionnel"
                            value={newVariant.sku}
                            onChange={(e) => setNewVariant({ ...newVariant, sku: e.target.value })}
                        />
                    </div>

                    {/* Prix ajustement */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Prix +/-</label>
                        <input
                            type="number"
                            step="0.01"
                            className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="0"
                            value={newVariant.price_adjustment}
                            onChange={(e) => setNewVariant({ ...newVariant, price_adjustment: parseFloat(e.target.value) || 0 })}
                        />
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-6 gap-4 mt-4">
                    {/* Stock */}
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Stock</label>
                        <input
                            type="number"
                            min="0"
                            className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="0"
                            value={newVariant.stock_quantity}
                            onChange={(e) => setNewVariant({ ...newVariant, stock_quantity: parseInt(e.target.value) || 0 })}
                        />
                    </div>

                    {/* Bouton ajouter */}
                    <div className="md:col-span-5 flex items-end">
                        <button
                            onClick={handleAddVariant}
                            disabled={saving}
                            className="flex items-center gap-2 px-6 py-2.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                            {saving ? (
                                <RefreshCw className="animate-spin" size={18} />
                            ) : (
                                <Plus size={18} />
                            )}
                            Ajouter cette variante
                        </button>
                    </div>
                </div>
            </div>

            {/* Liste des variantes groupées par type */}
            {Object.keys(groupedVariants).length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center">
                    <Package size={48} className="mx-auto mb-4 text-gray-300" />
                    <h3 className="text-lg font-medium text-gray-600 mb-2">Aucune variante</h3>
                    <p className="text-gray-400">
                        Ajoutez des variantes comme la taille ou la couleur pour ce produit
                    </p>
                </div>
            ) : (
                <div className="space-y-6">
                    {Object.entries(groupedVariants).map(([type, typeVariants]) => (
                        <div key={type} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                            <div className="bg-gray-50 px-6 py-3 border-b border-gray-100">
                                <h3 className="font-semibold text-gray-900">
                                    {getTypeLabel(type)}
                                    <span className="ml-2 text-sm font-normal text-gray-500">
                                        ({typeVariants.length} option{typeVariants.length > 1 ? 's' : ''})
                                    </span>
                                </h3>
                            </div>

                            <table className="w-full">
                                <thead className="bg-gray-50 text-xs uppercase text-gray-500">
                                    <tr>
                                        <th className="text-left p-4">Valeur</th>
                                        <th className="text-left p-4">SKU</th>
                                        <th className="text-center p-4">Prix +/-</th>
                                        <th className="text-center p-4">Stock</th>
                                        <th className="text-center p-4">Actif</th>
                                        <th className="text-center p-4 w-16"></th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-100">
                                    {typeVariants.map((variant) => (
                                        <tr key={variant.id} className="hover:bg-gray-50">
                                            <td className="p-4 font-medium text-gray-900">
                                                {variant.variant_value}
                                            </td>
                                            <td className="p-4 text-gray-500 text-sm">
                                                {variant.sku || '-'}
                                            </td>
                                            <td className="p-4 text-center">
                                                <input
                                                    type="number"
                                                    step="0.01"
                                                    className="w-20 border border-gray-200 rounded p-1 text-center text-sm"
                                                    value={variant.price_adjustment}
                                                    onChange={(e) => handleUpdateVariant(
                                                        variant.id,
                                                        'price_adjustment',
                                                        parseFloat(e.target.value) || 0
                                                    )}
                                                />
                                            </td>
                                            <td className="p-4 text-center">
                                                <input
                                                    type="number"
                                                    min="0"
                                                    className="w-20 border border-gray-200 rounded p-1 text-center text-sm"
                                                    value={variant.stock_quantity}
                                                    onChange={(e) => handleUpdateVariant(
                                                        variant.id,
                                                        'stock_quantity',
                                                        parseInt(e.target.value) || 0
                                                    )}
                                                />
                                            </td>
                                            <td className="p-4 text-center">
                                                <button
                                                    onClick={() => handleUpdateVariant(variant.id, 'is_active', !variant.is_active)}
                                                    className={`w-8 h-8 rounded-full transition-colors ${variant.is_active
                                                            ? 'bg-green-100 text-green-600'
                                                            : 'bg-gray-100 text-gray-400'
                                                        }`}
                                                >
                                                    {variant.is_active ? '✓' : '○'}
                                                </button>
                                            </td>
                                            <td className="p-4 text-center">
                                                <button
                                                    onClick={() => handleDeleteVariant(variant.id)}
                                                    className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                                >
                                                    <Trash size={16} />
                                                </button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    ))}
                </div>
            )}

            {/* Info card */}
            <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h3 className="font-medium text-blue-900 mb-2">💡 À propos des variantes</h3>
                <ul className="text-sm text-blue-800 space-y-1">
                    <li>• <strong>Prix +/-</strong> : Montant à ajouter ou soustraire du prix de base</li>
                    <li>• <strong>Stock</strong> : Quantité disponible pour cette variante spécifique</li>
                    <li>• Les variantes désactivées ne seront pas proposées aux acheteurs</li>
                </ul>
            </div>
        </div>
    );
}
