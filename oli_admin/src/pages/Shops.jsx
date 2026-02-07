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

function StatCard({ label, value, icon: Icon, color, subtitle }) {
    const c = { blue: 'bg-blue-50 text-blue-600', green: 'bg-green-50 text-green-600', amber: 'bg-amber-50 text-amber-600', purple: 'bg-purple-50 text-purple-600', rose: 'bg-rose-50 text-rose-600' };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-3 mb-2">
                <div className={`p-2 rounded-lg ${c[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
    );
}

function FilterPill({ label, count, active, onClick }) {
    return (
        <button onClick={onClick}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2 ${active ? 'bg-blue-600 text-white shadow-sm' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
        >
            {label}
            {count !== undefined && (
                <span className={`text-xs px-1.5 py-0.5 rounded-full ${active ? 'bg-white/20' : 'bg-gray-200 text-gray-500'}`}>{count}</span>
            )}
        </button>
    );
}

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
            if (Array.isArray(data)) { setShops(data); }
            else { setShops(data.shops || []); if (data.stats) setStats(data.stats); }
        } catch (error) { console.error("Erreur shops:", error); }
        finally { setLoading(false); }
    };

    const handleCertify = async (shopId, currentValue) => {
        const newValue = !currentValue;
        if (!window.confirm(`${newValue ? 'Certifier' : 'Retirer la certification de'} cette boutique ?`)) return;
        try { await api.patch(`/admin/shops/${shopId}/certify`, { certified: newValue }); fetchShops(); }
        catch (error) { console.error("Erreur certification:", error); alert("Erreur lors de la mise à jour"); }
    };

    const filteredShops = useMemo(() =>
        shops.filter(s => !search ||
            s.name?.toLowerCase().includes(search.toLowerCase()) ||
            s.owner_name?.toLowerCase().includes(search.toLowerCase()) ||
            s.owner_phone?.includes(search) ||
            s.category?.toLowerCase().includes(search.toLowerCase()) ||
            s.location?.toLowerCase().includes(search.toLowerCase())
        ), [shops, search]
    );

    if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Boutiques & Marchands</h1>
                    <p className="text-sm text-gray-400 mt-1">Gestion et certification des boutiques</p>
                </div>
                <div className="relative">
                    <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input type="text" placeholder="Rechercher nom, propriétaire, catégorie..."
                        className="pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm w-80 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                <StatCard label="Total" value={stats.total} icon={BuildingStorefrontIcon} color="blue" />
                <StatCard label="Certifiées" value={stats.certified} icon={CheckBadgeIcon} color="green" subtitle={stats.total > 0 ? `${Math.round(stats.certified / stats.total * 100)}% du total` : ''} />
                <StatCard label="En attente" value={stats.pending} icon={ShoppingBagIcon} color="amber" />
                <StatCard label="Produits" value={stats.total_products} icon={CubeIcon} color="purple" />
                <StatCard label="Ventes" value={stats.total_sales} icon={ChartBarIcon} color="rose" />
            </div>

            {/* Filters */}
            <div className="flex gap-2 flex-wrap">
                <FilterPill label="Toutes" count={stats.total} active={filter === 'all'} onClick={() => setFilter('all')} />
                <FilterPill label="✓ Certifiées" count={stats.certified} active={filter === 'verified'} onClick={() => setFilter('verified')} />
                <FilterPill label="⏳ En attente" count={stats.pending} active={filter === 'pending'} onClick={() => setFilter('pending')} />
            </div>

            {/* Shops List */}
            {filteredShops.length === 0 ? (
                <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
                    <BuildingStorefrontIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                    <p className="text-gray-500 font-medium">Aucune boutique trouvée</p>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    {/* Table Header */}
                    <div className="grid grid-cols-12 gap-4 px-6 py-4 bg-gray-50 border-b border-gray-100 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                        <div className="col-span-4">Boutique</div>
                        <div className="col-span-2">Propriétaire</div>
                        <div className="col-span-1 text-center">Produits</div>
                        <div className="col-span-1 text-center">Ventes</div>
                        <div className="col-span-1 text-center">Note</div>
                        <div className="col-span-1 text-center">Statut</div>
                        <div className="col-span-2 text-center">Actions</div>
                    </div>

                    {/* Shop Rows */}
                    <div className="divide-y divide-gray-50">
                        {filteredShops.map((shop) => (
                            <div key={shop.id} className="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-gray-50 transition">
                                {/* Boutique Info */}
                                <div className="col-span-4 flex items-center gap-4">
                                    <img
                                        src={shop.logo_url || `https://ui-avatars.com/api/?name=${shop.name || 'S'}&background=4F46E5&color=fff&size=128`}
                                        alt={shop.name}
                                        className="w-12 h-12 rounded-xl object-cover flex-shrink-0 border border-gray-100"
                                        onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.name || 'S'}&background=4F46E5&color=fff`; }}
                                    />
                                    <div className="min-w-0">
                                        <p className="font-semibold text-gray-900 truncate text-sm">{shop.name || 'Sans nom'}</p>
                                        <div className="flex items-center gap-2 mt-0.5">
                                            {shop.category && (
                                                <span className="text-xs text-gray-400 flex items-center">
                                                    <TagIcon className="h-3 w-3 mr-0.5" />{shop.category}
                                                </span>
                                            )}
                                            {shop.location && (
                                                <span className="text-xs text-gray-400 flex items-center">
                                                    <MapPinIcon className="h-3 w-3 mr-0.5" />{shop.location}
                                                </span>
                                            )}
                                        </div>
                                        <p className="text-[10px] text-gray-300 mt-0.5">
                                            {shop.created_at ? new Date(shop.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }) : '—'}
                                        </p>
                                    </div>
                                </div>

                                {/* Propriétaire */}
                                <div className="col-span-2">
                                    <Link to={`/users/${shop.owner_id}`} className="flex items-center gap-2 hover:opacity-80 transition">
                                        <img
                                            src={getImageUrl(shop.owner_avatar) || `https://ui-avatars.com/api/?name=${shop.owner_name || 'U'}&background=0B1727&color=fff&size=64`}
                                            className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                                            alt=""
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.owner_name || 'U'}&background=0B1727&color=fff`; }}
                                        />
                                        <div className="min-w-0">
                                            <p className="text-sm font-medium text-blue-600 truncate">{shop.owner_name || 'Inconnu'}</p>
                                            <p className="text-xs text-gray-400 truncate">{shop.owner_phone}</p>
                                        </div>
                                    </Link>
                                </div>

                                {/* Produits */}
                                <div className="col-span-1 text-center">
                                    <p className="text-sm font-bold text-gray-900">{shop.products_count || 0}</p>
                                    <p className="text-[10px] text-gray-400">{shop.active_products || 0} actifs</p>
                                </div>

                                {/* Ventes */}
                                <div className="col-span-1 text-center">
                                    <p className="text-sm font-bold text-gray-900">{shop.total_sales || 0}</p>
                                </div>

                                {/* Note */}
                                <div className="col-span-1 text-center">
                                    <span className="inline-flex items-center text-xs text-amber-600 bg-amber-50 px-2 py-1 rounded-full font-semibold">
                                        <StarIcon className="h-3 w-3 mr-0.5" />{shop.rating ? parseFloat(shop.rating).toFixed(1) : '—'}
                                    </span>
                                </div>

                                {/* Statut */}
                                <div className="col-span-1 text-center">
                                    {shop.is_verified ? (
                                        <span className="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-700">
                                            <CheckBadgeIcon className="h-3.5 w-3.5 mr-1" />Certifié
                                        </span>
                                    ) : (
                                        <span className="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-amber-100 text-amber-700">
                                            En attente
                                        </span>
                                    )}
                                </div>

                                {/* Actions */}
                                <div className="col-span-2 flex justify-center gap-2">
                                    <button
                                        onClick={() => handleCertify(shop.id, shop.is_verified)}
                                        className={`px-3 py-1.5 rounded-lg text-xs font-medium transition ${shop.is_verified
                                                ? 'bg-red-50 text-red-600 hover:bg-red-100 border border-red-100'
                                                : 'bg-green-600 text-white hover:bg-green-700'
                                            }`}
                                    >
                                        {shop.is_verified ? 'Retirer' : 'Certifier'}
                                    </button>
                                    <Link to={`/users/${shop.owner_id}`}
                                        className="px-3 py-1.5 rounded-lg text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition"
                                    >Profil</Link>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
}
