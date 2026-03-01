import { useState, useEffect, useCallback } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    MagnifyingGlassIcon,
    CheckBadgeIcon,
    ChartBarIcon,
    ArrowPathIcon,
    TagIcon,
    UserIcon,
    CurrencyDollarIcon,
    XMarkIcon,
} from '@heroicons/react/24/outline';
import { CheckBadgeIcon as CheckBadgeSolid } from '@heroicons/react/24/solid';

// ─── Barre de prix visuelle ──────────────────────────────────────────────────
function PriceBar({ value, min, max, median, avg, label, highlight = false }) {
    const range = max - min || 1;
    const pct = Math.min(100, Math.max(0, ((value - min) / range) * 100));
    const medPct = Math.min(100, Math.max(0, ((median - min) / range) * 100));
    const avgPct = Math.min(100, Math.max(0, ((avg - min) / range) * 100));

    return (
        <div className="mb-2">
            {label && <p className="text-xs text-gray-500 mb-1">{label}</p>}
            <div className="relative h-5 bg-gray-100 rounded-full overflow-visible">
                {/* Barre remplie jusqu'à ce produit */}
                <div
                    className={`h-full rounded-full transition-all ${highlight ? 'bg-blue-500' : 'bg-gray-300'}`}
                    style={{ width: `${pct}%` }}
                />
                {/* Médiane */}
                <div
                    className="absolute top-0 h-full w-0.5 bg-amber-500"
                    style={{ left: `${medPct}%` }}
                    title={`Médiane: $${median}`}
                />
                {/* Moyenne */}
                <div
                    className="absolute top-0 h-full w-0.5 bg-green-500"
                    style={{ left: `${avgPct}%` }}
                    title={`Moyenne: $${avg}`}
                />
            </div>
            <div className="flex justify-between text-xs text-gray-400 mt-0.5">
                <span>${min?.toFixed(2)}</span>
                <span className="font-bold text-blue-600">${value}</span>
                <span>${max?.toFixed(2)}</span>
            </div>
        </div>
    );
}

