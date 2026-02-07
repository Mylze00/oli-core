import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    EnvelopeIcon,
    NoSymbolIcon,
    CheckCircleIcon,
    TagIcon,
    MapPinIcon,
    PhoneIcon,
    ChevronLeftIcon,
    ShoppingCartIcon,
    CurrencyDollarIcon,
    ChatBubbleLeftRightIcon,
    ShieldExclamationIcon,
    CalendarDaysIcon,
    BuildingStorefrontIcon,
} from '@heroicons/react/24/solid';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

// ── Tab Button ──
function TabButton({ label, active, onClick, icon: Icon }) {
    return (
        <button
            onClick={onClick}
            className={`px-5 py-3.5 text-sm font-medium border-b-2 transition-colors flex items-center gap-2 ${active
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
        >
            {Icon && <Icon className="h-4 w-4" />}
            {label}
        </button>
    );
}

// ── Stat Card (mini) ──
function MiniStat({ label, value, icon: Icon, color = 'blue', subtitle }) {
    const colors = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        amber: 'bg-amber-50 text-amber-600',
        purple: 'bg-purple-50 text-purple-600',
        rose: 'bg-rose-50 text-rose-600',
        indigo: 'bg-indigo-50 text-indigo-600',
    };
    return (
        <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
            <div className="flex items-center gap-3 mb-3">
                <div className={`p-2 rounded-lg ${colors[color]}`}>
                    <Icon className="h-5 w-5" />
                </div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
    );
}

// ── User Products Grid ──
function UserProducts({ userId, limit }) {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchProducts = async () => {
            try {
                const { data } = await api.get(`/admin/users/${userId}/products`);
                setProducts(limit ? data.slice(0, limit) : data);
            } catch (error) {
                console.error("Erreur loading user products", error);
            } finally {
                setLoading(false);
            }
        };
        fetchProducts();
    }, [userId, limit]);

    if (loading) return <div className="p-4 text-center text-gray-400">Chargement des produits...</div>;
    if (products.length === 0) {
        return <div className="p-8 text-center text-gray-400 bg-gray-50 rounded-xl border border-dashed border-gray-200">Aucun produit mis en vente par cet utilisateur.</div>;
    }

    return (
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map(product => (
                <div key={product.id} className="bg-white border border-gray-100 rounded-xl overflow-hidden shadow-sm hover:shadow-md transition">
                    <div className="h-40 bg-gray-100 relative">
                        <img
                            src={getImageUrl(product.image_url)}
                            alt={product.name}
                            className="w-full h-full object-cover"
                            onError={(e) => e.target.src = 'https://via.placeholder.com/300?text=No+Image'}
                        />
                        <span className={`absolute top-2 right-2 px-2 py-1 text-xs rounded-full font-medium ${product.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                            {product.status}
                        </span>
                    </div>
                    <div className="p-3">
                        <h4 className="font-semibold text-gray-900 truncate text-sm">{product.name}</h4>
                        <div className="flex justify-between items-center mt-2">
                            <span className="text-blue-600 font-bold text-sm">{product.price} $</span>
                            <span className="text-xs text-gray-400">{new Date(product.created_at).toLocaleDateString('fr-FR')}</span>
                        </div>
                    </div>
                </div>
            ))}
        </div>
    );
}

