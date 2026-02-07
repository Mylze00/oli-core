import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    CheckBadgeIcon,
    BuildingStorefrontIcon,
    ShoppingBagIcon,
    StarIcon,
    MapPinIcon,
    MagnifyingGlassIcon,
    TagIcon,
    CubeIcon,
    ChartBarIcon,
} from '@heroicons/react/24/solid';

// ═══════════════════════════════════
// ══  STAT CARD
// ═══════════════════════════════════
function StatCard({ label, value, icon: Icon, color, subtitle }) {
    const colors = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        amber: 'bg-amber-50 text-amber-600',
        purple: 'bg-purple-50 text-purple-600',
        rose: 'bg-rose-50 text-rose-600',
    };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
            <div className="flex items-center gap-3 mb-2">
                <div className={`p-2 rounded-lg ${colors[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
    );
}

// ═══════════════════════════════════
// ══  FILTER PILL
// ═══════════════════════════════════
function FilterPill({ label, count, active, onClick }) {
    return (
        <button
            onClick={onClick}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2 ${active
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
        >
            {label}
            {count !== undefined && (
                <span className={`text-xs px-1.5 py-0.5 rounded-full ${active ? 'bg-white/20 text-white' : 'bg-gray-200 text-gray-500'}`}>
                    {count}
                </span>
            )}
        </button>
    );
}

// ═══════════════════════════════════
// ══  MAIN: SHOPS PAGE
// ═══════════════════════════════════
export default function Shops() {
    const [shops, setShops] = useState([]);
    const [stats, setStats] = useState({ total: 0, certified: 0, pending: 0, total_products: 0, total_sales: 0 });
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');

    useEffect(() => { fetchShops(); }, [filter]);

    const fetchShops = async () => {
        try {
            let url = '/admin/shops';
            if (filter === 'verified') url += '?verified=true';
            if (filter === 'pending') url += '?verified=false';
            const { data } = await api.get(url);

            // Support both old format (array) and new format (object with shops + stats)
            if (Array.isArray(data)) {
                setShops(data);
            } else {
                setShops(data.shops || []);
                if (data.stats) setStats(data.stats);
            }
        } catch (error) {
            console.error("Erreur shops:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleCertify = async (shopId, currentValue) => {
        const newValue = !currentValue;
        if (!window.confirm(`${newValue ? 'Certifier' : 'Retirer la certification de'} cette boutique ?`)) return;
        try {
            await api.patch(`/admin/shops/${shopId}/certify`, { certified: newValue });
            fetchShops();
        } catch (error) {
            console.error("Erreur certification:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const filteredShops = useMemo(() =>
        shops.filter(s =>
            !search ||
            s.name?.toLowerCase().includes(search.toLowerCase()) ||
            s.owner_name?.toLowerCase().includes(search.toLowerCase()) ||
            s.owner_phone?.includes(search) ||
            s.category?.toLowerCase().includes(search.toLowerCase()) ||
            s.location?.toLowerCase().includes(search.toLowerCase())
        ),
        [shops, search]
    );

    if (loading) return (
        <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
    );

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* ── Header ── */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Boutiques & Marchands</h1>
                    <p className="text-sm text-gray-400 mt-1">Gestion et certification des boutiques de la plateforme</p>
                </div>
                <div className="relative">
                    <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                        type="text"
                        placeholder="Rechercher nom, propriétaire, catégorie, ville..."
                        className="pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm w-80 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
            </div>

            {/* ── Stats Cards ── */}
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                <StatCard label="Total Boutiques" value={stats.total} icon={BuildingStorefrontIcon} color="blue" />
                <StatCard label="Certifiées" value={stats.certified} icon={CheckBadgeIcon} color="green" subtitle={stats.total > 0 ? `${Math.round(stats.certified / stats.total * 100)}% du total` : ''} />
                <StatCard label="En attente" value={stats.pending} icon={ShoppingBagIcon} color="amber" />
                <StatCard label="Produits" value={stats.total_products} icon={CubeIcon} color="purple" subtitle="Sur toute la plateforme" />
                <StatCard label="Ventes" value={stats.total_sales} icon={ChartBarIcon} color="rose" subtitle="Totales réalisées" />
            </div>

            {/* ── Filter Pills ── */}
            <div className="flex gap-2 flex-wrap">
                <FilterPill label="Toutes" count={stats.total} active={filter === 'all'} onClick={() => setFilter('all')} />
                <FilterPill label="✓ Certifiées" count={stats.certified} active={filter === 'verified'} onClick={() => setFilter('verified')} />
                <FilterPill label="⏳ En attente" count={stats.pending} active={filter === 'pending'} onClick={() => setFilter('pending')} />
            </div>

            {/* ── Shops Grid ── */}
            {filteredShops.length === 0 ? (
                <div className="bg-white rounded-2xl p-12 text-center border border-gray-100 shadow-sm">
                    <BuildingStorefrontIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                    <p className="text-gray-500 font-medium">Aucune boutique trouvée</p>
                    <p className="text-sm text-gray-400 mt-1">Essayez de modifier vos filtres ou votre recherche</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
                    {filteredShops.map((shop) => (
                        <div key={shop.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-lg transition-all group">
                            {/* Banner */}
                            <div className="h-28 bg-gradient-to-r from-blue-500 via-indigo-500 to-purple-500 relative">
                                {shop.banner_url && (
                                    <img
                                        src={shop.banner_url}
                                        alt=""
                                        className="w-full h-full object-cover"
                                        onError={(e) => { e.target.style.display = 'none'; }}
                                    />
                                )}
                                {/* Certification badge top-right */}
                                <div className="absolute top-3 right-3">
                                    {shop.is_verified ? (
                                        <span className="bg-green-500/90 backdrop-blur-sm text-white text-xs font-bold px-3 py-1 rounded-full flex items-center gap-1 shadow-sm">
                                            <CheckBadgeIcon className="h-3.5 w-3.5" /> Certifié
                                        </span>
                                    ) : (
                                        <span className="bg-white/20 backdrop-blur-sm text-white text-xs font-medium px-3 py-1 rounded-full border border-white/30">
                                            En attente
                                        </span>
                                    )}
                                </div>
                            </div>

                            {/* Content */}
                            <div className="px-5 pb-5 relative">
                                {/* Logo (overlaps banner) */}
                                <div className="flex items-end gap-4 -mt-8 mb-3">
                                    <div className="flex-shrink-0">
                                        <img
                                            src={shop.logo_url || getImageUrl(shop.logo_url) || `https://ui-avatars.com/api/?name=${shop.name || 'S'}&background=4F46E5&color=fff&size=128`}
                                            alt={shop.name}
                                            className="w-16 h-16 rounded-2xl border-4 border-white shadow-md object-cover bg-white"
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.name || 'S'}&background=4F46E5&color=fff`; }}
                                        />
                                    </div>
                                    <div className="flex-1 min-w-0 pb-1">
                                        <h3 className="font-bold text-gray-900 truncate text-base group-hover:text-blue-600 transition">{shop.name || 'Sans nom'}</h3>
                                        {shop.category && (
                                            <span className="inline-flex items-center text-xs text-gray-500">
                                                <TagIcon className="h-3 w-3 mr-1 text-gray-400" />{shop.category}
                                            </span>
                                        )}
                                    </div>
                                </div>

                                {/* Location & Rating */}
                                <div className="flex items-center justify-between mb-4">
                                    <span className="text-xs text-gray-400 flex items-center">
                                        <MapPinIcon className="h-3.5 w-3.5 mr-1 text-gray-300" />{shop.location || 'Non renseigné'}
                                    </span>
                                    {shop.rating && (
                                        <span className="text-xs flex items-center text-amber-500 bg-amber-50 px-2 py-0.5 rounded-full font-medium">
                                            <StarIcon className="h-3.5 w-3.5 mr-0.5" />{parseFloat(shop.rating).toFixed(1)}
                                        </span>
                                    )}
                                </div>

                                {/* Mini Stats */}
                                <div className="grid grid-cols-3 gap-2 mb-4">
                                    <div className="text-center p-2.5 bg-gray-50 rounded-xl">
                                        <p className="text-lg font-bold text-gray-900">{shop.products_count || 0}</p>
                                        <p className="text-[10px] text-gray-400 uppercase tracking-wide">Produits</p>
                                    </div>
                                    <div className="text-center p-2.5 bg-gray-50 rounded-xl">
                                        <p className="text-lg font-bold text-gray-900">{shop.total_sales || 0}</p>
                                        <p className="text-[10px] text-gray-400 uppercase tracking-wide">Ventes</p>
                                    </div>
                                    <div className="text-center p-2.5 bg-gray-50 rounded-xl">
                                        <p className="text-lg font-bold text-gray-900">{shop.active_products || 0}</p>
                                        <p className="text-[10px] text-gray-400 uppercase tracking-wide">Actifs</p>
                                    </div>
                                </div>

                                {/* Owner */}
                                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-xl mb-4">
                                    <Link to={`/users/${shop.owner_id}`} className="flex items-center gap-3 hover:opacity-80 transition">
                                        <img
                                            src={getImageUrl(shop.owner_avatar) || `https://ui-avatars.com/api/?name=${shop.owner_name || 'U'}&background=0B1727&color=fff&size=64`}
                                            alt={shop.owner_name}
                                            className="w-9 h-9 rounded-full object-cover"
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.owner_name || 'U'}&background=0B1727&color=fff`; }}
                                        />
                                        <div>
                                            <p className="text-sm font-medium text-gray-900">{shop.owner_name || 'Inconnu'}</p>
                                            <p className="text-xs text-gray-400">{shop.owner_phone}</p>
                                        </div>
                                    </Link>
                                    <span className="text-[10px] text-gray-300">Propriétaire</span>
                                </div>

                                {/* Actions */}
                                <div className="flex gap-2">
                                    <button
                                        onClick={() => handleCertify(shop.id, shop.is_verified)}
                                        className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${shop.is_verified
                                                ? 'bg-red-50 text-red-600 hover:bg-red-100 border border-red-100'
                                                : 'bg-green-600 text-white hover:bg-green-700 shadow-sm'
                                            }`}
                                    >
                                        <CheckBadgeIcon className="h-4 w-4 inline mr-1.5" />
                                        {shop.is_verified ? 'Retirer certification' : 'Certifier'}
                                    </button>
                                    <Link
                                        to={`/users/${shop.owner_id}`}
                                        className="px-4 py-2.5 rounded-xl text-sm font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition"
                                    >
                                        Profil
                                    </Link>
                                </div>

                                {/* Created date */}
                                <p className="text-[10px] text-gray-300 text-center mt-3">
                                    Créée le {shop.created_at ? new Date(shop.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' }) : '—'}
                                </p>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
