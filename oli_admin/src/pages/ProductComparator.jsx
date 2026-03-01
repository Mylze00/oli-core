import { useState, useEffect, useCallback } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    CheckBadgeIcon, ArrowPathIcon, TagIcon, UserIcon,
    PencilSquareIcon, TruckIcon, SwatchIcon, ArrowRightIcon,
    PlusIcon, TrashIcon, InboxIcon, StarIcon, EyeSlashIcon, XMarkIcon,
} from '@heroicons/react/24/outline';
import { CheckBadgeIcon as CheckBadgeSolid } from '@heroicons/react/24/solid';

// ─── Constantes variantes ─────────────────────────────────────────────────────
const COLORS = [
    { name: 'Rouge', hex: '#ef4444' }, { name: 'Bleu', hex: '#3b82f6' },
    { name: 'Vert', hex: '#22c55e' }, { name: 'Jaune', hex: '#eab308' },
    { name: 'Orange', hex: '#f97316' }, { name: 'Violet', hex: '#a855f7' },
    { name: 'Rose', hex: '#ec4899' }, { name: 'Noir', hex: '#1f2937' },
    { name: 'Blanc', hex: '#f3f4f6' }, { name: 'Gris', hex: '#9ca3af' },
    { name: 'Marron', hex: '#92400e' }, { name: 'Beige', hex: '#d4a47a' },
    { name: 'Gold', hex: '#f59e0b' }, { name: 'Argent', hex: '#cbd5e1' },
];
const SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];
const MATERIALS = ['Coton', 'Polyester', 'Cuir', 'Soie', 'Lin', 'Laine', 'Nylon', 'Velours', 'Denim', 'Plastique', 'Métal', 'Bois', 'Céramique', 'Verre', 'Caoutchouc'];

// Icônes emoji pour les modes de livraison (matchent les IDs en DB)
const DELIVERY_ICONS = {
    oli_standard: '📦',
    oli_express: '⚡',
    hand_delivery: '🤝',
    free: '🎁',
    pick_go: '🏪',
    moto: '🏍️',
    maritime: '🚢',
};

// ─── Barre prix ───────────────────────────────────────────────────────────────
function PriceBar({ value, min, max, median, avg }) {
    const range = max - min || 1;
    const pct = Math.min(100, Math.max(0, ((value - min) / range) * 100));
    const medPct = Math.min(100, Math.max(0, ((median - min) / range) * 100));
    const avgPct = Math.min(100, Math.max(0, ((avg - min) / range) * 100));
    return (
        <div>
            <div className="relative h-3 bg-gray-100 rounded-full mb-1">
                <div className="h-full rounded-full bg-blue-400 transition-all" style={{ width: `${pct}%` }} />
                <div className="absolute top-0 h-full w-0.5 bg-amber-500" style={{ left: `${medPct}%` }} />
                <div className="absolute top-0 h-full w-0.5 bg-green-500" style={{ left: `${avgPct}%` }} />
            </div>
            <div className="flex justify-between text-xs text-gray-400">
                <span>${parseFloat(min || 0).toFixed(2)}</span>
                <span className="font-bold text-blue-600">${parseFloat(value || 0).toFixed(2)}</span>
                <span>${parseFloat(max || 0).toFixed(2)}</span>
            </div>
        </div>
    );
}

