import { useState, useEffect, useCallback } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    CheckBadgeIcon, ArrowPathIcon, TagIcon, UserIcon,
    PencilSquareIcon, TruckIcon, SwatchIcon, ArrowRightIcon,
    PlusIcon, TrashIcon, InboxIcon, StarIcon,
} from '@heroicons/react/24/outline';
import { CheckBadgeIcon as CheckBadgeSolid } from '@heroicons/react/24/solid';

// ─── Barre prix ───────────────────────────────────────────────────────────────
function PriceBar({ value, min, max, median, avg }) {
    const range = max - min || 1;
    const pct = Math.min(100, Math.max(0, ((value - min) / range) * 100));
    const medPct = Math.min(100, Math.max(0, ((median - min) / range) * 100));
    const avgPct = Math.min(100, Math.max(0, ((avg - min) / range) * 100));
    return (
        <div>
            <div className="relative h-4 bg-gray-100 rounded-full overflow-visible mb-1">
                <div className="h-full rounded-full bg-blue-400 transition-all" style={{ width: `${pct}%` }} />
                <div className="absolute top-0 h-full w-0.5 bg-amber-500" style={{ left: `${medPct}%` }} />
                <div className="absolute top-0 h-full w-0.5 bg-green-500" style={{ left: `${avgPct}%` }} />
            </div>
            <div className="flex justify-between text-xs text-gray-400">
                <span>${parseFloat(min || 0).toFixed(2)}</span>
                <span className="font-bold text-blue-600">${parseFloat(value || 0).toFixed(2)}</span>
                <span>${parseFloat(max || 0).toFixed(2)}</span>
            </div>
            <div className="flex gap-3 mt-1 text-xs text-gray-400">
                <span className="flex items-center gap-1"><span className="w-2 h-2 bg-amber-400 rounded-full" />Méd. ${parseFloat(median || 0).toFixed(2)}</span>
                <span className="flex items-center gap-1"><span className="w-2 h-2 bg-green-500 rounded-full" />Moy. ${parseFloat(avg || 0).toFixed(2)}</span>
            </div>
        </div>
    );
}

