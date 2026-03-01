import { useState, useEffect, useCallback } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    CheckBadgeIcon,
    ArrowPathIcon,
    TagIcon,
    UserIcon,
    PencilSquareIcon,
    ChevronRightIcon,
    InboxIcon,
} from '@heroicons/react/24/outline';
import { CheckBadgeIcon as CheckBadgeSolid, CheckCircleIcon } from '@heroicons/react/24/solid';

// ─── Barre de prix ────────────────────────────────────────────────────────────
function PriceBar({ value, min, max, median, avg }) {
    const range = max - min || 1;
    const pct = Math.min(100, Math.max(0, ((value - min) / range) * 100));
    const medPct = Math.min(100, Math.max(0, ((median - min) / range) * 100));
    const avgPct = Math.min(100, Math.max(0, ((avg - min) / range) * 100));
    return (
        <div>
            <div className="relative h-4 bg-gray-100 rounded-full overflow-visible mb-1">
                <div className="h-full rounded-full bg-blue-400 transition-all" style={{ width: `${pct}%` }} />
                <div className="absolute top-0 h-full w-0.5 bg-amber-500" style={{ left: `${medPct}%` }} title={`Médiane $${median}`} />
                <div className="absolute top-0 h-full w-0.5 bg-green-500" style={{ left: `${avgPct}%` }} title={`Moy. $${avg}`} />
            </div>
            <div className="flex justify-between text-xs text-gray-400">
                <span>${parseFloat(min).toFixed(2)}</span>
                <span className="font-bold text-blue-600">${parseFloat(value).toFixed(2)}</span>
                <span>${parseFloat(max).toFixed(2)}</span>
            </div>
            <div className="flex gap-3 mt-1 text-xs text-gray-400">
                <span className="flex items-center gap-1"><span className="w-2 h-2 bg-amber-500 rounded-full inline-block" />Méd. ${parseFloat(median).toFixed(2)}</span>
                <span className="flex items-center gap-1"><span className="w-2 h-2 bg-green-500 rounded-full inline-block" />Moy. ${parseFloat(avg).toFixed(2)}</span>
            </div>
        </div>
    );
}