// ── Order Status Badge ──
function StatusBadge({ status }) {
    const map = {
        pending: { label: 'En attente', cls: 'bg-yellow-100 text-yellow-700' },
        paid: { label: 'Payée', cls: 'bg-green-100 text-green-700' },
        shipped: { label: 'Expédiée', cls: 'bg-blue-100 text-blue-700' },
        delivered: { label: 'Livrée', cls: 'bg-emerald-100 text-emerald-700' },
        cancelled: { label: 'Annulée', cls: 'bg-red-100 text-red-700' },
    };
    const s = map[status] || { label: status, cls: 'bg-gray-100 text-gray-600' };
    return <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${s.cls}`}>{s.label}</span>;
}

// ════════════════════════════════════
// ══  MAIN COMPONENT
// ════════════════════════════════════
export default function UserDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('overview');
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => { fetchUser(); }, [id]);

    const fetchUser = async () => {
        try {
            const { data } = await api.get(`/admin/users/${id}`);
            const userData = data.user || data;
            const stats = data.stats || {};
            const roles = [];
            if (userData.is_admin) roles.push('admin');
            if (userData.is_seller) roles.push('seller');
            if (userData.is_deliverer) roles.push('deliverer');
            if (userData.is_verified) roles.push('verified');

            setUser({
                ...userData,
                city: userData.location || userData.city || 'Kinshasa',
                roles,
                wallet_balance: parseFloat(userData.wallet || 0),
                reward_points: userData.reward_points || 0,
                is_active: !userData.is_suspended,
                stats,
                transactions: data.transactions || [],
                recentOrders: data.recentOrders || [],
                shops: data.shops || [],
            });
        } catch (error) {
            console.error("Erreur user:", error);
            setUser({
                id, name: 'Utilisateur Inconnu', phone: 'N/A', city: 'N/A',
                roles: [], wallet_balance: 0, reward_points: 0, is_active: false,
                stats: {}, transactions: [], recentOrders: [], shops: [],
            });
        } finally {
            setLoading(false);
        }
    };

    if (loading) return (
        <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
    );

    const badgeColor = user.has_certified_shop ? '#D4A500' :
        user.account_type === 'entreprise' ? '#D4A500' : '#1DA1F2';
    const showBadge = user.is_verified || user.account_type === 'certifie' || user.account_type === 'entreprise' || user.has_certified_shop;

    return (
        <div className="space-y-6 p-6 bg-gray-50 min-h-screen">
            {/* ── Navigation ── */}
            <button onClick={() => navigate('/users')} className="flex items-center text-gray-400 hover:text-gray-600 transition">
                <ChevronLeftIcon className="h-4 w-4 mr-1" /> Retour aux utilisateurs
            </button>

            {/* ── Profile Header Card ── */}
            <div className="bg-white rounded-2xl shadow-sm overflow-hidden border border-gray-100">
                <div className="h-28 bg-gradient-to-r from-blue-600 via-indigo-500 to-emerald-400 relative">
                    <div className={`absolute top-4 right-4 backdrop-blur rounded-full px-3.5 py-1.5 flex items-center text-xs font-bold border ${user.is_active
                            ? 'bg-green-500/20 text-white border-green-400/30'
                            : 'bg-red-500/20 text-white border-red-400/30'
                        }`}>
                        {user.is_active ? 'ACTIF' : 'SUSPENDU'}
                        <div className={`ml-2 w-2.5 h-2.5 rounded-full ${user.is_active ? 'bg-green-400 animate-pulse' : 'bg-red-400'}`}></div>
                    </div>
                </div>

                <div className="px-8 pb-8 flex flex-col md:flex-row items-start md:items-end -mt-14 gap-6">
                    {/* Avatar */}
                    <div className="relative">
                        <img
                            src={getImageUrl(user.avatar_url || user.avatar) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff&size=256`}
                            alt={user.name}
                            className="w-28 h-28 rounded-2xl border-4 border-white shadow-lg object-cover bg-white"
                            onError={(e) => {
                                e.target.onerror = null;
                                e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`;
                            }}
                        />
                        {showBadge && (
                            <div className="absolute -bottom-1 -right-1">
                                <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
                                    <path d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5c-1.51 0-2.816.917-3.437 2.25-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484z" fill={badgeColor} />
                                    <path d="M9.5 16.5L5.5 12.5l1.41-1.41L9.5 13.67l7.09-7.09L18 8l-8.5 8.5z" fill="white" />
                                </svg>
                            </div>
                        )}
                    </div>

                    {/* User Info */}
                    <div className="flex-1 pt-16 md:pt-0">
                        <h1 className="text-2xl font-bold text-gray-900">{user.name || 'Sans nom'}</h1>
                        <div className="flex flex-wrap gap-4 text-gray-500 text-sm mt-1.5">
                            <div className="flex items-center"><PhoneIcon className="h-4 w-4 mr-1" /> {user.phone}</div>
                            <div className="flex items-center"><MapPinIcon className="h-4 w-4 mr-1" /> {user.city}</div>
                            <div className="flex items-center"><CalendarDaysIcon className="h-4 w-4 mr-1" /> Inscrit le {user.created_at ? new Date(user.created_at).toLocaleDateString('fr-FR') : '—'}</div>
                        </div>
                        {/* Role badges */}
                        <div className="flex flex-wrap gap-2 mt-3">
                            {[
                                { field: 'is_verified', label: 'Vérifié', active: 'bg-green-100 text-green-700 border-green-200', inactive: 'bg-gray-100 text-gray-500 border-gray-200', roleKey: null },
                                { field: 'is_seller', label: 'Vendeur', active: 'bg-blue-100 text-blue-700 border-blue-200', inactive: 'bg-gray-100 text-gray-500 border-gray-200', roleKey: 'is_seller' },
                                { field: 'is_deliverer', label: 'Livreur', active: 'bg-purple-100 text-purple-700 border-purple-200', inactive: 'bg-gray-100 text-gray-500 border-gray-200', roleKey: 'is_deliverer' },
                            ].map(badge => (
                                <button
                                    key={badge.field}
                                    onClick={async () => {
                                        const newVal = !user[badge.field];
                                        const confirmMsg = badge.field === 'is_verified'
                                            ? `${newVal ? 'Vérifier' : 'Retirer la vérification de'} cet utilisateur ?`
                                            : `${newVal ? 'Accorder' : 'Retirer'} le statut ${badge.label} ?`;
                                        if (window.confirm(confirmMsg)) {
                                            try {
                                                if (badge.field === 'is_verified') {
                                                    await api.patch(`/admin/users/${user.id}/verify`, { verified: newVal });
                                                } else {
                                                    await api.patch(`/admin/users/${user.id}/role`, { [badge.field]: newVal });
                                                }
                                                setUser({ ...user, [badge.field]: newVal });
                                            } catch (err) {
                                                console.error(err);
                                                alert("Erreur lors de la mise à jour");
                                            }
                                        }
                                    }}
                                    className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium border cursor-pointer hover:opacity-80 transition ${user[badge.field] ? badge.active : badge.inactive}`}
                                >
                                    <TagIcon className="h-3 w-3 mr-1" />
                                    {user[badge.field] ? badge.label : `Non ${badge.label}`}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Account Type + Actions */}
                    <div className="flex flex-col gap-4 mt-4 md:mt-0">
                        <div>
                            <span className="text-xs text-gray-400 font-medium block mb-2">Type de compte</span>
                            <div className="flex gap-1.5">
                                {[
                                    { value: 'ordinaire', label: 'Ordinaire', bg: '#6b7280' },
                                    { value: 'certifie', label: 'Certifié ✓', bg: '#3b82f6' },
                                    { value: 'entreprise', label: 'Entreprise 🏢', bg: '#eab308' },
                                ].map(type => (
                                    <button
                                        key={type.value}
                                        onClick={async () => {
                                            if (window.confirm(`Définir comme ${type.label} ?`)) {
                                                try {
                                                    await api.patch(`/admin/users/${user.id}/account-type`, { account_type: type.value });
                                                    setUser({ ...user, account_type: type.value });
                                                } catch (err) { console.error(err); alert("Erreur"); }
                                            }
                                        }}
                                        className="px-3 py-1.5 rounded-full text-xs font-medium border transition"
                                        style={{
                                            backgroundColor: user.account_type === type.value ? type.bg : 'transparent',
                                            color: user.account_type === type.value ? 'white' : '#6b7280',
                                            borderColor: user.account_type === type.value ? type.bg : '#e5e7eb',
                                        }}
                                    >
                                        {type.label}
                                    </button>
                                ))}
                            </div>
                        </div>
                        <div className="flex gap-2">
                            <button
                                onClick={async () => {
                                    const msg = prompt("Message à " + (user.name || 'utilisateur') + " :");
                                    if (msg?.trim()) {
                                        try {
                                            await api.post(`/admin/users/${user.id}/message`, { content: msg });
                                            alert("Message envoyé !");
                                        } catch (err) { console.error(err); alert("Erreur envoi"); }
                                    }
                                }}
                                className="flex items-center px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium shadow-sm hover:bg-blue-700 transition"
                            >
                                <EnvelopeIcon className="h-4 w-4 mr-2" /> Message
                            </button>
                            <button
                                onClick={async () => {
                                    if (window.confirm(user.is_active ? 'BLOQUER cet utilisateur ?' : 'DÉBLOQUER cet utilisateur ?')) {
                                        try {
                                            await api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active });
                                            setUser({ ...user, is_active: !user.is_active, is_suspended: user.is_active });
                                        } catch (err) { console.error(err); alert("Erreur"); }
                                    }
                                }}
                                className={`flex items-center px-4 py-2 text-white rounded-xl text-sm font-medium shadow-sm transition ${user.is_active ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}
                            >
                                <NoSymbolIcon className="h-4 w-4 mr-2" />
                                {user.is_active ? 'Bloquer' : 'Débloquer'}
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            {/* ── Tabs ── */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 px-2 lg:px-6">
                <div className="flex space-x-1 overflow-x-auto">
                    <TabButton label="Vue Générale" active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} />
                    <TabButton label="Finance & Wallet" active={activeTab === 'finance'} onClick={() => setActiveTab('finance')} icon={CurrencyDollarIcon} />
                    <TabButton label="Commandes" active={activeTab === 'orders'} onClick={() => setActiveTab('orders')} icon={ShoppingCartIcon} />
                    <TabButton label="Marketplace" active={activeTab === 'marketplace'} onClick={() => setActiveTab('marketplace')} icon={BuildingStorefrontIcon} />
                    <TabButton label="Activité" active={activeTab === 'activity'} onClick={() => setActiveTab('activity')} icon={ChatBubbleLeftRightIcon} />
                    <TabButton label="Sécurité" active={activeTab === 'security'} onClick={() => setActiveTab('security')} icon={ShieldExclamationIcon} />
                </div>
            </div>

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: VUE GÉNÉRALE              */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'overview' && (
                <div className="space-y-6">
                    {/* KPIs */}
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
                        <MiniStat label="Wallet" value={`${user.wallet_balance.toLocaleString()} FC`} icon={CurrencyDollarIcon} color="green" />
                        <MiniStat label="Produits" value={user.stats?.products_count || 0} icon={BuildingStorefrontIcon} color="blue" subtitle={user.is_seller ? 'En vente' : ''} />
                        <MiniStat label="Commandes" value={user.stats?.orders?.total || 0} icon={ShoppingCartIcon} color="amber" subtitle={`${user.stats?.orders?.paid || 0} payées`} />
                        <MiniStat label="Dépensé" value={`${(user.stats?.orders?.total_spent || 0).toLocaleString()} $`} icon={CurrencyDollarIcon} color="rose" />
                        <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" subtitle={`${user.stats?.messages || 0} messages`} />
                        <MiniStat label="Ventes" value={user.stats?.seller_orders?.total || 0} icon={ShoppingCartIcon} color="indigo" subtitle={`${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $ CA`} />
                    </div>

                    {/* Boutiques */}
                    {user.shops && user.shops.length > 0 && (
                        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                            <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                                <BuildingStorefrontIcon className="h-5 w-5 text-amber-500" /> Boutiques
                            </h3>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {user.shops.map(shop => (
                                    <div key={shop.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-xl border border-gray-100">
                                        <img
                                            src={getImageUrl(shop.logo_url) || `https://ui-avatars.com/api/?name=${shop.name}&background=F59E0B&color=fff`}
                                            className="w-12 h-12 rounded-xl object-cover"
                                            alt={shop.name}
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.name}&background=F59E0B&color=fff`; }}
                                        />
                                        <div>
                                            <p className="font-semibold text-gray-900">{shop.name}</p>
                                            <p className="text-xs text-gray-400">{shop.category} · {shop.location}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Aperçu Marketplace */}
                    <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                        <div className="flex justify-between items-center mb-4">
                            <h3 className="font-bold text-gray-900">Aperçu du Marketplace</h3>
                            <button onClick={() => setActiveTab('marketplace')} className="text-blue-600 text-sm font-medium hover:underline">Voir tout</button>
                        </div>
                        <UserProducts userId={id} limit={4} />
                    </div>

                    {/* Commandes récentes */}
                    {user.recentOrders && user.recentOrders.length > 0 && (
                        <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                            <div className="p-5 border-b border-gray-100 flex justify-between items-center">
                                <h3 className="font-bold text-gray-900">Commandes récentes</h3>
                                <button onClick={() => setActiveTab('orders')} className="text-blue-600 text-sm font-medium hover:underline">Voir tout</button>
                            </div>
                            <div className="divide-y divide-gray-50">
                                {user.recentOrders.slice(0, 5).map(order => (
                                    <div key={order.id} className="px-5 py-3.5 flex justify-between items-center hover:bg-gray-50 transition">
                                        <div className="flex items-center gap-3">
                                            <span className="text-xs text-gray-400 font-mono">#{String(order.id).slice(-6)}</span>
                                            <span className="text-sm text-gray-500">
                                                {new Date(order.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' })}
                                            </span>
                                        </div>
                                        <div className="flex items-center gap-3">
                                            <StatusBadge status={order.status} />
                                            <span className="text-sm font-semibold text-gray-900">{parseFloat(order.total_amount || 0).toLocaleString()} $</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            )}

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: FINANCE & WALLET           */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'finance' && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div className="space-y-6">
                        {/* Wallet */}
                        <div className="bg-gradient-to-br from-blue-600 to-indigo-700 p-6 rounded-2xl text-white shadow-lg">
                            <p className="text-blue-200 text-sm font-medium">Solde Wallet Oli</p>
                            <p className="text-4xl font-bold mt-2">{user.wallet_balance.toLocaleString()} FC</p>
                            <div className="border-t border-white/20 mt-4 pt-4 flex justify-between">
                                <div>
                                    <p className="text-blue-200 text-xs">Points Récompense</p>
                                    <p className="text-xl font-bold">{user.reward_points} Pts</p>
                                </div>
                                <div>
                                    <p className="text-blue-200 text-xs">Total dépensé</p>
                                    <p className="text-xl font-bold">{(user.stats?.orders?.total_spent || 0).toLocaleString()} $</p>
                                </div>
                            </div>
                        </div>

                        {/* Info */}
                        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                            <h3 className="font-semibold text-gray-900 mb-4">Résumé financier</h3>
                            <div className="space-y-3">
                                <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                    <span className="text-sm text-gray-600">Commandes passées</span>
                                    <span className="font-semibold text-gray-900">{user.stats?.orders?.total || 0}</span>
                                </div>
                                <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                    <span className="text-sm text-gray-600">Commandes payées</span>
                                    <span className="font-semibold text-green-600">{user.stats?.orders?.paid || 0}</span>
                                </div>
                                {user.is_seller && (
                                    <>
                                        <div className="flex justify-between items-center p-3 bg-amber-50 rounded-xl">
                                            <span className="text-sm text-gray-600">Ventes réalisées</span>
                                            <span className="font-semibold text-amber-700">{user.stats?.seller_orders?.total || 0}</span>
                                        </div>
                                        <div className="flex justify-between items-center p-3 bg-amber-50 rounded-xl">
                                            <span className="text-sm text-gray-600">Chiffre d'affaires</span>
                                            <span className="font-semibold text-amber-700">{(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $</span>
                                        </div>
                                    </>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Transactions */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                        <div className="p-5 border-b border-gray-100">
                            <h3 className="font-semibold text-gray-900">Historique Transactions</h3>
                        </div>
                        <div className="divide-y divide-gray-50 max-h-[500px] overflow-y-auto">
                            {(user.transactions && user.transactions.length > 0) ? (
                                user.transactions.map((tx) => (
                                    <div key={tx.id} className="p-4 flex justify-between items-center hover:bg-gray-50 transition">
                                        <div className="flex gap-3 items-center">
                                            <span className="text-gray-400 text-xs font-mono">
                                                {new Date(tx.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' })}
                                            </span>
                                            <span className="text-gray-700 text-sm">{tx.description || tx.type}</span>
                                        </div>
                                        <span className={`font-semibold text-sm ${parseFloat(tx.amount) > 0 ? 'text-green-600' : 'text-red-600'}`}>
                                            {parseFloat(tx.amount) > 0 ? '+' : ''}{parseFloat(tx.amount).toLocaleString()} FC
                                        </span>
                                    </div>
                                ))
                            ) : (
                                <div className="p-10 text-center text-gray-400">Aucune transaction</div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: COMMANDES                  */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'orders' && (
                <div className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <MiniStat label="Total commandes" value={user.stats?.orders?.total || 0} icon={ShoppingCartIcon} color="blue" />
                        <MiniStat label="Payées" value={user.stats?.orders?.paid || 0} icon={CheckCircleIcon} color="green" />
                        <MiniStat label="Total dépensé" value={`${(user.stats?.orders?.total_spent || 0).toLocaleString()} $`} icon={CurrencyDollarIcon} color="amber" />
                    </div>

                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                        <div className="p-5 border-b border-gray-100">
                            <h3 className="font-bold text-gray-900">Toutes les commandes</h3>
                        </div>
                        {user.recentOrders && user.recentOrders.length > 0 ? (
                            <div className="divide-y divide-gray-50">
                                {user.recentOrders.map(order => (
                                    <div key={order.id} className="px-5 py-4 flex justify-between items-center hover:bg-gray-50 transition">
                                        <div className="flex items-center gap-4">
                                            <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center">
                                                <ShoppingCartIcon className="h-5 w-5 text-blue-500" />
                                            </div>
                                            <div>
                                                <p className="text-sm font-medium text-gray-900">Commande #{String(order.id).slice(-6)}</p>
                                                <p className="text-xs text-gray-400">
                                                    {new Date(order.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' })}
                                                </p>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-4">
                                            <StatusBadge status={order.status} />
                                            <span className="text-sm font-bold text-gray-900">{parseFloat(order.total_amount || 0).toLocaleString()} $</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="p-10 text-center text-gray-400">Aucune commande trouvée</div>
                        )}
                    </div>
                </div>
            )}

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: MARKETPLACE (PRODUITS)      */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'marketplace' && (
                <div className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <MiniStat label="Produits en vente" value={user.stats?.products_count || 0} icon={BuildingStorefrontIcon} color="blue" />
                        <MiniStat label="Ventes réalisées" value={user.stats?.seller_orders?.total || 0} icon={ShoppingCartIcon} color="green" subtitle={`${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $ CA`} />
                    </div>

                    {/* Boutiques */}
                    {user.shops && user.shops.length > 0 && (
                        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                            <h3 className="font-bold text-gray-900 mb-4">Boutiques</h3>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {user.shops.map(shop => (
                                    <div key={shop.id} className="flex items-center gap-4 p-4 bg-amber-50 rounded-xl border border-amber-100">
                                        <img
                                            src={getImageUrl(shop.logo_url) || `https://ui-avatars.com/api/?name=${shop.name}&background=F59E0B&color=fff`}
                                            className="w-14 h-14 rounded-xl object-cover"
                                            alt={shop.name}
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${shop.name}&background=F59E0B&color=fff`; }}
                                        />
                                        <div>
                                            <p className="font-bold text-gray-900">{shop.name}</p>
                                            <p className="text-xs text-gray-500">{shop.category} · {shop.location}</p>
                                            <p className="text-xs text-gray-400 mt-1">Créée le {new Date(shop.created_at).toLocaleDateString('fr-FR')}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    <UserProducts userId={id} />
                </div>
            )}

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: ACTIVITÉ                    */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'activity' && (
                <div className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" />
                        <MiniStat label="Messages envoyés" value={user.stats?.messages || 0} icon={EnvelopeIcon} color="blue" />
                    </div>

                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
                        <h3 className="font-bold text-gray-900 mb-4">Informations du compte</h3>
                        <div className="space-y-3">
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                <span className="text-sm text-gray-600">ID utilisateur</span>
                                <span className="font-mono text-sm text-gray-900">{user.id}</span>
                            </div>
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                <span className="text-sm text-gray-600">ID Oli</span>
                                <span className="font-mono text-sm text-gray-900">{user.id_oli || '—'}</span>
                            </div>
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                <span className="text-sm text-gray-600">Date d'inscription</span>
                                <span className="text-sm text-gray-900">{user.created_at ? new Date(user.created_at).toLocaleString('fr-FR') : '—'}</span>
                            </div>
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                <span className="text-sm text-gray-600">Dernière mise à jour profil</span>
                                <span className="text-sm text-gray-900">{user.last_profile_update ? new Date(user.last_profile_update).toLocaleString('fr-FR') : 'Jamais'}</span>
                            </div>
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                <span className="text-sm text-gray-600">Type de compte</span>
                                <span className="text-sm font-medium text-gray-900 capitalize">{user.account_type || 'Ordinaire'}</span>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* ════════════════════════════════════ */}
            {/* ══  TAB: SÉCURITÉ                    */}
            {/* ════════════════════════════════════ */}
            {activeTab === 'security' && (
                <div className="space-y-6">
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
                        <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                            <ShieldExclamationIcon className="h-5 w-5 text-red-500" /> Sécurité du compte
                        </h3>
                        <div className="space-y-4">
                            {/* Status */}
                            <div className="flex justify-between items-center p-4 bg-gray-50 rounded-xl border border-gray-100">
                                <div>
                                    <p className="font-medium text-gray-900">Statut du compte</p>
                                    <p className="text-xs text-gray-400 mt-1">L'utilisateur peut accéder à l'application</p>
                                </div>
                                <span className={`px-3 py-1.5 rounded-full text-sm font-bold ${user.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                                    {user.is_active ? '✓ Actif' : '✕ Suspendu'}
                                </span>
                            </div>

                            {/* Verification */}
                            <div className="flex justify-between items-center p-4 bg-gray-50 rounded-xl border border-gray-100">
                                <div>
                                    <p className="font-medium text-gray-900">Vérification identité</p>
                                    <p className="text-xs text-gray-400 mt-1">Badge de confiance sur le profil</p>
                                </div>
                                <span className={`px-3 py-1.5 rounded-full text-sm font-bold ${user.is_verified ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
                                    {user.is_verified ? '✓ Vérifié' : 'Non vérifié'}
                                </span>
                            </div>

                            {/* Admin */}
                            <div className="flex justify-between items-center p-4 bg-gray-50 rounded-xl border border-gray-100">
                                <div>
                                    <p className="font-medium text-gray-900">Rôle administrateur</p>
                                    <p className="text-xs text-gray-400 mt-1">Accès complet au panneau d'administration</p>
                                </div>
                                <button
                                    onClick={async () => {
                                        const newVal = !user.is_admin;
                                        if (window.confirm(`${newVal ? 'Accorder' : 'Retirer'} les droits admin ?`)) {
                                            try {
                                                await api.patch(`/admin/users/${user.id}/role`, { is_admin: newVal });
                                                setUser({ ...user, is_admin: newVal });
                                            } catch (err) { console.error(err); alert("Erreur"); }
                                        }
                                    }}
                                    className={`px-3 py-1.5 rounded-full text-sm font-bold transition cursor-pointer hover:opacity-80 ${user.is_admin ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-500'}`}
                                >
                                    {user.is_admin ? '✓ Admin' : 'Non admin'}
                                </button>
                            </div>

                            {/* Danger Zone */}
                            <div className="mt-6 p-4 border-2 border-dashed border-red-200 rounded-xl">
                                <h4 className="font-semibold text-red-700 mb-3">⚠️ Zone de danger</h4>
                                <div className="flex gap-3">
                                    <button
                                        onClick={async () => {
                                            if (window.confirm(user.is_active ? 'BLOQUER cet utilisateur ? Il ne pourra plus se connecter.' : 'DÉBLOQUER cet utilisateur ?')) {
                                                try {
                                                    await api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active });
                                                    setUser({ ...user, is_active: !user.is_active, is_suspended: user.is_active });
                                                } catch (err) { console.error(err); alert("Erreur"); }
                                            }
                                        }}
                                        className={`px-4 py-2 rounded-xl text-sm font-bold transition ${user.is_active
                                            ? 'bg-red-600 text-white hover:bg-red-700'
                                            : 'bg-green-600 text-white hover:bg-green-700'
                                            }`}
                                    >
                                        {user.is_active ? '🔒 Bloquer le compte' : '🔓 Débloquer le compte'}
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
