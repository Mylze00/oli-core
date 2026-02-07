import { useEffect, useState, useCallback } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
    MagnifyingGlassIcon,
    UserGroupIcon,
    ShieldCheckIcon,
    TruckIcon,
    NoSymbolIcon,
    CheckBadgeIcon,
    ChevronLeftIcon,
    ChevronRightIcon,
    SparklesIcon,
} from '@heroicons/react/24/outline';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

// Twitter/X-style Scalloped Verification Badge
const VerificationBadge = ({ type = 'blue', size = 18 }) => {
    const colors = {
        blue: '#1DA1F2',
        gold: '#D4A500',
        gray: '#71767B',
        green: '#00BA7C',
    };
    const color = colors[type] || colors.blue;
    return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
            <path d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5c-1.51 0-2.816.917-3.437 2.25-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484z" fill={color} />
            <path d="M9.5 16.5L5.5 12.5l1.41-1.41L9.5 13.67l7.09-7.09L18 8l-8.5 8.5z" fill="white" />
        </svg>
    );
};

const FILTERS = [
    { key: 'all', label: 'Tous', icon: UserGroupIcon, color: 'blue' },
    { key: 'seller', label: 'Vendeurs', icon: ShieldCheckIcon, color: 'indigo' },
    { key: 'deliverer', label: 'Livreurs', icon: TruckIcon, color: 'emerald' },
    { key: 'admin', label: 'Admins', icon: SparklesIcon, color: 'red' },
    { key: 'verified', label: 'Vérifiés', icon: CheckBadgeIcon, color: 'sky' },
    { key: 'suspended', label: 'Suspendus', icon: NoSymbolIcon, color: 'rose' },
];

const PAGE_SIZE = 30;