// ─── Carte de la file (gauche) ───────────────────────────────────────────────
function QueueCard({ product, isActive, onClick }) {
    const img = product.images?.[0] ? getImageUrl(product.images[0]) : 'https://via.placeholder.com/48?text=No';
    return (
        <button
            onClick={onClick}
            className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition text-left ${isActive ? 'bg-blue-50 border border-blue-200' : 'hover:bg-gray-50 border border-transparent'}`}
        >
            <img src={img} alt="" className="w-10 h-10 rounded-lg object-cover bg-gray-100 flex-shrink-0"
                onError={e => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/40?text=No'; }} />
            <div className="flex-1 min-w-0">
                <p className="text-xs font-medium text-gray-800 truncate">{product.name}</p>
                <p className="text-xs text-gray-400 flex items-center gap-1">
                    <TagIcon className="h-3 w-3" />{product.category}
                </p>
            </div>
            <span className="text-xs font-bold text-blue-600 flex-shrink-0">${parseFloat(product.price).toFixed(2)}</span>
            {isActive && <ChevronRightIcon className="h-4 w-4 text-blue-400" />}
        </button>
    );
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
export default function ProductComparator() {
    const [queue, setQueue] = useState([]);
    const [totalUnverified, setTotalUnverified] = useState(0);
    const [activeId, setActiveId] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [editPrice, setEditPrice] = useState('');
    const [savingPrice, setSavingPrice] = useState(false);
    const [verifying, setVerifying] = useState(false);
    const [successId, setSuccessId] = useState(null);
    const [offset, setOffset] = useState(0);

    const active = queue.find(p => p.id === activeId) || null;
    const stats = active?.category_stats || null;
    const img = active?.images?.[0] ? getImageUrl(active.images[0]) : 'https://via.placeholder.com/200?text=No+img';

    const loadQueue = useCallback(async (currentOffset = 0) => {
        setLoading(true);
        setError(null);
        try {
            const { data } = await api.get(`/admin/products/unverified?limit=10&offset=${currentOffset}`);
            if (!data || data.error) throw new Error(data?.error || 'Erreur API');
            setQueue(data.products || []);
            setTotalUnverified(data.total_unverified || 0);
            if (data.products?.length > 0) {
                setActiveId(data.products[0].id);
                setEditPrice(data.products[0].price);
            } else {
                setActiveId(null);
            }
        } catch (e) {
            console.error('loadQueue error:', e);
            setError(e.response?.data?.error || e.message || 'Erreur de chargement');
        }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { loadQueue(0); }, [loadQueue]);

    // Sélectionner un produit dans la file
    const selectProduct = (p) => {
        setActiveId(p.id);
        setEditPrice(p.price);
    };

    // Sauvegarder le prix
    const savePrice = async () => {
        if (!active || editPrice == active.price) return;
        setSavingPrice(true);
        try {
            await api.patch(`/admin/products/${active.id}/price`, { price: editPrice });
            // Mettre à jour localement
            setQueue(prev => prev.map(p => p.id === active.id ? { ...p, price: editPrice } : p));
        } catch (e) { alert('Erreur mise à jour prix'); }
        finally { setSavingPrice(false); }
    };

    // Vérifier le produit → le retire de la file et charge le suivant
    const verifyAndNext = async () => {
        if (!active) return;
        setVerifying(true);
        try {
            // Sauvegarder le prix si modifié
            if (editPrice != active.price) {
                await api.patch(`/admin/products/${active.id}/price`, { price: editPrice });
            }
            // Vérifier
            await api.patch(`/admin/products/${active.id}/verify`);
            setSuccessId(active.id);

            // Retirer de la file après 600ms d'animation
            setTimeout(() => {
                setSuccessId(null);
                const newQueue = queue.filter(p => p.id !== active.id);

                // Si la file est presque vide, charger le suivant
                if (newQueue.length <= 2) {
                    const newOffset = offset + 10;
                    setOffset(newOffset);
                    loadQueue(newOffset);
                } else {
                    // Sélectionner le prochain produit
                    const currentIdx = queue.findIndex(p => p.id === active.id);
                    const nextProduct = queue[currentIdx + 1] || queue[0];
                    setQueue(newQueue);
                    if (nextProduct && nextProduct.id !== active.id) {
                        setActiveId(nextProduct.id);
                        setEditPrice(nextProduct.price);
                    } else {
                        setActiveId(newQueue[0]?.id || null);
                        setEditPrice(newQueue[0]?.price || '');
                    }
                    setTotalUnverified(t => Math.max(0, t - 1));
                }
            }, 600);
        } catch (e) { alert('Erreur vérification'); }
        finally { setVerifying(false); }
    };

    // ── Rendu ──────────────────────────────────────────────────────────────────
    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="flex items-start justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                        <CheckBadgeIcon className="h-7 w-7 text-blue-600" />
                        File de Vérification
                    </h1>
                    <p className="text-sm text-gray-400 mt-1">
                        Vérifiez et corrigez les prix des produits avant de les étiqueter
                    </p>
                </div>
                {totalUnverified > 0 && (
                    <span className="bg-blue-100 text-blue-700 text-sm font-semibold px-3 py-1.5 rounded-full">
                        {totalUnverified} en attente
                    </span>
                )}
            </div>

            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <ArrowPathIcon className="h-8 w-8 text-blue-500 animate-spin" />
                </div>
            ) : queue.length === 0 ? (
                <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-16 text-center">
                    <InboxIcon className="h-16 w-16 text-gray-200 mx-auto mb-4" />
                    <p className="text-gray-500 font-semibold text-lg">Tout est vérifié ✅</p>
                    <p className="text-sm text-gray-300 mt-1">Il n'y a plus de produits en attente de vérification</p>
                    <button onClick={() => loadQueue(0)}
                        className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm hover:bg-blue-700 transition">
                        Rafraîchir
                    </button>
                </div>
            ) : (
                <div className="flex gap-5 h-[calc(100vh-180px)]">

                    {/* File gauche */}
                    <div className="w-64 flex-shrink-0 bg-white rounded-2xl shadow-sm border border-gray-100 overflow-y-auto flex flex-col">
                        <div className="px-4 py-3 border-b border-gray-100">
                            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">
                                File ({queue.length})
                            </p>
                        </div>
                        <div className="flex-1 p-2 space-y-1">
                            {queue.map(p => (
                                <div key={p.id} className={`transition-all duration-500 ${successId === p.id ? 'opacity-0 scale-95' : 'opacity-100 scale-100'}`}>
                                    <QueueCard
                                        product={p}
                                        isActive={p.id === activeId}
                                        onClick={() => selectProduct(p)}
                                    />
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Panneau détail droite */}
                    {active && (
                        <div className="flex-1 overflow-y-auto space-y-4">

                            {/* Image + infos */}
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                                <div className="flex">
                                    <img src={img} alt={active.name}
                                        className="w-40 h-40 object-cover bg-gray-100 flex-shrink-0"
                                        onError={e => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/160?text=No'; }} />
                                    <div className="p-5 flex-1 min-w-0">
                                        <h2 className="text-base font-bold text-gray-900 leading-snug">{active.name}</h2>
                                        <div className="flex flex-wrap items-center gap-2 mt-2">
                                            <span className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full flex items-center gap-1">
                                                <TagIcon className="h-3 w-3" />{active.category}
                                            </span>
                                            <span className="text-xs text-gray-400 flex items-center gap-1">
                                                <UserIcon className="h-3 w-3" />{active.seller_name}
                                            </span>
                                        </div>
                                        {active.description && (
                                            <p className="text-xs text-gray-400 mt-2 line-clamp-3">{active.description}</p>
                                        )}
                                    </div>
                                </div>
                            </div>

                            {/* Modification prix */}
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                                <p className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
                                    <PencilSquareIcon className="h-4 w-4" />Modifier le prix
                                </p>
                                <div className="flex items-center gap-3">
                                    <div className="relative flex-1">
                                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                                        <input
                                            type="number"
                                            step="0.01"
                                            min="0"
                                            value={editPrice}
                                            onChange={e => setEditPrice(e.target.value)}
                                            className="w-full pl-7 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-semibold"
                                        />
                                    </div>
                                    <button
                                        onClick={savePrice}
                                        disabled={savingPrice || editPrice == active.price}
                                        className="px-4 py-2.5 bg-gray-800 text-white rounded-xl text-sm font-medium hover:bg-gray-900 disabled:opacity-40 transition flex items-center gap-2"
                                    >
                                        {savingPrice ? <ArrowPathIcon className="h-4 w-4 animate-spin" /> : 'Enregistrer'}
                                    </button>
                                </div>
                            </div>

                            {/* Comparaison prix catégorie */}
                            {stats && (
                                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                                    <p className="text-sm font-semibold text-gray-700 mb-3">
                                        Position dans <span className="text-blue-600">"{active.category}"</span>
                                        <span className="text-xs text-gray-400 font-normal ml-1">({stats.total} produits)</span>
                                    </p>
                                    <PriceBar
                                        value={parseFloat(editPrice) || parseFloat(active.price)}
                                        min={parseFloat(stats.price_min) || 0}
                                        max={parseFloat(stats.price_max) || 0}
                                        median={parseFloat(stats.price_median) || 0}
                                        avg={parseFloat(stats.price_avg) || 0}
                                    />
                                    {(() => {
                                        const price = parseFloat(editPrice) || parseFloat(active.price);
                                        const median = parseFloat(stats.price_median);
                                        if (!median) return null;
                                        const diff = ((price - median) / median * 100).toFixed(1);
                                        const cheaper = diff < 0;
                                        return (
                                            <p className={`text-xs mt-3 font-medium ${cheaper ? 'text-green-600' : 'text-orange-500'}`}>
                                                {cheaper ? `▼ ${Math.abs(diff)}% sous la médiane` : `▲ ${diff}% au-dessus de la médiane`}
                                            </p>
                                        );
                                    })()}
                                </div>
                            )}

                            {/* Bouton vérifier */}
                            <button
                                onClick={verifyAndNext}
                                disabled={verifying}
                                className="w-full py-3.5 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl text-sm font-bold transition flex items-center justify-center gap-2 shadow-md shadow-blue-200"
                            >
                                {verifying ? (
                                    <ArrowPathIcon className="h-5 w-5 animate-spin" />
                                ) : (
                                    <><CheckBadgeSolid className="h-5 w-5" />Vérifier &amp; Passer au suivant</>
                                )}
                            </button>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}
