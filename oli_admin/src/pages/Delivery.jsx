import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    TruckIcon,
    CheckBadgeIcon,
    NoSymbolIcon,
    UserGroupIcon,
    MagnifyingGlassIcon,
    CheckCircleIcon,
    XCircleIcon,
    ShieldCheckIcon,
} from '@heroicons/react/24/solid';

function StatCard({ label, value, icon: Icon, color }) {
    const c = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        red: 'bg-red-50 text-red-600',
        amber: 'bg-amber-50 text-amber-600',
    };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-3 mb-2">
                <div className={`p-2 rounded-lg ${c[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
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

export default function Delivery() {
    const [drivers, setDrivers] = useState([]);
    const [stats, setStats] = useState({ total: 0, active: 0, verified: 0, suspended: 0 });
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');

    useEffect(() => { fetchDrivers(); }, []);

    const fetchDrivers = async () => {
        try {
            const { data } = await api.get('/admin/delivery/drivers?limit=200');
            setDrivers(data.drivers || []);
            if (data.stats) setStats(data.stats);
        } catch (error) {
            console.error("Erreur livreurs:", error);
        } finally {
            setLoading(false);
        }
    };

    const toggleSuspend = async (driver) => {
        const action = driver.is_suspended ? 'réactiver' : 'suspendre';
        if (!window.confirm(`Voulez-vous ${action} ce livreur ?`)) return;
        try {
            const { data } = await api.patch(`/admin/delivery/drivers/${driver.id}/toggle`);
            setDrivers(drivers.map(d => d.id === driver.id ? { ...d, is_suspended: data.is_suspended } : d));
        } catch (err) { console.error(err); alert("Erreur"); }
    };

    const toggleVerify = async (driver) => {
        try {
            const { data } = await api.patch(`/admin/delivery/drivers/${driver.id}/verify`);
            setDrivers(drivers.map(d => d.id === driver.id ? { ...d, is_verified: data.is_verified } : d));
        } catch (err) { console.error(err); alert("Erreur"); }
    };

    const filteredDrivers = useMemo(() => {
        let list = drivers;
        if (filter === 'active') list = list.filter(d => !d.is_suspended);
        if (filter === 'verified') list = list.filter(d => d.is_verified);
        if (filter === 'suspended') list = list.filter(d => d.is_suspended);
        if (search) {
            const s = search.toLowerCase();
            list = list.filter(d =>
                d.name?.toLowerCase().includes(s) ||
                d.phone?.includes(s) ||
                d.email?.toLowerCase().includes(s)
            );
        }
        return list;
    }, [drivers, filter, search]);

    const timeAgo = (date) => {
        if (!date) return 'Jamais';
        const diff = Date.now() - new Date(date).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 60) return `${mins} min`;
        const hours = Math.floor(mins / 60);
        if (hours < 24) return `${hours}h`;
        const days = Math.floor(hours / 24);
        return `${days}j`;
    };

    if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Livreurs</h1>
                    <p className="text-sm text-gray-400 mt-1">Gestion et suivi des livreurs partenaires</p>
                </div>
                <div className="relative">
                    <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input type="text" placeholder="Rechercher nom, téléphone..."
                        className="pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm w-72 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <StatCard label="Total" value={stats.total} icon={UserGroupIcon} color="blue" />
                <StatCard label="Actifs" value={stats.active} icon={TruckIcon} color="green" />
                <StatCard label="Vérifiés" value={stats.verified} icon={CheckBadgeIcon} color="amber" />
                <StatCard label="Suspendus" value={stats.suspended} icon={NoSymbolIcon} color="red" />
            </div>

            {/* Filters */}
            <div className="flex gap-2 flex-wrap">
                <FilterPill label="Tous" count={stats.total} active={filter === 'all'} onClick={() => setFilter('all')} />
                <FilterPill label="✓ Actifs" count={stats.active} active={filter === 'active'} onClick={() => setFilter('active')} />
                <FilterPill label="✅ Vérifiés" count={stats.verified} active={filter === 'verified'} onClick={() => setFilter('verified')} />
                <FilterPill label="⛔ Suspendus" count={stats.suspended} active={filter === 'suspended'} onClick={() => setFilter('suspended')} />
            </div>

            {/* Drivers Table */}
            {filteredDrivers.length === 0 ? (
                <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
                    <TruckIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                    <p className="text-gray-500 font-medium">Aucun livreur trouvé</p>
                    <p className="text-gray-400 text-sm mt-1">Les utilisateurs avec le rôle "livreur" apparaîtront ici</p>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    {/* Table Header */}
                    <div className="grid grid-cols-12 gap-4 px-6 py-4 bg-gray-50 border-b border-gray-100 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                        <div className="col-span-3">Livreur</div>
                        <div className="col-span-2 text-center">Livraisons</div>
                        <div className="col-span-1 text-center">En cours</div>
                        <div className="col-span-1 text-center">Vérifié</div>
                        <div className="col-span-1 text-center">Statut</div>
                        <div className="col-span-2 text-center">Dernière activité</div>
                        <div className="col-span-2 text-center">Actions</div>
                    </div>

                    {/* Driver Rows */}
                    <div className="divide-y divide-gray-50">
                        {filteredDrivers.map((driver) => (
                            <div key={driver.id} className="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-gray-50 transition">
                                {/* Livreur */}
                                <div className="col-span-3">
                                    <Link to={`/users/${driver.id}`} className="flex items-center gap-3 hover:opacity-80 transition">
                                        <img
                                            src={driver.avatar_url || `https://ui-avatars.com/api/?name=${driver.name || 'L'}&background=0B1727&color=fff&size=64`}
                                            className="w-10 h-10 rounded-full object-cover flex-shrink-0 border border-gray-100"
                                            alt=""
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${driver.name || 'L'}&background=0B1727&color=fff`; }}
                                        />
                                        <div className="min-w-0">
                                            <p className="text-sm font-semibold text-blue-600 truncate">{driver.name || 'Sans nom'}</p>
                                            <p className="text-xs text-gray-400 truncate">{driver.phone}</p>
                                        </div>
                                    </Link>
                                </div>

                                {/* Livraisons terminées */}
                                <div className="col-span-2 text-center">
                                    <p className="text-sm font-bold text-gray-900">{driver.completed_deliveries || 0}</p>
                                    <p className="text-xs text-gray-400">terminées</p>
                                </div>

                                {/* En cours */}
                                <div className="col-span-1 text-center">
                                    {parseInt(driver.active_deliveries) > 0 ? (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-700">{driver.active_deliveries}</span>
                                    ) : (
                                        <span className="text-xs text-gray-300">0</span>
                                    )}
                                </div>

                                {/* Vérifié */}
                                <div className="col-span-1 text-center">
                                    {driver.is_verified ? (
                                        <CheckBadgeIcon className="h-5 w-5 text-green-500 mx-auto" />
                                    ) : (
                                        <span className="text-xs text-gray-300">—</span>
                                    )}
                                </div>

                                {/* Statut */}
                                <div className="col-span-1 text-center">
                                    {driver.is_suspended ? (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-700">Suspendu</span>
                                    ) : (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-700">Actif</span>
                                    )}
                                </div>

                                {/* Dernière activité */}
                                <div className="col-span-2 text-center">
                                    <p className="text-xs text-gray-400">
                                        {driver.last_active ? `Il y a ${timeAgo(driver.last_active)}` : 'Jamais connecté'}
                                    </p>
                                </div>

                                {/* Actions */}
                                <div className="col-span-2 flex justify-center gap-1.5">
                                    <button onClick={() => toggleVerify(driver)}
                                        className={`p-2 rounded-lg transition ${driver.is_verified ? 'bg-green-100 text-green-600 hover:bg-green-200' : 'bg-gray-100 text-gray-400 hover:bg-gray-200'}`}
                                        title={driver.is_verified ? 'Retirer vérification' : 'Vérifier'}
                                    >
                                        <ShieldCheckIcon className="h-4 w-4" />
                                    </button>
                                    <button onClick={() => toggleSuspend(driver)}
                                        className={`p-2 rounded-lg transition ${driver.is_suspended ? 'bg-amber-100 text-amber-600 hover:bg-amber-200' : 'bg-gray-100 text-red-400 hover:bg-red-100 hover:text-red-600'}`}
                                        title={driver.is_suspended ? 'Réactiver' : 'Suspendre'}
                                    >
                                        {driver.is_suspended ? (
                                            <CheckCircleIcon className="h-4 w-4" />
                                        ) : (
                                            <XCircleIcon className="h-4 w-4" />
                                        )}
                                    </button>
                                    <Link to={`/users/${driver.id}`}
                                        className="p-2 rounded-lg bg-gray-100 text-blue-500 hover:bg-blue-100 transition"
                                        title="Voir profil"
                                    >
                                        <UserGroupIcon className="h-4 w-4" />
                                    </Link>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Footer */}
                    <div className="px-6 py-3 bg-gray-50 border-t border-gray-100 text-xs text-gray-400 text-right">
                        {filteredDrivers.length} livreur{filteredDrivers.length > 1 ? 's' : ''} affiché{filteredDrivers.length > 1 ? 's' : ''}
                    </div>
                </div>
            )}
        </div>
    );
}