// ─── Carte file ───────────────────────────────────────────────────────────────
function QueueCard({ product, isActive, onClick }) {
    const img = product.images?.[0] ? getImageUrl(product.images[0]) : null;
    return (
        <button onClick={onClick}
            className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-xl transition text-left border
                ${isActive ? 'bg-blue-50 border-blue-200' : 'hover:bg-gray-50 border-transparent'}`}>
            <div className="w-9 h-9 rounded-lg bg-gray-100 flex-shrink-0 overflow-hidden">
                {img && <img src={img} alt="" className="w-full h-full object-cover"
                    onError={e => { e.target.onerror = null; e.target.style.display = 'none'; }} />}
            </div>
            <div className="flex-1 min-w-0">
                <p className="text-xs font-medium text-gray-800 truncate">{product.name}</p>
                <p className="text-xs text-gray-400 flex items-center gap-1"><TagIcon className="h-3 w-3" />{product.category}</p>
            </div>
            <span className="text-xs font-bold text-blue-600 flex-shrink-0">${parseFloat(product.price || 0).toFixed(2)}</span>
        </button>
    );
}

// ─── Onglets ──────────────────────────────────────────────────────────────────
const TABS = [
    { id: 'infos', label: 'Infos', icon: PencilSquareIcon },
    { id: 'price', label: 'Prix', icon: TagIcon },
    { id: 'delivery', label: 'Livraison', icon: TruckIcon },
    { id: 'variants', label: 'Variantes', icon: SwatchIcon },
    { id: 'brand', label: 'Badge Brand', icon: StarIcon },
];

// ─── Onglet Variantes ─────────────────────────────────────────────────────────
function VariantsTab({ activeId, variants, setVariants }) {
    const [loading, setLoading] = useState(false);

    const toggleVariant = async (type, value) => {
        const exists = variants.find(v => v.variant_type === type && v.variant_value === value);
        if (exists) {
            try {
                await api.delete(`/admin/products/${activeId}/variants/${exists.id}`);
                setVariants(prev => prev.filter(v => v.id !== exists.id));
            } catch (e) { alert(e.response?.data?.error || e.message); }
        } else {
            setLoading(true);
            try {
                const { data } = await api.post(`/admin/products/${activeId}/variants`, { variant_type: type, variant_value: value, price_adjustment: 0, stock_quantity: 0 });
                setVariants(prev => [...prev, data.variant]);
            } catch (e) { alert(e.response?.data?.error || e.message); }
            finally { setLoading(false); }
        }
    };

    const isActive = (type, value) => variants.some(v => v.variant_type === type && v.variant_value === value);

    return (
        <div className="space-y-5">
            {loading && <div className="flex justify-center"><ArrowPathIcon className="h-5 w-5 animate-spin text-blue-400" /></div>}

            {/* Couleurs */}
            <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Couleurs</p>
                <div className="flex flex-wrap gap-2">
                    {COLORS.map(c => {
                        const active = isActive('color', c.name);
                        return (
                            <button key={c.name} onClick={() => toggleVariant('color', c.name)} title={c.name}
                                className={`relative w-8 h-8 rounded-full border-2 transition-transform hover:scale-110 ${active ? 'border-blue-500 scale-110 shadow-md' : 'border-gray-200'}`}
                                style={{ backgroundColor: c.hex }}>
                                {active && <span className="absolute inset-0 flex items-center justify-center text-white text-xs font-bold drop-shadow">✓</span>}
                            </button>
                        );
                    })}
                </div>
                {variants.filter(v => v.variant_type === 'color').length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-2">
                        {variants.filter(v => v.variant_type === 'color').map(v => (
                            <span key={v.id} className="text-xs bg-gray-100 px-2 py-0.5 rounded-full text-gray-600">{v.variant_value}</span>
                        ))}
                    </div>
                )}
            </div>

            {/* Tailles */}
            <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Tailles</p>
                <div className="flex flex-wrap gap-2">
                    {SIZES.map(s => {
                        const active = isActive('size', s);
                        return (
                            <button key={s} onClick={() => toggleVariant('size', s)}
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
                        const active = isActive('material', m);
                        return (
                            <button key={m} onClick={() => toggleVariant('material', m)}
                                className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition
                                    ${active ? 'bg-purple-600 text-white border-purple-600 shadow-sm' : 'text-gray-600 border-gray-200 hover:border-purple-300 hover:text-purple-600'}`}>
                                {m}
                            </button>
                        );
                    })}
                </div>
            </div>

            {variants.length === 0 && !loading && (
                <p className="text-xs text-gray-400 text-center py-2">Cliquez sur les éléments pour les ajouter</p>
            )}
        </div>
    );
}