// ─── Carte file ───────────────────────────────────────────────────────────────
function QueueCard({ product, isActive, skipped, onClick }) {
    const img = product.images?.[0] ? getImageUrl(product.images[0]) : null;
    return (
        <button onClick={onClick}
            className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-xl transition text-left border
                ${isActive ? 'bg-blue-50 border-blue-200' : skipped ? 'opacity-40 border-transparent' : 'hover:bg-gray-50 border-transparent'}`}>
            <div className="w-9 h-9 rounded-lg bg-gray-100 flex-shrink-0 overflow-hidden">
                {img ? <img src={img} alt="" className="w-full h-full object-cover"
                    onError={e => { e.target.onerror = null; e.target.style.display = 'none'; }} /> : null}
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

// ─── MAIN ─────────────────────────────────────────────────────────────────────
export default function ProductComparator() {
    const [queue, setQueue] = useState([]);
    const [skipped, setSkipped] = useState(new Set());
    const [totalUnverified, setTotal] = useState(0);
    const [activeId, setActiveId] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [activeTab, setActiveTab] = useState('infos');
    const [saving, setSaving] = useState(false);
    const [verifying, setVerifying] = useState(false);
    const [successId, setSuccessId] = useState(null);
    const [offset, setOffset] = useState(0);
    const [variants, setVariants] = useState([]);
    const [variantsLoading, setVL] = useState(false);

    // Form state
    const [form, setForm] = useState({ name: '', description: '', price: '', brand_certified: false, brand_display_name: '' });
    const [shipping, setShipping] = useState([]);
    const [newVariant, setNewVariant] = useState({ variant_type: 'color', variant_value: '', price_adjustment: 0, stock_quantity: 0 });

    const active = queue.find(p => p.id === activeId) || null;
    const stats = active?.category_stats || null;
    const img = active?.images?.[0] ? getImageUrl(active.images[0]) : null;

    // ── Charger file ─────────────────────────────────────────────────────────
    const loadQueue = useCallback(async (currentOffset = 0) => {
        setLoading(true); setError(null);
        try {
            const { data } = await api.get(`/admin/products/unverified?limit=10&offset=${currentOffset}`);
            if (!data || data.error) throw new Error(data?.error || 'Erreur API');
            setQueue(data.products || []);
            setTotal(data.total_unverified || 0);
            if (data.products?.length > 0) selectProduct(data.products[0]);
        } catch (e) { setError(e.response?.data?.error || e.message); }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { loadQueue(0); }, [loadQueue]);

    // ── Sélectionner produit ──────────────────────────────────────────────────
    const selectProduct = (p) => {
        setActiveId(p.id);
        setForm({ name: p.name || '', description: p.description || '', price: p.price || '', brand_certified: p.brand_certified || false, brand_display_name: p.brand_display_name || '' });
        setShipping(p.shipping_options || []);
        setActiveTab('infos');
        setVariants([]);
    };

    // Charger variantes quand onglet actif
    useEffect(() => {
        if (activeTab !== 'variants' || !activeId) return;
        setVL(true);
        api.get(`/admin/products/${activeId}/variants`)
            .then(r => setVariants(r.data.variants || []))
            .catch(() => setVariants([]))
            .finally(() => setVL(false));
    }, [activeTab, activeId]);

    // ── Skip ─────────────────────────────────────────────────────────────────
    const skip = () => {
        if (!activeId) return;
        const newSkipped = new Set(skipped).add(activeId);
        setSkipped(newSkipped);
        const nextProduct = queue.find(p => !newSkipped.has(p.id) && p.id !== activeId);
        if (nextProduct) selectProduct(nextProduct);
    };

    // ── Sauvegarder & Vérifier ───────────────────────────────────────────────
    const save = async () => {
        if (!active) return;
        setSaving(true);
        try {
            await api.patch(`/admin/products/${activeId}/quick-edit`, {
                name: form.name,
                description: form.description,
                price: form.price,
                shipping_options: shipping,
                brand_certified: form.brand_certified,
                brand_display_name: form.brand_display_name || null,
            });
        } catch (e) { alert('Erreur sauvegarde: ' + (e.response?.data?.error || e.message)); }
        finally { setSaving(false); }
    };

    const verifyAndNext = async () => {
        if (!active) return;
        setVerifying(true);
        try {
            await save();
            await api.patch(`/admin/products/${activeId}/verify`);
            setSuccessId(activeId);
            setTimeout(() => {
                setSuccessId(null);
                const newQueue = queue.filter(p => p.id !== activeId);
                const newSkipped = new Set(skipped); newSkipped.delete(activeId);
                setSkipped(newSkipped);
                setTotal(t => Math.max(0, t - 1));
                if (newQueue.length <= 2) { const no = offset + 10; setOffset(no); loadQueue(no); }
                else {
                    const next = newQueue.find(p => !newSkipped.has(p.id));
                    setQueue(newQueue);
                    if (next) selectProduct(next);
                    else { setQueue(newQueue); setActiveId(null); }
                }
            }, 500);
        } catch (e) { alert('Erreur vérification'); }
        finally { setVerifying(false); }
    };

    // ── Livraison helpers ────────────────────────────────────────────────────
    const addShipping = () => setShipping(s => [...s, { methodId: `custom_${Date.now()}`, label: 'Nouvelle livraison', cost: 0, time: '3-5 jours' }]);
    const updateShipping = (idx, key, val) => setShipping(s => s.map((item, i) => i === idx ? { ...item, [key]: val } : item));
    const removeShipping = (idx) => setShipping(s => s.filter((_, i) => i !== idx));

    // ── Variantes helpers ────────────────────────────────────────────────────
    const addVariant = async () => {
        if (!newVariant.variant_value.trim()) return;
        try {
            const { data } = await api.post(`/admin/products/${activeId}/variants`, newVariant);
            setVariants(v => [...v.filter(x => x.id !== data.variant.id), data.variant]);
            setNewVariant(p => ({ ...p, variant_value: '', price_adjustment: 0, stock_quantity: 0 }));
        } catch (e) { alert(e.response?.data?.error || e.message); }
    };
    const deleteVariant = async (vid) => {
        try {
            await api.delete(`/admin/products/${activeId}/variants/${vid}`);
            setVariants(v => v.filter(x => x.id !== vid));
        } catch (e) { alert(e.response?.data?.error || e.message); }
    };

    // ── RENDU ─────────────────────────────────────────────────────────────────
    if (loading) return (
        <div className="flex justify-center items-center h-96">
            <ArrowPathIcon className="h-8 w-8 text-blue-500 animate-spin" />
        </div>
    );

    if (error) return (
        <div className="p-6 bg-red-50 rounded-2xl border border-red-100 m-6">
            <p className="font-semibold text-red-700">Erreur de chargement</p>
            <p className="text-sm text-red-500 mt-1">{error}</p>
            <button onClick={() => loadQueue(0)} className="mt-3 px-4 py-2 bg-red-600 text-white rounded-xl text-sm">Réessayer</button>
        </div>
    );

    if (queue.length === 0) return (
        <div className="p-16 text-center">
            <InboxIcon className="h-16 w-16 text-gray-200 mx-auto mb-4" />
            <p className="text-gray-500 font-semibold">Tout est vérifié ✅</p>
            <button onClick={() => loadQueue(0)} className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm">Rafraîchir</button>
        </div>
    );

    return (
        <div className="flex gap-5 h-[calc(100vh-72px)] p-5 bg-gray-50 overflow-hidden">

            {/* ── File gauche ── */}
            <div className="w-56 flex-shrink-0 bg-white rounded-2xl shadow-sm border border-gray-100 flex flex-col overflow-hidden">
                <div className="px-3 py-3 border-b border-gray-100 flex items-center justify-between">
                    <span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">File</span>
                    <span className="text-xs bg-blue-100 text-blue-600 font-semibold px-2 py-0.5 rounded-full">{totalUnverified}</span>
                </div>
                <div className="flex-1 overflow-y-auto p-2 space-y-0.5">
                    {queue.map(p => (
                        <div key={p.id} className={`transition-all duration-400 ${successId === p.id ? 'opacity-0 scale-95 h-0 overflow-hidden' : ''}`}>
                            <QueueCard product={p} isActive={p.id === activeId} skipped={skipped.has(p.id)} onClick={() => selectProduct(p)} />
                        </div>
                    ))}
                </div>
            </div>

            {/* ── Panneau principal ── */}
            {active && (
                <div className="flex-1 flex flex-col gap-4 overflow-y-auto min-w-0">

                    {/* Header produit */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden flex-shrink-0">
                        <div className="flex">
                            <div className="w-36 h-36 flex-shrink-0 bg-gray-100 overflow-hidden">
                                {img && <img src={img} alt="" className="w-full h-full object-cover"
                                    onError={e => { e.target.onerror = null; e.target.style.opacity = '0'; }} />}
                            </div>
                            <div className="p-4 flex-1 min-w-0">
                                <div className="flex items-start justify-between gap-2">
                                    <div className="min-w-0">
                                        <h2 className="text-sm font-bold text-gray-900 truncate">{active.name}</h2>
                                        <p className="text-xs text-gray-400 flex items-center gap-1 mt-0.5">
                                            <TagIcon className="h-3 w-3" />{active.category}
                                            <span className="mx-1">·</span>
                                            <UserIcon className="h-3 w-3" />{active.seller_name}
                                        </p>
                                    </div>
                                    <div className="flex flex-col items-end gap-1">
                                        <span className="text-lg font-bold text-blue-600">${parseFloat(active.price || 0).toFixed(2)}</span>
                                        {active.brand_certified && (
                                            <span className="text-xs bg-amber-50 text-amber-600 px-2 py-0.5 rounded-full border border-amber-200 flex items-center gap-1">
                                                <StarIcon className="h-3 w-3" />{active.brand_display_name || 'Brand Certifié'}
                                            </span>
                                        )}
                                    </div>
                                </div>
                                {stats && (
                                    <div className="mt-3">
                                        <PriceBar value={parseFloat(form.price) || parseFloat(active.price)} min={parseFloat(stats.price_min)} max={parseFloat(stats.price_max)} median={parseFloat(stats.price_median)} avg={parseFloat(stats.price_avg)} />
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Onglets */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
                        <div className="flex border-b border-gray-100 px-2 pt-2 gap-1">
                            {TABS.map(t => (
                                <button key={t.id} onClick={() => setActiveTab(t.id)}
                                    className={`flex items-center gap-1.5 px-3 py-2 text-xs font-medium rounded-t-lg transition border-b-2 ${activeTab === t.id ? 'text-blue-600 border-blue-500 bg-blue-50' : 'text-gray-400 border-transparent hover:text-gray-600'}`}>
                                    <t.icon className="h-3.5 w-3.5" />{t.label}
                                </button>
                            ))}
                        </div>

                        <div className="flex-1 overflow-y-auto p-4 space-y-4">

                            {/* ── Onglet Infos ─────────────── */}
                            {activeTab === 'infos' && (
                                <>
                                    <div>
                                        <label className="text-xs font-semibold text-gray-600 mb-1 block">Nom du produit</label>
                                        <input className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                                            value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="Nom du produit" />
                                    </div>
                                    <div>
                                        <label className="text-xs font-semibold text-gray-600 mb-1 block">Description</label>
                                        <textarea rows={5} className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm resize-none focus:outline-none focus:ring-2 focus:ring-blue-400"
                                            value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} placeholder="Description du produit..." />
                                    </div>
                                </>
                            )}

                            {/* ── Onglet Prix ──────────────── */}
                            {activeTab === 'price' && (
                                <div>
                                    <label className="text-xs font-semibold text-gray-600 mb-1 block">Prix de vente ($)</label>
                                    <div className="relative">
                                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                                        <input type="number" step="0.01" min="0"
                                            className="w-full pl-7 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-blue-400"
                                            value={form.price} onChange={e => setForm(f => ({ ...f, price: e.target.value }))} />
                                    </div>
                                    {stats && (
                                        <div className="mt-4 grid grid-cols-2 gap-3">
                                            {[['Min catégorie', stats.price_min, 'text-green-600'], ['Médiane', stats.price_median, 'text-amber-600'], ['Moyenne', stats.price_avg, 'text-blue-600'], ['Max catégorie', stats.price_max, 'text-red-500']].map(([l, v, c]) => (
                                                <div key={l} className="bg-gray-50 rounded-xl p-3 text-center">
                                                    <p className="text-xs text-gray-400">{l}</p>
                                                    <p className={`text-base font-bold ${c}`}>${parseFloat(v || 0).toFixed(2)}</p>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* ── Onglet Livraison ─────────── */}
                            {activeTab === 'delivery' && (
                                <div className="space-y-3">
                                    {shipping.length === 0 && (
                                        <p className="text-xs text-gray-400 text-center py-4">Aucune option de livraison configurée</p>
                                    )}
                                    {shipping.map((s, i) => (
                                        <div key={i} className="border border-gray-200 rounded-xl p-3 space-y-2">
                                            <div className="flex gap-2">
                                                <input className="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                    value={s.label} onChange={e => updateShipping(i, 'label', e.target.value)} placeholder="Libellé" />
                                                <button onClick={() => removeShipping(i)} className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg">
                                                    <TrashIcon className="h-4 w-4" />
                                                </button>
                                            </div>
                                            <div className="flex gap-2">
                                                <div className="flex-1">
                                                    <label className="text-xs text-gray-400 mb-0.5 block">Coût ($)</label>
                                                    <input type="number" min="0" step="0.5" className="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={s.cost} onChange={e => updateShipping(i, 'cost', parseFloat(e.target.value) || 0)} />
                                                </div>
                                                <div className="flex-1">
                                                    <label className="text-xs text-gray-400 mb-0.5 block">Délai</label>
                                                    <input className="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={s.time} onChange={e => updateShipping(i, 'time', e.target.value)} placeholder="ex: 3-5 jours" />
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                    <button onClick={addShipping} className="w-full py-2 border-2 border-dashed border-gray-200 rounded-xl text-sm text-gray-400 hover:border-blue-300 hover:text-blue-500 transition flex items-center justify-center gap-2">
                                        <PlusIcon className="h-4 w-4" />Ajouter une option
                                    </button>
                                </div>
                            )}

                            {/* ── Onglet Variantes ─────────── */}
                            {activeTab === 'variants' && (
                                <div className="space-y-3">
                                    {variantsLoading ? (
                                        <div className="flex justify-center py-6"><ArrowPathIcon className="h-5 w-5 animate-spin text-blue-400" /></div>
                                    ) : (
                                        <>
                                            {variants.length === 0 && <p className="text-xs text-gray-400 text-center py-4">Aucune variante</p>}
                                            {variants.map(v => (
                                                <div key={v.id} className="flex items-center gap-2 bg-gray-50 rounded-xl px-3 py-2">
                                                    <span className="text-xs text-gray-500 bg-white px-2 py-0.5 rounded-lg border">{v.variant_type}</span>
                                                    <span className="text-sm font-medium text-gray-800 flex-1">{v.variant_value}</span>
                                                    <span className="text-xs text-gray-400">Ajust. {v.price_adjustment >= 0 ? '+' : ''}{v.price_adjustment}$</span>
                                                    <span className="text-xs text-gray-400">Stock: {v.stock_quantity}</span>
                                                    <button onClick={() => deleteVariant(v.id)} className="p-1 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg">
                                                        <TrashIcon className="h-4 w-4" />
                                                    </button>
                                                </div>
                                            ))}
                                            {/* Ajouter variante */}
                                            <div className="border border-gray-200 rounded-xl p-3 space-y-2 mt-2">
                                                <p className="text-xs font-semibold text-gray-600">Ajouter une variante</p>
                                                <div className="flex gap-2">
                                                    <select className="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={newVariant.variant_type} onChange={e => setNewVariant(v => ({ ...v, variant_type: e.target.value }))}>
                                                        {['color', 'size', 'material', 'style'].map(t => <option key={t} value={t}>{t}</option>)}
                                                    </select>
                                                    <input className="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={newVariant.variant_value} onChange={e => setNewVariant(v => ({ ...v, variant_value: e.target.value }))} placeholder="Valeur (ex: Rouge, XL...)" />
                                                </div>
                                                <div className="flex gap-2">
                                                    <input type="number" step="0.5" className="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={newVariant.price_adjustment} onChange={e => setNewVariant(v => ({ ...v, price_adjustment: e.target.value }))} placeholder="Ajust. prix" />
                                                    <input type="number" className="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-blue-400"
                                                        value={newVariant.stock_quantity} onChange={e => setNewVariant(v => ({ ...v, stock_quantity: e.target.value }))} placeholder="Stock" />
                                                    <button onClick={addVariant} className="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 flex items-center gap-1">
                                                        <PlusIcon className="h-4 w-4" />
                                                    </button>
                                                </div>
                                            </div>
                                        </>
                                    )}
                                </div>
                            )}

                            {/* ── Onglet Badge Brand ───────── */}
                            {activeTab === 'brand' && (
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between p-4 bg-amber-50 rounded-2xl border border-amber-100">
                                        <div>
                                            <p className="text-sm font-semibold text-amber-800 flex items-center gap-2"><StarIcon className="h-4 w-4" />Badge Produit Certifié</p>
                                            <p className="text-xs text-amber-600 mt-0.5">Affiche un badge sur la fiche produit pour certifier l'authenticité</p>
                                        </div>
                                        <button onClick={() => setForm(f => ({ ...f, brand_certified: !f.brand_certified }))}
                                            className={`w-12 h-6 rounded-full transition-colors flex-shrink-0 ${form.brand_certified ? 'bg-amber-500' : 'bg-gray-200'}`}>
                                            <div className={`w-5 h-5 bg-white rounded-full shadow m-0.5 transition-transform ${form.brand_certified ? 'translate-x-6' : 'translate-x-0'}`} />
                                        </button>
                                    </div>

                                    {form.brand_certified && (
                                        <div>
                                            <label className="text-xs font-semibold text-gray-600 mb-2 block">Nom affiché sur le badge <span className="text-gray-300 font-normal">(optionnel)</span></label>
                                            <input className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
                                                value={form.brand_display_name} onChange={e => setForm(f => ({ ...f, brand_display_name: e.target.value }))}
                                                placeholder="ex: Nike, Samsung, Apple... (laisser vide pour badge sans nom)" />

                                            {/* Preview */}
                                            <div className="mt-4 p-4 bg-gray-50 rounded-xl border border-gray-100">
                                                <p className="text-xs text-gray-400 mb-2 font-medium">Aperçu du badge :</p>
                                                <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-semibold border
                                                    ${form.brand_display_name ? 'bg-amber-50 text-amber-700 border-amber-200' : 'bg-blue-50 text-blue-700 border-blue-200'}`}>
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

                    {/* Boutons actions */}
                    <div className="flex gap-3 flex-shrink-0">
                        <button onClick={skip}
                            className="flex items-center gap-2 px-5 py-3 bg-white border border-gray-200 text-gray-600 rounded-2xl text-sm font-medium hover:bg-gray-50 transition shadow-sm">
                            <ArrowRightIcon className="h-4 w-4" />Passer
                        </button>
                        <button onClick={save} disabled={saving}
                            className="flex items-center gap-2 px-5 py-3 bg-gray-800 text-white rounded-2xl text-sm font-medium hover:bg-gray-900 disabled:opacity-50 transition shadow-sm">
                            {saving ? <ArrowPathIcon className="h-4 w-4 animate-spin" /> : <PencilSquareIcon className="h-4 w-4" />}
                            Enregistrer
                        </button>
                        <button onClick={verifyAndNext} disabled={verifying}
                            className="flex-1 flex items-center justify-center gap-2 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-sm font-bold transition shadow-md shadow-blue-200">
                            {verifying ? <ArrowPathIcon className="h-5 w-5 animate-spin" /> : <><CheckBadgeSolid className="h-5 w-5" />Vérifier &amp; Suivant</>}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
