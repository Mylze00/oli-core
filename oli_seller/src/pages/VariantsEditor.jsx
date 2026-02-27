import { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, Plus, Trash2, RefreshCw, Zap,
    CheckCircle, Circle, Save
} from 'lucide-react';
import { sellerAPI } from '../services/api';

// ── Constantes ──────────────────────────────────────────────

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

const PRESET_SIZES = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL',
    '36', '37', '38', '39', '40', '41', '42', '43', '44', '45'
];

// ── Composant principal ─────────────────────────────────────

export default function VariantsEditor() {
    const { productId } = useParams();
    const navigate = useNavigate();

    // Variantes sauvegardées (viennent du backend)
    const [variants, setVariants] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(null);
    const [successMsg, setSuccessMsg] = useState(null);

    // Sélections pour la génération de variantes
    const [selectedColors, setSelectedColors] = useState([]);
    const [selectedSizes, setSelectedSizes] = useState([]);
    const [customColor, setCustomColor] = useState('');
    const [customSize, setCustomSize] = useState('');

    // Stock et prix par défaut pour la génération
    const [defaultStock, setDefaultStock] = useState(10);
    const [defaultPriceAdj, setDefaultPriceAdj] = useState(0);

    // Ajout de variante simple (type personnalisé hors couleur/taille)
    const [customVariantType, setCustomVariantType] = useState('');
    const [customVariantValue, setCustomVariantValue] = useState('');

    // ── Chargement ──────────────────────────────────────────

    useEffect(() => { loadVariants(); }, [productId]);

    const loadVariants = async () => {
        try {
            setLoading(true);
            const data = await sellerAPI.getVariants(productId);
            setVariants(data);
        } catch (err) {
            setError('Impossible de charger les variantes.');
        } finally {
            setLoading(false);
        }
    };

    // ── Toggles sélection ───────────────────────────────────

    const toggleColor = (name) =>
        setSelectedColors(p => p.includes(name) ? p.filter(c => c !== name) : [...p, name]);

    const toggleSize = (s) =>
        setSelectedSizes(p => p.includes(s) ? p.filter(x => x !== s) : [...p, s]);

    const addCustomColor = () => {
        const v = customColor.trim();
        if (v && !selectedColors.includes(v)) {
            setSelectedColors(p => [...p, v]);
        }
        setCustomColor('');
    };

    const addCustomSize = () => {
        const v = customSize.trim();
        if (v && !selectedSizes.includes(v)) {
            setSelectedSizes(p => [...p, v]);
        }
        setCustomSize('');
    };

    // ── Génération automatique de variantes ─────────────────

    const generateVariants = async () => {
        const toAdd = [];

        // Couleurs
        for (const color of selectedColors) {
            const alreadyExists = variants.some(
                v => v.variant_type === 'color' && v.variant_value === color
            );
            if (!alreadyExists) {
                toAdd.push({
                    variant_type: 'color',
                    variant_value: color,
                    stock_quantity: defaultStock,
                    price_adjustment: defaultPriceAdj,
                    sku: '',
                });
            }
        }

        // Tailles
        for (const size of selectedSizes) {
            const alreadyExists = variants.some(
                v => v.variant_type === 'size' && v.variant_value === size
            );
            if (!alreadyExists) {
                toAdd.push({
                    variant_type: 'size',
                    variant_value: size,
                    stock_quantity: defaultStock,
                    price_adjustment: defaultPriceAdj,
                    sku: '',
                });
            }
        }

        if (toAdd.length === 0) {
            setSuccessMsg('Toutes ces variantes existent déjà.');
            setTimeout(() => setSuccessMsg(null), 3000);
            return;
        }

        try {
            setSaving(true);
            const result = await sellerAPI.addVariantsBulk(productId, toAdd);
            setVariants(p => [...p, ...result]);
            setSelectedColors([]);
            setSelectedSizes([]);
            showSuccess(`${toAdd.length} variante(s) ajoutée(s) ✓`);
        } catch (err) {
            alert('Erreur : ' + (err.response?.data?.error || err.message));
        } finally {
            setSaving(false);
        }
    };

    // ── Suppression ─────────────────────────────────────────

    const deleteVariant = async (id) => {
        if (!confirm('Supprimer cette variante ?')) return;
        try {
            await sellerAPI.deleteVariant(id);
            setVariants(p => p.filter(v => v.id !== id));
        } catch {
            alert('Erreur lors de la suppression.');
        }
    };

    // ── Mise à jour inline ───────────────────────────────────

    const updateVariant = useCallback(async (id, field, value) => {
        try {
            await sellerAPI.updateVariant(id, { [field]: value });
            setVariants(p => p.map(v => v.id === id ? { ...v, [field]: value } : v));
        } catch {
            /* silencieux — en cas d'erreur le champ revient à l'ancienne valeur */
        }
    }, []);

    // ── Ajout variante personnalisée ─────────────────────────

    const addCustomVariant = async () => {
        if (!customVariantType.trim() || !customVariantValue.trim()) {
            alert('Type et valeur requis.');
            return;
        }
        try {
            setSaving(true);
            const result = await sellerAPI.addVariant(productId, {
                variant_type: customVariantType.trim().toLowerCase(),
                variant_value: customVariantValue.trim(),
                stock_quantity: defaultStock,
                price_adjustment: defaultPriceAdj,
                sku: '',
            });
            setVariants(p => [...p, result]);
            setCustomVariantType('');
            setCustomVariantValue('');
            showSuccess('Variante ajoutée ✓');
        } catch (err) {
            alert('Erreur : ' + (err.response?.data?.error || err.message));
        } finally {
            setSaving(false);
        }
    };

    const showSuccess = (msg) => {
        setSuccessMsg(msg);
        setTimeout(() => setSuccessMsg(null), 3000);
    };

    // ── Groupes pour l'affichage ─────────────────────────────

    const grouped = variants.reduce((acc, v) => {
        (acc[v.variant_type] = acc[v.variant_type] || []).push(v);
        return acc;
    }, {});

    const typeLabels = { color: '🎨 Couleurs', size: '📐 Tailles' };

    // ── Rendu ────────────────────────────────────────────────

    if (loading) return (
        <div className="flex items-center justify-center h-screen">
            <RefreshCw className="animate-spin text-blue-600" size={32} />
        </div>
    );

    return (
        <div className="p-6 max-w-5xl mx-auto">

            {/* En-tête */}
            <button onClick={() => navigate('/products')}
                className="text-gray-500 flex items-center gap-2 mb-5 hover:text-gray-900 transition-colors">
                <ArrowLeft size={16} /> Retour aux produits
            </button>

            <div className="flex justify-between items-start mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Variantes du Produit</h1>
                    <p className="text-gray-500 text-sm">Gérez tailles, couleurs et autres options</p>
                </div>
                <span className="text-sm text-gray-400 bg-gray-100 px-3 py-1 rounded-full">
                    Produit #{productId}
                </span>
            </div>

            {/* Messages */}
            {error && (
                <div className="mb-4 bg-red-50 border border-red-200 text-red-700 p-3 rounded-lg text-sm">
                    {error}
                </div>
            )}
            {successMsg && (
                <div className="mb-4 bg-green-50 border border-green-200 text-green-700 p-3 rounded-lg text-sm flex items-center gap-2">
                    <CheckCircle size={16} /> {successMsg}
                </div>
            )}

            {/* ══ Section 1 : Sélecteur visuel ══════════════════════ */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-5">
                <h2 className="font-bold text-gray-900 mb-5 flex items-center gap-2">
                    <Zap size={18} className="text-amber-500" />
                    Ajouter des variantes rapidement
                </h2>

                {/* Paramètres par défaut */}
                <div className="flex gap-4 mb-5 p-3 bg-gray-50 rounded-lg">
                    <div>
                        <label className="block text-xs text-gray-500 mb-1">Stock par défaut</label>
                        <input type="number" min="0" value={defaultStock}
                            onChange={e => setDefaultStock(parseInt(e.target.value) || 0)}
                            className="w-24 border border-gray-200 rounded-lg px-2 py-1.5 text-sm focus:ring-2 focus:ring-amber-400 outline-none" />
                    </div>
                    <div>
                        <label className="block text-xs text-gray-500 mb-1">Ajustement prix ($)</label>
                        <input type="number" step="0.01" value={defaultPriceAdj}
                            onChange={e => setDefaultPriceAdj(parseFloat(e.target.value) || 0)}
                            className="w-28 border border-gray-200 rounded-lg px-2 py-1.5 text-sm focus:ring-2 focus:ring-amber-400 outline-none" />
                    </div>
                </div>

                {/* Couleurs */}
                <div className="mb-5">
                    <label className="text-sm font-semibold text-gray-700 mb-2 flex items-center gap-1.5">
                        🎨 Couleurs disponibles
                    </label>
                    <div className="flex flex-wrap gap-2 mb-2">
                        {PRESET_COLORS.map(c => {
                            const sel = selectedColors.includes(c.name);
                            return (
                                <button key={c.name} type="button" onClick={() => toggleColor(c.name)}
                                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-sm font-medium transition-all ${sel
                                            ? 'border-amber-400 bg-amber-50 text-amber-800 shadow-sm'
                                            : 'border-gray-200 text-gray-600 hover:border-gray-300 hover:bg-gray-50'
                                        }`}>
                                    <span className="w-3.5 h-3.5 rounded-full border border-gray-300 flex-shrink-0"
                                        style={{ backgroundColor: c.hex }} />
                                    {c.name}
                                    {sel && <CheckCircle size={12} className="text-amber-500" />}
                                </button>
                            );
                        })}
                    </div>
                    {/* Couleurs personnalisées sélectionnées */}
                    {selectedColors.filter(c => !PRESET_COLORS.find(p => p.name === c)).map(c => (
                        <span key={c}
                            className="inline-flex items-center gap-1 mr-2 mb-2 px-3 py-1.5 rounded-full border border-amber-400 bg-amber-50 text-amber-800 text-sm font-medium">
                            {c}
                            <button onClick={() => setSelectedColors(p => p.filter(x => x !== c))}
                                className="text-amber-500 hover:text-red-500 ml-0.5">×</button>
                        </span>
                    ))}
                    <div className="flex gap-2 mt-2">
                        <input type="text" placeholder="Autre couleur..." value={customColor}
                            onChange={e => setCustomColor(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && addCustomColor()}
                            className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-amber-400 outline-none" />
                        <button onClick={addCustomColor}
                            className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm font-medium transition-colors">
                            + Ajouter
                        </button>
                    </div>
                </div>

                <hr className="border-gray-100 mb-5" />

                {/* Tailles */}
                <div className="mb-5">
                    <label className="text-sm font-semibold text-gray-700 mb-2 flex items-center gap-1.5">
                        📐 Tailles disponibles
                    </label>
                    <div className="flex flex-wrap gap-2 mb-2">
                        {PRESET_SIZES.map(s => {
                            const sel = selectedSizes.includes(s);
                            return (
                                <button key={s} type="button" onClick={() => toggleSize(s)}
                                    className={`px-3 py-1.5 rounded-full border text-sm font-medium transition-all ${sel
                                            ? 'border-amber-400 bg-amber-50 text-amber-800 shadow-sm'
                                            : 'border-gray-200 text-gray-600 hover:border-gray-300 hover:bg-gray-50'
                                        }`}>
                                    {s}
                                </button>
                            );
                        })}
                    </div>
                    {/* Tailles personnalisées sélectionnées */}
                    {selectedSizes.filter(s => !PRESET_SIZES.includes(s)).map(s => (
                        <span key={s}
                            className="inline-flex items-center gap-1 mr-2 mb-2 px-3 py-1.5 rounded-full border border-amber-400 bg-amber-50 text-amber-800 text-sm font-medium">
                            {s}
                            <button onClick={() => setSelectedSizes(p => p.filter(x => x !== s))}
                                className="text-amber-500 hover:text-red-500 ml-0.5">×</button>
                        </span>
                    ))}
                    <div className="flex gap-2 mt-2">
                        <input type="text" placeholder="Autre taille (ex: 46, Unique, 128Go...)" value={customSize}
                            onChange={e => setCustomSize(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && addCustomSize()}
                            className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-amber-400 outline-none" />
                        <button onClick={addCustomSize}
                            className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm font-medium transition-colors">
                            + Ajouter
                        </button>
                    </div>
                </div>

                {/* Bouton générer */}
                <div className="flex items-center justify-between pt-3 border-t border-gray-100">
                    <p className="text-sm text-gray-500">
                        {selectedColors.length + selectedSizes.length === 0
                            ? 'Sélectionnez des couleurs ou des tailles ci-dessus'
                            : `${selectedColors.length} couleur(s), ${selectedSizes.length} taille(s) sélectionnée(s)`
                        }
                    </p>
                    <button
                        onClick={generateVariants}
                        disabled={saving || (selectedColors.length === 0 && selectedSizes.length === 0)}
                        className="flex items-center gap-2 px-5 py-2.5 bg-amber-500 hover:bg-amber-600 text-white font-semibold rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
                        {saving ? <RefreshCw className="animate-spin" size={16} /> : <Plus size={16} />}
                        Générer les variantes
                    </button>
                </div>
            </div>

            {/* ══ Section 2 : Variante personnalisée ════════════════ */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5 mb-5">
                <h2 className="font-semibold text-gray-700 mb-3 text-sm uppercase tracking-wide">
                    Autre type de variante (stockage, capacité, etc.)
                </h2>
                <div className="flex gap-3 items-end">
                    <div className="flex-1">
                        <label className="text-xs text-gray-500 mb-1 block">Type</label>
                        <input type="text" placeholder="ex: Stockage, Matière..." value={customVariantType}
                            onChange={e => setCustomVariantType(e.target.value)}
                            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
                    </div>
                    <div className="flex-1">
                        <label className="text-xs text-gray-500 mb-1 block">Valeur</label>
                        <input type="text" placeholder="ex: 128Go, Cuir..." value={customVariantValue}
                            onChange={e => setCustomVariantValue(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && addCustomVariant()}
                            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
                    </div>
                    <button onClick={addCustomVariant} disabled={saving}
                        className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-50 flex items-center gap-1.5">
                        <Plus size={15} /> Ajouter
                    </button>
                </div>
            </div>

            {/* ══ Section 3 : Tableau des variantes ════════════════ */}
            {Object.keys(grouped).length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center">
                    <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Circle size={32} className="text-gray-300" />
                    </div>
                    <h3 className="text-base font-semibold text-gray-500 mb-1">Aucune variante</h3>
                    <p className="text-sm text-gray-400">Sélectionnez des couleurs ou tailles ci-dessus pour commencer</p>
                </div>
            ) : (
                <div className="space-y-4">
                    {Object.entries(grouped).map(([type, tvariants]) => (
                        <div key={type} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                            {/* En-tête du groupe */}
                            <div className="flex items-center justify-between px-5 py-3 bg-gray-50 border-b border-gray-100">
                                <h3 className="font-semibold text-gray-800 text-sm">
                                    {typeLabels[type] || `📦 ${type.charAt(0).toUpperCase() + type.slice(1)}`}
                                    <span className="ml-2 font-normal text-gray-400">
                                        {tvariants.length} option{tvariants.length > 1 ? 's' : ''}
                                    </span>
                                </h3>
                            </div>

                            {/* Tableau */}
                            <table className="w-full">
                                <thead>
                                    <tr className="text-xs text-gray-400 uppercase border-b border-gray-100">
                                        <th className="text-left px-5 py-2.5 font-medium">Valeur</th>
                                        <th className="text-center px-4 py-2.5 font-medium">Stock</th>
                                        <th className="text-center px-4 py-2.5 font-medium">Prix +/- ($)</th>
                                        <th className="text-center px-4 py-2.5 font-medium">Actif</th>
                                        <th className="px-4 py-2.5 w-12" />
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-50">
                                    {tvariants.map(v => (
                                        <tr key={v.id} className="hover:bg-gray-50 transition-colors group">
                                            {/* Valeur avec point couleur si color */}
                                            <td className="px-5 py-3">
                                                <div className="flex items-center gap-2">
                                                    {type === 'color' && (
                                                        <span className="w-4 h-4 rounded-full border border-gray-200 flex-shrink-0"
                                                            style={{
                                                                backgroundColor:
                                                                    PRESET_COLORS.find(c => c.name === v.variant_value)?.hex || '#ccc'
                                                            }} />
                                                    )}
                                                    <span className="font-medium text-gray-800 text-sm">
                                                        {v.variant_value}
                                                    </span>
                                                </div>
                                            </td>

                                            {/* Stock — inline edit */}
                                            <td className="px-4 py-3 text-center">
                                                <input
                                                    type="number" min="0"
                                                    defaultValue={v.stock_quantity}
                                                    onBlur={e => updateVariant(v.id, 'stock_quantity', parseInt(e.target.value) || 0)}
                                                    className="w-20 border border-gray-200 rounded-lg px-2 py-1.5 text-sm text-center focus:ring-2 focus:ring-amber-400 outline-none"
                                                />
                                            </td>

                                            {/* Prix ajustement — inline edit */}
                                            <td className="px-4 py-3 text-center">
                                                <input
                                                    type="number" step="0.01"
                                                    defaultValue={v.price_adjustment}
                                                    onBlur={e => updateVariant(v.id, 'price_adjustment', parseFloat(e.target.value) || 0)}
                                                    className="w-24 border border-gray-200 rounded-lg px-2 py-1.5 text-sm text-center focus:ring-2 focus:ring-amber-400 outline-none"
                                                />
                                            </td>

                                            {/* Toggle actif */}
                                            <td className="px-4 py-3 text-center">
                                                <button
                                                    onClick={() => updateVariant(v.id, 'is_active', !v.is_active)}
                                                    className={`w-9 h-9 rounded-full transition-all flex items-center justify-center mx-auto ${v.is_active
                                                            ? 'bg-green-100 text-green-600 hover:bg-green-200'
                                                            : 'bg-gray-100 text-gray-400 hover:bg-gray-200'
                                                        }`}
                                                    title={v.is_active ? 'Désactiver' : 'Activer'}>
                                                    {v.is_active
                                                        ? <CheckCircle size={18} />
                                                        : <Circle size={18} />
                                                    }
                                                </button>
                                            </td>

                                            {/* Supprimer */}
                                            <td className="px-4 py-3 text-center">
                                                <button
                                                    onClick={() => deleteVariant(v.id)}
                                                    className="p-2 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors opacity-0 group-hover:opacity-100">
                                                    <Trash2 size={15} />
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
            <div className="mt-5 p-4 bg-amber-50 border border-amber-100 rounded-xl text-sm text-amber-800">
                <p className="font-semibold mb-1">💡 Conseils</p>
                <ul className="space-y-0.5 text-amber-700">
                    <li>• Le stock et le prix s'enregistrent automatiquement quand vous quittez le champ</li>
                    <li>• <strong>Prix +/-</strong> : montant ajouté ou soustrait du prix de base</li>
                    <li>• Les variantes désactivées ne sont pas proposées aux acheteurs</li>
                </ul>
            </div>
        </div>
    );
}