// ── Fallback : 7 modes Oli si l'API ne répond pas ───────────────────────────
const FALLBACK_MODES = [
    { id: 'oli_standard', label: 'Livraison Standard', time_label: '10 jours', default_cost: 2.50, is_distance_based: false },
    { id: 'oli_express', label: 'Oli Express 24h', time_label: '24 heures', default_cost: 5.00, is_distance_based: false },
    { id: 'hand_delivery', label: 'Retrait en main propre', time_label: 'Sur rendez-vous', default_cost: 0, is_distance_based: false },
    { id: 'free', label: 'Livraison gratuite', time_label: '60 jours', default_cost: 0, is_distance_based: false },
    { id: 'pick_go', label: 'PickGo', time_label: '1-4 heures', default_cost: 1.00, is_distance_based: false },
    { id: 'moto', label: 'Livraison moto', time_label: 'Calculé/distance', default_cost: 0, is_distance_based: true },
    { id: 'maritime', label: 'Livraison maritime', time_label: '60 jours', default_cost: 15.00, is_distance_based: false },
];

// ─── Onglet Livraison ─────────────────────────────────────────────────────────
function DeliveryTab({ shipping, setShipping }) {
    const [modes, setModes] = useState(FALLBACK_MODES);

    useEffect(() => {
        api.get('/api/delivery-methods')
            .then(r => {
                const data = Array.isArray(r.data) && r.data.length > 0 ? r.data : FALLBACK_MODES;
                setModes(data);
            })
            .catch(() => { }); // garder le fallback en cas d'erreur
    }, []);

    const isEnabled = (id) => shipping.some(s => (s.id || s.methodId) === id);
    const getCost = (id) => { const s = shipping.find(s => (s.id || s.methodId) === id); return s?.cost ?? 0; };

    const toggle = (mode) => {
        if (isEnabled(mode.id)) {
            setShipping(prev => prev.filter(s => (s.id || s.methodId) !== mode.id));
        } else {
            setShipping(prev => [...prev, {
                methodId: mode.id, id: mode.id, label: mode.label,
                cost: parseFloat(mode.default_cost) || 0,
                time: mode.time_label || '',
            }]);
        }
    };
    const updateCost = (id, val) =>
        setShipping(prev => prev.map(s => (s.id || s.methodId) === id ? { ...s, cost: parseFloat(val) || 0 } : s));


    return (
        <div className="space-y-2">
            {modes.map(mode => {
                const enabled = isEnabled(mode.id);
                const icon = DELIVERY_ICONS[mode.id] || '📦';
                return (
                    <div key={mode.id} className={`rounded-xl border transition-colors ${enabled ? 'border-blue-200 bg-blue-50' : 'border-gray-200 bg-white'}`}>
                        <div className="flex items-center gap-3 p-3">
                            <button onClick={() => toggle(mode)}
                                className={`w-10 h-6 rounded-full transition-colors flex-shrink-0 ${enabled ? 'bg-blue-500' : 'bg-gray-200'}`}>
                                <div className={`w-4 h-4 bg-white rounded-full shadow m-1 transition-transform ${enabled ? 'translate-x-4' : 'translate-x-0'}`} />
                            </button>
                            <span className="text-xl flex-shrink-0">{icon}</span>
                            <div className="flex-1 min-w-0">
                                <p className={`text-sm font-semibold truncate ${enabled ? 'text-blue-800' : 'text-gray-700'}`}>{mode.label}</p>
                                <p className="text-xs text-gray-400">
                                    {mode.time_label}
                                    {mode.is_distance_based && <span className="ml-1 text-amber-500">· prix calculé/km</span>}
                                </p>
                            </div>
                            {enabled && !mode.is_distance_based && (
                                <div className="flex items-center gap-1 flex-shrink-0">
                                    <span className="text-xs text-gray-400">$</span>
                                    <input type="number" min="0" step="0.5"
                                        className="w-16 px-2 py-1 border border-blue-200 rounded-lg text-xs text-center focus:outline-none focus:ring-1 focus:ring-blue-400 bg-white"
                                        value={getCost(mode.id)}
                                        onChange={e => updateCost(mode.id, e.target.value)} />
                                </div>
                            )}
                            {enabled && mode.is_distance_based && (
                                <span className="text-xs text-amber-600 bg-amber-50 px-2 py-1 rounded-lg border border-amber-200 flex-shrink-0">Auto/km</span>
                            )}
                        </div>
                    </div>
                );
            })}
        </div>
    );
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
export default function ProductComparator() {
    const [queue, setQueue] = useState([]);
    const [queueIdx, setQueueIdx] = useState(0);
    const [totalUnverified, setTotal] = useState(0);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [activeTab, setActiveTab] = useState('infos');
    const [saving, setSaving] = useState(false);
    const [verifying, setVerifying] = useState(false);
    const [successId, setSuccessId] = useState(null);
    const [pageOffset, setPageOffset] = useState(0);
    const [variants, setVariants] = useState([]);
    const [variantsLoading, setVL] = useState(false);
    const [confirmDelete, setConfirmDelete] = useState(false);

    const [form, setForm] = useState({ name: '', description: '', price: '', brand_certified: false, brand_display_name: '' });
    const [shipping, setShipping] = useState([]);

    const active = queue[queueIdx] || null;
    const activeId = active?.id || null;
    const stats = active?.category_stats || null;
    const img = active?.images?.[0] ? getImageUrl(active.images[0]) : null;

    // ── Charger la file ───────────────────────────────────────────────────────
    const loadQueue = useCallback(async (offset = 0, startIdx = 0) => {
        setLoading(true); setError(null);
        try {
            const { data } = await api.get(`/admin/products/unverified?limit=10&offset=${offset}`);
            if (!data || data.error) throw new Error(data?.error || 'Erreur API');
            const products = data.products || [];
            setQueue(products);
            setTotal(data.total_unverified || 0);
            const idx = Math.min(startIdx, Math.max(0, products.length - 1));
            setQueueIdx(idx);
            if (products[idx]) applyProduct(products[idx]);
            else setForm({ name: '', description: '', price: '', brand_certified: false, brand_display_name: '' });
        } catch (e) { setError(e.response?.data?.error || e.message); }
        finally { setLoading(false); }
    }, []);

    const applyProduct = (p) => {
        if (!p) return;
        setForm({ name: p.name || '', description: p.description || '', price: p.price || '', brand_certified: p.brand_certified || false, brand_display_name: p.brand_display_name || '' });
        setShipping(p.shipping_options || []);
        setActiveTab('infos');
        setVariants([]);
        setConfirmDelete(false);
    };

    useEffect(() => { loadQueue(0, 0); }, [loadQueue]);
    useEffect(() => { if (queue[queueIdx]) applyProduct(queue[queueIdx]); }, [queueIdx, queue]);

    // Charger variantes
    useEffect(() => {
        if (activeTab !== 'variants' || !activeId) return;
        setVL(true);
        api.get(`/admin/products/${activeId}/variants`)
            .then(r => setVariants(r.data.variants || []))
            .catch(() => setVariants([]))
            .finally(() => setVL(false));
    }, [activeTab, activeId]);

    // ── Navigation ────────────────────────────────────────────────────────────
    const goToNext = useCallback((currentQueue, currentIdx, currentOffset) => {
        const nextIdx = currentIdx + 1;
        if (nextIdx < currentQueue.length) {
            setQueueIdx(nextIdx);
        } else {
            const newOffset = currentOffset + 10;
            setPageOffset(newOffset);
            loadQueue(newOffset, 0);
        }
    }, [loadQueue]);

    const removeFromQueue = (id) => {
        setQueue(prev => {
            const newQ = prev.filter(p => p.id !== id);
            const newIdx = Math.min(queueIdx, Math.max(0, newQ.length - 1));
            setQueueIdx(newIdx);
            if (newQ.length === 0) {
                const newOffset = pageOffset + 10;
                setPageOffset(newOffset);
                loadQueue(newOffset, 0);
            }
            return newQ;
        });
    };

    const skip = () => {
        const nextIdx = queueIdx + 1;
        if (nextIdx < queue.length) setQueueIdx(nextIdx);
        else { const no = pageOffset + 10; setPageOffset(no); loadQueue(no, 0); }
    };

    // ── Save ──────────────────────────────────────────────────────────────────
    const save = async () => {
        if (!activeId) return;
        setSaving(true);
        try {
            await api.patch(`/admin/products/${activeId}/quick-edit`, {
                name: form.name, description: form.description, price: form.price,
                shipping_options: shipping, brand_certified: form.brand_certified,
                brand_display_name: form.brand_display_name || null,
            });
        } catch (e) { alert('Erreur sauvegarde: ' + (e.response?.data?.error || e.message)); }
        finally { setSaving(false); }
    };

    // ── Verify ────────────────────────────────────────────────────────────────
    const verifyAndNext = async () => {
        if (!activeId) return;
        setVerifying(true);
        try {
            await save();
            await api.patch(`/admin/products/${activeId}/verify`);
            setSuccessId(activeId);
            setTotal(t => Math.max(0, t - 1));
            setTimeout(() => { setSuccessId(null); removeFromQueue(activeId); }, 500);
        } catch (e) { alert('Erreur: ' + (e.response?.data?.error || e.message)); }
        finally { setVerifying(false); }
    };

    // ── Retirer (masquer) ─────────────────────────────────────────────────────
    const hideProduct = async () => {
        if (!activeId) return;
        try {
            await api.patch(`/admin/products/${activeId}/toggle-visibility`);
            setSuccessId(activeId);
            setTimeout(() => { setSuccessId(null); removeFromQueue(activeId); }, 400);
        } catch (e) { alert('Erreur: ' + (e.response?.data?.error || e.message)); }
    };

    // ── Supprimer ─────────────────────────────────────────────────────────────
    const deleteProduct = async () => {
        if (!activeId || !confirmDelete) return;
        try {
            await api.delete(`/admin/products/${activeId}`);
            setSuccessId(activeId);
            setTotal(t => Math.max(0, t - 1));
            setTimeout(() => { setSuccessId(null); removeFromQueue(activeId); }, 400);
        } catch (e) { alert('Erreur: ' + (e.response?.data?.error || e.message)); }
        finally { setConfirmDelete(false); }
    };

    // ── RENDU ─────────────────────────────────────────────────────────────────
    if (loading) return <div className="flex justify-center items-center h-96"><ArrowPathIcon className="h-8 w-8 text-blue-500 animate-spin" /></div>;
    if (error) return (
        <div className="p-6 bg-red-50 rounded-2xl border border-red-100 m-6">
            <p className="font-semibold text-red-700">Erreur</p>
            <p className="text-sm text-red-500 mt-1">{error}</p>
            <button onClick={() => loadQueue(0, 0)} className="mt-3 px-4 py-2 bg-red-600 text-white rounded-xl text-sm">Réessayer</button>
        </div>
    );
    if (queue.length === 0) return (
        <div className="p-16 text-center">
            <InboxIcon className="h-16 w-16 text-gray-200 mx-auto mb-4" />
            <p className="text-gray-500 font-semibold">Tout est vérifié ✅</p>
            <button onClick={() => loadQueue(0, 0)} className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm">Rafraîchir</button>
        </div>
    );

    return (
        <div className="flex gap-4 h-[calc(100vh-72px)] p-4 bg-gray-50 overflow-hidden">

            {/* ── File gauche ── */}
            <div className="w-52 flex-shrink-0 bg-white rounded-2xl shadow-sm border border-gray-100 flex flex-col overflow-hidden">
                <div className="px-3 py-3 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
                    <span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">File</span>
                    <span className="text-xs bg-blue-100 text-blue-600 font-semibold px-2 py-0.5 rounded-full">{totalUnverified}</span>
                </div>
                <div className="flex-1 overflow-y-auto p-2 space-y-0.5">
                    {queue.map((p, idx) => (
                        <div key={p.id} className={`transition-all duration-300 ${successId === p.id ? 'opacity-0 -translate-x-4 h-0 overflow-hidden' : ''}`}>
                            <QueueCard product={p} isActive={idx === queueIdx} onClick={() => setQueueIdx(idx)} />
                        </div>
                    ))}
                </div>
            </div>

            {/* ── Panneau principal ── */}
            {active && (
                <div className="flex-1 flex flex-col gap-3 overflow-hidden min-w-0">

                    {/* Header */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden flex-shrink-0">
                        <div className="flex">
                            {/* Image produit avec fallback */}
                            <div className="w-32 h-32 flex-shrink-0 bg-gradient-to-br from-gray-100 to-gray-200 overflow-hidden relative flex items-center justify-center">
                                {img
                                    ? <img src={img} alt="" className="w-full h-full object-cover absolute inset-0"
                                        onError={e => { e.target.onerror = null; e.target.style.display = 'none'; }} />
                                    : null}
                                {/* Fallback icône si pas d'image ou image cassée */}
                                <span className="text-4xl select-none">🛍️</span>
                            </div>
                            <div className="p-4 flex-1 min-w-0">
                                <div className="flex items-start justify-between gap-2">
                                    <div className="min-w-0">
                                        <h2 className="text-sm font-bold text-gray-900 truncate">{active.name}</h2>
                                        <p className="text-xs text-gray-400 flex items-center gap-1 mt-0.5">
                                            <TagIcon className="h-3 w-3" />
                                            <span>{active.category}</span>
                                            <span className="mx-1">·</span>
                                            <UserIcon className="h-3 w-3" />
                                            <span className="font-medium text-gray-600">
                                                {active.seller_name || active.seller_phone || 'Vendeur'}
                                            </span>
                                        </p>
                                    </div>
                                    <span className="text-lg font-bold text-blue-600 flex-shrink-0">${parseFloat(active.price || 0).toFixed(2)}</span>
                                </div>
                                {stats && (
                                    <div className="mt-2">
                                        <PriceBar value={parseFloat(form.price) || parseFloat(active.price)} min={parseFloat(stats.price_min)} max={parseFloat(stats.price_max)} median={parseFloat(stats.price_median)} avg={parseFloat(stats.price_avg)} />
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Onglets */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
                        <div className="flex border-b border-gray-100 px-2 pt-2 gap-1 flex-shrink-0 overflow-x-auto">
                            {TABS.map(t => (
                                <button key={t.id} onClick={() => setActiveTab(t.id)}
                                    className={`flex items-center gap-1 px-3 py-2 text-xs font-medium rounded-t-lg transition border-b-2 whitespace-nowrap flex-shrink-0
                                        ${activeTab === t.id ? 'text-blue-600 border-blue-500 bg-blue-50' : 'text-gray-400 border-transparent hover:text-gray-600'}`}>
                                    <t.icon className="h-3.5 w-3.5" />{t.label}
                                </button>
                            ))}
                        </div>
                        <div className="flex-1 overflow-y-auto p-4">

                            {/* Infos */}
                            {activeTab === 'infos' && (
                                <div className="space-y-4">
                                    <div>
                                        <label className="text-xs font-semibold text-gray-600 mb-1 block">Nom</label>
                                        <input className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                                            value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
                                    </div>
                                    <div>
                                        <label className="text-xs font-semibold text-gray-600 mb-1 block">Description</label>
                                        <textarea rows={5} className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm resize-none focus:outline-none focus:ring-2 focus:ring-blue-400"
                                            value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
                                    </div>
                                </div>
                            )}

                            {/* Prix */}
                            {activeTab === 'price' && (
                                <div className="space-y-4">
                                    <div>
                                        <label className="text-xs font-semibold text-gray-600 mb-1 block">Prix ($)</label>
                                        <div className="relative">
                                            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">$</span>
                                            <input type="number" step="0.01" min="0"
                                                className="w-full pl-7 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-blue-400"
                                                value={form.price} onChange={e => setForm(f => ({ ...f, price: e.target.value }))} />
                                        </div>
                                    </div>
                                    {stats && (
                                        <div className="grid grid-cols-2 gap-3">
                                            {[['Min', stats.price_min, 'text-green-600'], ['Médiane', stats.price_median, 'text-amber-600'], ['Moyenne', stats.price_avg, 'text-blue-600'], ['Max', stats.price_max, 'text-red-500']].map(([l, v, c]) => (
                                                <div key={l} className="bg-gray-50 rounded-xl p-3 text-center">
                                                    <p className="text-xs text-gray-400">{l}</p>
                                                    <p className={`text-base font-bold ${c}`}>${parseFloat(v || 0).toFixed(2)}</p>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Livraison */}
                            {activeTab === 'delivery' && (
                                <DeliveryTab shipping={shipping} setShipping={setShipping} />
                            )}

                            {/* Variantes */}
                            {activeTab === 'variants' && (
                                variantsLoading
                                    ? <div className="flex justify-center py-6"><ArrowPathIcon className="h-5 w-5 animate-spin text-blue-400" /></div>
                                    : <VariantsTab activeId={activeId} variants={variants} setVariants={setVariants} />
                            )}

                            {/* Badge Brand */}
                            {activeTab === 'brand' && (
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between p-4 bg-amber-50 rounded-2xl border border-amber-100">
                                        <div>
                                            <p className="text-sm font-semibold text-amber-800 flex items-center gap-2"><StarIcon className="h-4 w-4" />Badge Certifié</p>
                                            <p className="text-xs text-amber-600 mt-0.5">Certifie l'authenticité du produit</p>
                                        </div>
                                        <button onClick={() => setForm(f => ({ ...f, brand_certified: !f.brand_certified }))}
                                            className={`w-12 h-6 rounded-full transition-colors flex-shrink-0 ${form.brand_certified ? 'bg-amber-500' : 'bg-gray-200'}`}>
                                            <div className={`w-5 h-5 bg-white rounded-full shadow m-0.5 transition-transform ${form.brand_certified ? 'translate-x-6' : 'translate-x-0'}`} />
                                        </button>
                                    </div>
                                    {form.brand_certified && (
                                        <div>
                                            <label className="text-xs font-semibold text-gray-600 mb-1 block">Nom du badge <span className="text-gray-300 font-normal">(optionnel)</span></label>
                                            <input className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
                                                value={form.brand_display_name} onChange={e => setForm(f => ({ ...f, brand_display_name: e.target.value }))}
                                                placeholder="ex: Nike, Samsung..." />
                                            <div className="mt-3 p-3 bg-gray-50 rounded-xl">
                                                <p className="text-xs text-gray-400 mb-1.5">Aperçu :</p>
                                                <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-semibold border bg-amber-50 text-amber-700 border-amber-200">
                                                    <CheckBadgeSolid className="h-4 w-4" />
                                                    {form.brand_display_name || 'Produit Certifié Authentique'}
                                                </span>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* ── Boutons actions ── */}
                    <div className="flex-shrink-0 space-y-2">
                        {/* Ligne 1 : actions dangereuses */}
                        <div className="flex gap-2">
                            <button onClick={hideProduct}
                                className="flex items-center gap-1.5 px-4 py-2.5 bg-white border border-orange-200 text-orange-600 rounded-xl text-xs font-semibold hover:bg-orange-50 transition shadow-sm">
                                <EyeSlashIcon className="h-4 w-4" />Retirer
                            </button>
                            {confirmDelete ? (
                                <div className="flex-1 flex gap-2">
                                    <button onClick={deleteProduct}
                                        className="flex-1 py-2.5 bg-red-600 text-white rounded-xl text-xs font-bold hover:bg-red-700 transition">
                                        ⚠️ Confirmer la suppression
                                    </button>
                                    <button onClick={() => setConfirmDelete(false)}
                                        className="px-3 py-2.5 bg-white border border-gray-200 text-gray-500 rounded-xl text-xs hover:bg-gray-50">
                                        <XMarkIcon className="h-4 w-4" />
                                    </button>
                                </div>
                            ) : (
                                <button onClick={() => setConfirmDelete(true)}
                                    className="flex items-center gap-1.5 px-4 py-2.5 bg-white border border-red-200 text-red-600 rounded-xl text-xs font-semibold hover:bg-red-50 transition shadow-sm">
                                    <TrashIcon className="h-4 w-4" />Supprimer
                                </button>
                            )}
                        </div>
                        {/* Ligne 2 : navigation */}
                        <div className="flex gap-2">
                            <button onClick={skip}
                                className="flex items-center gap-1.5 px-4 py-3 bg-white border border-gray-200 text-gray-600 rounded-2xl text-sm font-medium hover:bg-gray-50 transition shadow-sm">
                                <ArrowRightIcon className="h-4 w-4" />Passer
                            </button>
                            <button onClick={save} disabled={saving}
                                className="flex items-center gap-1.5 px-4 py-3 bg-gray-800 text-white rounded-2xl text-sm font-medium hover:bg-gray-900 disabled:opacity-50 transition shadow-sm">
                                {saving ? <ArrowPathIcon className="h-4 w-4 animate-spin" /> : <PencilSquareIcon className="h-4 w-4" />}
                                Enregistrer
                            </button>
                            <button onClick={verifyAndNext} disabled={verifying}
                                className="flex-1 flex items-center justify-center gap-2 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-sm font-bold transition shadow-md shadow-blue-200">
                                {verifying ? <ArrowPathIcon className="h-5 w-5 animate-spin" /> : <><CheckBadgeSolid className="h-5 w-5" />Vérifier &amp; Suivant</>}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