export default function Users() {
    const [users, setUsers] = useState([]);
    const [total, setTotal] = useState(0);
    const [stats, setStats] = useState({});
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [activeFilter, setActiveFilter] = useState('all');
    const [page, setPage] = useState(0);
    const [searchParams] = useSearchParams();

    useEffect(() => {
        const searchFromUrl = searchParams.get('search');
        if (searchFromUrl) setSearch(searchFromUrl);
    }, [searchParams]);

    useEffect(() => {
        fetchUsers();
    }, [activeFilter, page]);

    // Debounced search
    useEffect(() => {
        const timer = setTimeout(() => {
            setPage(0);
            fetchUsers();
        }, 400);
        return () => clearTimeout(timer);
    }, [search]);

    const fetchUsers = async () => {
        setLoading(true);
        try {
            const params = new URLSearchParams();
            params.set('limit', PAGE_SIZE);
            params.set('offset', page * PAGE_SIZE);
            if (search) params.set('search', search);
            if (activeFilter === 'suspended') {
                params.set('status', 'suspended');
            } else if (activeFilter !== 'all') {
                params.set('role', activeFilter);
            }

            const { data } = await api.get(`/admin/users?${params.toString()}`);
            setUsers(data.users || data);
            setTotal(data.total || (data.users || data).length);
            if (data.stats) setStats(data.stats);
        } catch (error) {
            console.error("Erreur users:", error);
        } finally {
            setLoading(false);
        }
    };

    const handlePromote = async (userId, role, currentValue) => {
        if (!window.confirm(`Voulez-vous changer le rôle ${role} ?`)) return;
        try {
            await api.patch(`/admin/users/${userId}/role`, { [role]: !currentValue });
            fetchUsers();
        } catch (error) {
            console.error("Erreur update role:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const handleSuspend = async (user) => {
        const action = user.is_suspended ? "débloquer" : "suspendre";
        if (!window.confirm(`Voulez-vous vraiment ${action} ${user.name || "cet utilisateur"} ?`)) return;
        try {
            await api.post(`/admin/users/${user.id}/suspend`, { suspended: !user.is_suspended });
            setUsers(users.map(u =>
                u.id === user.id ? { ...u, is_suspended: !u.is_suspended } : u
            ));
        } catch (error) {
            console.error("Erreur suspend:", error);
            alert("Erreur lors de la suspension");
        }
    };

    const totalPages = Math.ceil(total / PAGE_SIZE);

    const getStatForFilter = (key) => {
        if (key === 'all') return stats.total || 0;
        if (key === 'seller') return stats.sellers || 0;
        if (key === 'deliverer') return stats.deliverers || 0;
        if (key === 'admin') return stats.admins || 0;
        if (key === 'verified') return stats.verified || 0;
        if (key === 'suspended') return stats.suspended || 0;
        return 0;
    };

    const getBadgeType = (user) => {
        if (user.has_certified_shop) return 'gold';
        if (user.account_type === 'entreprise') return 'gold';
        if (user.account_type === 'premium') return 'green';
        if (user.account_type === 'certifie' || user.is_verified) return 'blue';
        return null;
    };

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* ── Header ── */}
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-6 gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Gestion Utilisateurs</h1>
                    <p className="text-sm text-gray-500 mt-1">
                        {stats.total || 0} utilisateurs · {stats.new_this_week || 0} nouveaux cette semaine
                    </p>
                </div>
            </div>

            {/* ── Stats pills ── */}
            <div className="flex flex-wrap gap-2 mb-6">
                {FILTERS.map(f => {
                    const count = getStatForFilter(f.key);
                    const isActive = activeFilter === f.key;
                    return (
                        <button
                            key={f.key}
                            onClick={() => { setActiveFilter(f.key); setPage(0); }}
                            className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all ${isActive
                                    ? `bg-${f.color}-600 text-white shadow-md`
                                    : 'bg-white text-gray-600 hover:bg-gray-100 border border-gray-200'
                                }`}
                            style={isActive ? {
                                backgroundColor: f.color === 'blue' ? '#2563eb' :
                                    f.color === 'indigo' ? '#4f46e5' :
                                        f.color === 'emerald' ? '#059669' :
                                            f.color === 'red' ? '#dc2626' :
                                                f.color === 'sky' ? '#0284c7' :
                                                    f.color === 'rose' ? '#e11d48' : '#2563eb',
                                color: 'white'
                            } : {}}
                        >
                            <f.icon className="h-4 w-4" />
                            {f.label}
                            <span className={`px-1.5 py-0.5 rounded-full text-xs font-bold ${isActive ? 'bg-white/20 text-white' : 'bg-gray-100 text-gray-500'
                                }`}>
                                {count}
                            </span>
                        </button>
                    );
                })}
            </div>

            {/* ── Recherche ── */}
            <div className="mb-6">
                <div className="relative max-w-md">
                    <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                    <input
                        type="text"
                        placeholder="Rechercher par nom, téléphone, ID Oli..."
                        className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent shadow-sm"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
            </div>

            {/* ── Table ── */}
            <div className="bg-white shadow-sm rounded-2xl border border-gray-100 overflow-hidden">
                {loading ? (
                    <div className="flex justify-center items-center h-40">
                        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                    </div>
                ) : (
                    <>
                        <div className="overflow-x-auto">
                            <table className="min-w-full divide-y divide-gray-100">
                                <thead className="bg-gray-50">
                                    <tr>
                                        <th className="px-6 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Utilisateur</th>
                                        <th className="px-6 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Rôles</th>
                                        <th className="px-6 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Portefeuille</th>
                                        <th className="px-6 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Inscrit le</th>
                                        <th className="px-6 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</th>
                                    </tr>
                                </thead>
                                <tbody className="bg-white divide-y divide-gray-50">
                                    {users.length === 0 ? (
                                        <tr>
                                            <td colSpan={5} className="px-6 py-12 text-center text-gray-400">
                                                Aucun utilisateur trouvé
                                            </td>
                                        </tr>
                                    ) : users.map((user) => {
                                        const badgeType = getBadgeType(user);
                                        return (
                                            <tr key={user.id} className="hover:bg-gray-50 transition-colors">
                                                <td className="px-6 py-4 whitespace-nowrap">
                                                    <Link to={`/users/${user.id}`} className="flex items-center group cursor-pointer">
                                                        <div className="flex-shrink-0 h-10 w-10 relative">
                                                            <img
                                                                className="h-10 w-10 rounded-full object-cover border-2 border-gray-200"
                                                                src={getImageUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`}
                                                                alt=""
                                                                onError={(e) => {
                                                                    e.target.onerror = null;
                                                                    e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`;
                                                                }}
                                                            />
                                                            {badgeType && (
                                                                <div className="absolute -bottom-1 -right-1">
                                                                    <VerificationBadge type={badgeType} size={16} />
                                                                </div>
                                                            )}
                                                        </div>
                                                        <div className="ml-3">
                                                            <div className="text-sm font-medium text-gray-900 group-hover:text-blue-600 transition-colors">
                                                                {user.name || 'Sans nom'}
                                                            </div>
                                                            <div className="text-xs text-gray-400">{user.phone}</div>
                                                        </div>
                                                    </Link>
                                                </td>
                                                <td className="px-6 py-4 whitespace-nowrap">
                                                    <div className="flex flex-wrap gap-1">
                                                        {user.is_admin && <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-red-100 text-red-700">Admin</span>}
                                                        {user.is_seller && <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-blue-100 text-blue-700">Vendeur</span>}
                                                        {user.is_deliverer && <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-emerald-100 text-emerald-700">Livreur</span>}
                                                        {user.account_type && user.account_type !== 'ordinaire' && (
                                                            <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${user.account_type === 'certifie' ? 'bg-sky-100 text-sky-700' :
                                                                    user.account_type === 'entreprise' ? 'bg-amber-100 text-amber-700' :
                                                                        user.account_type === 'premium' ? 'bg-violet-100 text-violet-700' :
                                                                            'bg-gray-100 text-gray-600'
                                                                }`}>
                                                                {user.account_type === 'certifie' ? 'Certifié' :
                                                                    user.account_type === 'entreprise' ? 'Entreprise' :
                                                                        user.account_type === 'premium' ? 'Premium' : user.account_type}
                                                            </span>
                                                        )}
                                                        {user.has_certified_shop && (
                                                            <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-amber-100 text-amber-700">🏪 Boutique</span>
                                                        )}
                                                        {user.is_suspended && (
                                                            <span className="px-2 py-0.5 text-xs font-bold rounded-full bg-red-600 text-white">SUSPENDU</span>
                                                        )}
                                                    </div>
                                                </td>
                                                <td className="px-6 py-4 whitespace-nowrap">
                                                    <span className="text-sm font-medium text-gray-900">{parseFloat(user.wallet || 0).toFixed(2)} $</span>
                                                </td>
                                                <td className="px-6 py-4 whitespace-nowrap">
                                                    <span className="text-sm text-gray-500">
                                                        {user.created_at ? new Date(user.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }) : '—'}
                                                    </span>
                                                </td>
                                                <td className="px-6 py-4 whitespace-nowrap">
                                                    <div className="flex items-center gap-2">
                                                        <button
                                                            onClick={() => handlePromote(user.id, 'is_admin', user.is_admin)}
                                                            className="text-xs font-medium text-indigo-600 hover:text-indigo-800 hover:underline"
                                                        >
                                                            {user.is_admin ? '✕ Admin' : '+ Admin'}
                                                        </button>
                                                        <span className="text-gray-300">|</span>
                                                        <button
                                                            onClick={() => handleSuspend(user)}
                                                            className={`text-xs font-semibold px-3 py-1 rounded-full transition-colors ${user.is_suspended
                                                                    ? 'bg-green-100 text-green-700 hover:bg-green-200'
                                                                    : 'bg-red-50 text-red-600 hover:bg-red-100'
                                                                }`}
                                                        >
                                                            {user.is_suspended ? 'Débloquer' : 'Suspendre'}
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        );
                                    })}
                                </tbody>
                            </table>
                        </div>

                        {/* ── Pagination ── */}
                        {totalPages > 1 && (
                            <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-between">
                                <p className="text-sm text-gray-500">
                                    {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} sur {total} utilisateurs
                                </p>
                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={() => setPage(Math.max(0, page - 1))}
                                        disabled={page === 0}
                                        className="p-2 rounded-lg border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed transition"
                                    >
                                        <ChevronLeftIcon className="h-4 w-4 text-gray-600" />
                                    </button>
                                    <span className="text-sm font-medium text-gray-700 px-3">
                                        {page + 1} / {totalPages}
                                    </span>
                                    <button
                                        onClick={() => setPage(Math.min(totalPages - 1, page + 1))}
                                        disabled={page >= totalPages - 1}
                                        className="p-2 rounded-lg border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed transition"
                                    >
                                        <ChevronRightIcon className="h-4 w-4 text-gray-600" />
                                    </button>
                                </div>
                            </div>
                        )}
                    </>
                )}
            </div>
        </div>
    );
}