// ─── Carte concurrent ────────────────────────────────────────────────────────
function CompetitorRow({ product, targetPrice, onSelectProduct }) {
    const diff = (parseFloat(product.price) - parseFloat(targetPrice)).toFixed(2);
    const diffPct = ((diff / parseFloat(targetPrice)) * 100).toFixed(1);
    const cheaper = diff < 0;
    const img = product.images?.[0]
        ? getImageUrl(product.images[0])
        : 'https://via.placeholder.com/48?text=No+img';

    return (
        <div className="flex items-center gap-3 py-2.5 px-3 rounded-xl hover:bg-gray-50 transition cursor-pointer"
            onClick={() => onSelectProduct(product.id)}>
            <img src={img} alt="" className="w-12 h-12 rounded-lg object-cover border border-gray-100 bg-gray-50 flex-shrink-0"
                onError={e => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/48?text=No+img'; }} />
            <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-800 truncate">{product.name}</p>
                <p className="text-xs text-gray-400 flex items-center gap-1">
                    <UserIcon className="h-3 w-3" />{product.seller_name}
                    {product.is_verified && <span className="text-blue-500 flex items-center"><CheckBadgeSolid className="h-3 w-3 ml-1" />Vérifié</span>}
                </p>
            </div>
            <div className="text-right flex-shrink-0">
                <p className="text-sm font-bold text-gray-900">${parseFloat(product.price).toFixed(2)}</p>
                <p className={`text-xs font-medium ${cheaper ? 'text-green-600' : 'text-red-500'}`}>
                    {cheaper ? '▼' : '▲'} {Math.abs(diffPct)}%
                </p>
            </div>
        </div>
    );
}

// ─── Légende ─────────────────────────────────────────────────────────────────
function Legend() {
    return (
        <div className="flex flex-wrap gap-4 text-xs text-gray-500 mt-3">
            <span className="flex items-center gap-1"><span className="inline-block w-3 h-3 rounded-full bg-blue-500" />Ce produit</span>
            <span className="flex items-center gap-1"><span className="inline-block w-0.5 h-4 bg-amber-500" />Médiane</span>
            <span className="flex items-center gap-1"><span className="inline-block w-0.5 h-4 bg-green-500" />Moyenne</span>
        </div>
    );
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
export default function ProductComparator() {
    const [search, setSearch] = useState('');
    const [searchResults, setSearchResults] = useState([]);
    const [selectedId, setSelectedId] = useState(null);
    const [compareData, setCompareData] = useState(null);
    const [loading, setLoading] = useState(false);
    const [verifying, setVerifying] = useState(false);
    const [searchLoading, setSearchLoading] = useState(false);

    // Recherche debounce
    useEffect(() => {
        if (search.trim().length < 2) { setSearchResults([]); return; }
        const t = setTimeout(() => doSearch(search), 350);
        return () => clearTimeout(t);
    }, [search]);

    const doSearch = async (q) => {
        setSearchLoading(true);
        try {
            const { data } = await api.get(`/admin/products?search=${encodeURIComponent(q)}&limit=10`);
            const list = Array.isArray(data) ? data : (data.products || []);
            setSearchResults(list);
        } catch (e) { console.error(e); }
        finally { setSearchLoading(false); }
    };

    const loadCompare = useCallback(async (id) => {
        setSelectedId(id);
        setSearchResults([]);
        setSearch('');
        setLoading(true);
        try {
            const { data } = await api.get(`/admin/products/${id}/compare`);
            setCompareData(data);
        } catch (e) { console.error(e); }
        finally { setLoading(false); }
    }, []);

    const handleVerify = async () => {
        if (!compareData) return;
        setVerifying(true);
        try {
            const { data } = await api.patch(`/admin/products/${compareData.product.id}/verify`);
            setCompareData(prev => ({
                ...prev,
                product: { ...prev.product, is_verified: data.product.is_verified, verified_at: data.product.verified_at }
            }));
        } catch (e) { alert('Erreur lors de la vérification'); }
        finally { setVerifying(false); }
    };

    const { product, category_stats: stats, competitors } = compareData || {};
    const imgUrl = product?.images?.[0] ? getImageUrl(product.images[0]) : 'https://via.placeholder.com/200?text=No+img';

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div>
                <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                    <ChartBarIcon className="h-7 w-7 text-blue-600" />
                    Comparateur de Prix & Vérification
                </h1>
                <p className="text-sm text-gray-400 mt-1">Analysez le positionnement prix d'un produit et étiquetez-le comme vérifié</p>
            </div>

            {/* Barre de recherche */}
            <div className="relative max-w-xl">
                <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                    type="text"
                    placeholder="Rechercher un produit par nom, catégorie, vendeur..."
                    className="w-full pl-10 pr-4 py-3 bg-white border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-sm"
                    value={search}
                    onChange={e => setSearch(e.target.value)}
                />
                {search && (
                    <button onClick={() => { setSearch(''); setSearchResults([]); }}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-300 hover:text-gray-500">
                        <XMarkIcon className="h-4 w-4" />
                    </button>
                )}
                {/* Dropdown résultats */}
                {(searchResults.length > 0 || searchLoading) && (
                    <div className="absolute z-30 top-full mt-1 w-full bg-white rounded-xl shadow-xl border border-gray-100 overflow-hidden max-h-72 overflow-y-auto">
                        {searchLoading ? (
                            <div className="p-4 text-center text-sm text-gray-400">Recherche...</div>
                        ) : searchResults.map(p => (
                            <button key={p.id}
                                className="w-full flex items-center gap-3 px-4 py-3 hover:bg-blue-50 transition text-left"
                                onClick={() => loadCompare(p.id)}>
                                <img
                                    src={p.image_url || 'https://via.placeholder.com/40?text=No+img'}
                                    className="w-10 h-10 rounded-lg object-cover bg-gray-100 flex-shrink-0"
                                    alt="" onError={e => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/40?text=No+img'; }}
                                />
                                <div className="min-w-0">
                                    <p className="text-sm font-medium text-gray-800 truncate">{p.name}</p>
                                    <p className="text-xs text-gray-400 flex items-center gap-1">
                                        <TagIcon className="h-3 w-3" />{p.category} · ${p.price}
                                    </p>
                                </div>
                                {p.is_verified && <CheckBadgeSolid className="h-5 w-5 text-blue-500 ml-auto flex-shrink-0" />}
                            </button>
                        ))}
                    </div>
                )}
            </div>

            {/* Loading */}
            {loading && (
                <div className="flex justify-center items-center h-48">
                    <ArrowPathIcon className="h-8 w-8 text-blue-500 animate-spin" />
                </div>
            )}

            {/* Résultats comparaison */}
            {!loading && compareData && (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

                    {/* Colonne gauche : fiche produit */}
                    <div className="lg:col-span-1 space-y-4">
                        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                            <img src={imgUrl} alt={product.name}
                                className="w-full h-48 object-cover bg-gray-100"
                                onError={e => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/200?text=No+img'; }} />
                            <div className="p-5 space-y-3">
                                <div className="flex items-start justify-between gap-2">
                                    <h2 className="text-base font-bold text-gray-900 leading-snug">{product.name}</h2>
                                    {product.is_verified && (
                                        <CheckBadgeSolid className="h-6 w-6 text-blue-500 flex-shrink-0" title="Produit vérifié" />
                                    )}
                                </div>
                                <div className="flex items-center gap-2 flex-wrap">
                                    <span className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full flex items-center gap-1">
                                        <TagIcon className="h-3 w-3" />{product.category}
                                    </span>
                                    <span className="text-2xl font-bold text-blue-600 flex items-center">
                                        <CurrencyDollarIcon className="h-5 w-5" />{parseFloat(product.price).toFixed(2)}
                                    </span>
                                </div>
                                <div className="flex items-center gap-2">
                                    <img
                                        src={getImageUrl(product.seller_avatar) || `https://ui-avatars.com/api/?name=${product.seller_name}&background=0B1727&color=fff&size=32`}
                                        className="w-7 h-7 rounded-full object-cover"
                                        alt="" onError={e => { e.target.onerror = null; }} />
                                    <span className="text-sm text-gray-600">{product.seller_name}</span>
                                </div>

                                {/* Bouton vérifier */}
                                <button
                                    onClick={handleVerify}
                                    disabled={verifying}
                                    className={`w-full mt-2 py-2.5 rounded-xl text-sm font-semibold transition flex items-center justify-center gap-2 ${product.is_verified
                                            ? 'bg-blue-50 text-blue-600 hover:bg-blue-100'
                                            : 'bg-blue-600 text-white hover:bg-blue-700'
                                        }`}
                                >
                                    {verifying ? (
                                        <ArrowPathIcon className="h-4 w-4 animate-spin" />
                                    ) : product.is_verified ? (
                                        <><CheckBadgeSolid className="h-4 w-4" />Retirer vérification</>
                                    ) : (
                                        <><CheckBadgeIcon className="h-4 w-4" />Vérifier ce produit</>
                                    )}
                                </button>
                                {product.is_verified && product.verified_at && (
                                    <p className="text-xs text-gray-400 text-center">
                                        Vérifié le {new Date(product.verified_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' })}
                                    </p>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Colonne droite : comparaison */}
                    <div className="lg:col-span-2 space-y-4">

                        {/* Stats catégorie */}
                        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                            <h3 className="font-semibold text-gray-800 mb-4">
                                Positionnement dans la catégorie <span className="text-blue-600">"{product.category}"</span>
                                <span className="text-xs text-gray-400 font-normal ml-2">({stats.total} produits actifs)</span>
                            </h3>

                            <PriceBar
                                value={parseFloat(product.price)}
                                min={stats.price_min}
                                max={stats.price_max}
                                median={stats.price_median}
                                avg={stats.price_avg}
                                highlight
                            />
                            <Legend />

                            {/* Stats grid */}
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-5">
                                {[
                                    { label: 'Prix min', value: `$${stats.price_min?.toFixed(2)}`, color: 'text-green-600' },
                                    { label: 'Prix max', value: `$${stats.price_max?.toFixed(2)}`, color: 'text-red-500' },
                                    { label: 'Médiane', value: `$${stats.price_median?.toFixed(2)}`, color: 'text-amber-600' },
                                    { label: 'Moyenne', value: `$${stats.price_avg?.toFixed(2)}`, color: 'text-blue-600' },
                                ].map(s => (
                                    <div key={s.label} className="bg-gray-50 rounded-xl p-3 text-center">
                                        <p className="text-xs text-gray-400 mb-1">{s.label}</p>
                                        <p className={`text-lg font-bold ${s.color}`}>{s.value}</p>
                                    </div>
                                ))}
                            </div>

                            {/* Positionnement relatif */}
                            <div className="mt-4 p-3 rounded-xl bg-blue-50 border border-blue-100">
                                {(() => {
                                    const price = parseFloat(product.price);
                                    const diff = price - stats.price_median;
                                    const pct = ((diff / stats.price_median) * 100).toFixed(1);
                                    const cheaper = diff < 0;
                                    return (
                                        <p className="text-sm text-blue-800">
                                            Ce produit est{' '}
                                            <span className={`font-bold ${cheaper ? 'text-green-600' : 'text-red-500'}`}>
                                                {cheaper ? `${Math.abs(pct)}% moins cher` : `${pct}% plus cher`}
                                            </span>{' '}
                                            que la médiane de sa catégorie.
                                        </p>
                                    );
                                })()}
                            </div>
                        </div>

                        {/* Concurrents */}
                        {competitors?.length > 0 && (
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                                <h3 className="font-semibold text-gray-800 mb-3">
                                    Concurrents proches
                                    <span className="text-xs text-gray-400 font-normal ml-2">(prix les + similaires)</span>
                                </h3>
                                <div className="divide-y divide-gray-50">
                                    {competitors.map(c => (
                                        <CompetitorRow
                                            key={c.id}
                                            product={c}
                                            targetPrice={product.price}
                                            onSelectProduct={loadCompare}
                                        />
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* État initial */}
            {!loading && !compareData && (
                <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-16 text-center">
                    <ChartBarIcon className="h-16 w-16 text-gray-200 mx-auto mb-4" />
                    <p className="text-gray-400 font-medium">Recherchez un produit pour lancer la comparaison</p>
                    <p className="text-sm text-gray-300 mt-1">Entrez au moins 2 caractères dans la barre de recherche</p>
                </div>
            )}
        </div>
    );
}
