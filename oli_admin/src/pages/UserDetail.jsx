import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    EnvelopeIcon,
    NoSymbolIcon,
    CheckCircleIcon,
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

// ═══════════════════════════════════
// ══  TOGGLE SWITCH COMPONENT
// ═══════════════════════════════════
function ToggleSwitch({ enabled, onChange, label, sublabel, loading: isLoading }) {
    return (
        <div className="flex items-center justify-between py-3">
            <div>
                <p className="text-sm font-medium text-gray-900">{label}</p>
                {sublabel && <p className="text-xs text-gray-400 mt-0.5">{sublabel}</p>}
            </div>
            <button
                onClick={onChange}
                disabled={isLoading}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${enabled ? 'bg-blue-600' : 'bg-gray-300'} ${isLoading ? 'opacity-50 cursor-wait' : 'cursor-pointer'}`}
            >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow-md transition-transform duration-200 ${enabled ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
        </div>
    );
}

// ═══════════════════════════════════
// ══  TAB BUTTON
// ═══════════════════════════════════
function TabButton({ label, active, onClick, icon: Icon }) {
    return (
        <button
            onClick={onClick}
            className={`px-5 py-3.5 text-sm font-medium border-b-2 transition-colors flex items-center gap-2 whitespace-nowrap ${active
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-400 hover:text-gray-600 hover:border-gray-200'
                }`}
        >
            {Icon && <Icon className="h-4 w-4" />}
            {label}
        </button>
    );
}

// ═══════════════════════════════════
// ══  MINI STAT CARD
// ═══════════════════════════════════
function MiniStat({ label, value, icon: Icon, color = 'blue', subtitle }) {
    const bg = {
        blue: 'bg-blue-50 text-blue-600', green: 'bg-green-50 text-green-600',
        amber: 'bg-amber-50 text-amber-600', purple: 'bg-purple-50 text-purple-600',
        rose: 'bg-rose-50 text-rose-600', indigo: 'bg-indigo-50 text-indigo-600',
    };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
            <div className="flex items-center gap-3 mb-3">
                <div className={`p-2 rounded-lg ${bg[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
    );
}

// ═══════════════════════════════════
// ══  USER PRODUCTS GRID
// ═══════════════════════════════════
function UserProducts({ userId, limit }) {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    useEffect(() => {
        (async () => {
            try { const { data } = await api.get(`/admin/users/${userId}/products`); setProducts(limit ? data.slice(0, limit) : data); }
            catch (e) { console.error(e); }
            finally { setLoading(false); }
        })();
    }, [userId, limit]);
    if (loading) return <div className="p-4 text-center text-gray-400">Chargement...</div>;
    if (!products.length) return <div className="p-8 text-center text-gray-400 bg-gray-50 rounded-2xl border border-dashed border-gray-200">Aucun produit.</div>;
    return (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map(p => (
                <div key={p.id} className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition">
                    <div className="h-40 bg-gray-100 relative">
                        <img src={getImageUrl(p.image_url)} alt={p.name} className="w-full h-full object-cover" onError={(e) => e.target.src = 'https://via.placeholder.com/300?text=No+Image'} />
                        <span className={`absolute top-2 right-2 px-2 py-0.5 text-xs rounded-full font-medium ${p.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>{p.status}</span>
                    </div>
                    <div className="p-3">
                        <h4 className="font-semibold text-gray-900 truncate text-sm">{p.name}</h4>
                        <div className="flex justify-between items-center mt-2">
                            <span className="text-blue-600 font-bold text-sm">{p.price} $</span>
                            <span className="text-xs text-gray-400">{new Date(p.created_at).toLocaleDateString('fr-FR')}</span>
                        </div>
                    </div>
                </div>
            ))}
        </div>
    );
}

// ═══════════════════════════════════
// ══  STATUS BADGE
// ═══════════════════════════════════
function StatusBadge({ status }) {
    const m = {
        pending: { l: 'En attente', c: 'bg-yellow-100 text-yellow-700' },
        paid: { l: 'Payée', c: 'bg-green-100 text-green-700' },
        shipped: { l: 'Expédiée', c: 'bg-blue-100 text-blue-700' },
        delivered: { l: 'Livrée', c: 'bg-emerald-100 text-emerald-700' },
        cancelled: { l: 'Annulée', c: 'bg-red-100 text-red-700' },
    };
    const s = m[status] || { l: status, c: 'bg-gray-100 text-gray-600' };
    return <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${s.c}`}>{s.l}</span>;
}

// ═══════════════════════════════════════════════
// ══  MAIN: USER DETAIL
// ═══════════════════════════════════════════════
export default function UserDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('overview');
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const [toggleLoading, setToggleLoading] = useState({});

    useEffect(() => { fetchUser(); }, [id]);

    const fetchUser = async () => {
        try {
            const { data } = await api.get(`/admin/users/${id}`);
            const u = data.user || data;
            setUser({
                ...u,
                city: u.location || u.city || 'Non renseigné',
                wallet_balance: parseFloat(u.wallet || 0),
                reward_points: u.reward_points || 0,
                is_active: !u.is_suspended,
                stats: data.stats || {},
                transactions: data.transactions || [],
                recentOrders: data.recentOrders || [],
                shops: data.shops || [],
            });
        } catch (error) {
            console.error("Erreur user:", error);
            setUser({ id, name: 'Inconnu', phone: 'N/A', city: 'N/A', wallet_balance: 0, reward_points: 0, is_active: false, stats: {}, transactions: [], recentOrders: [], shops: [] });
        } finally { setLoading(false); }
    };

    // ── Unified toggle handler ──
    const handleToggle = async (field, apiCall) => {
        setToggleLoading(prev => ({ ...prev, [field]: true }));
        try {
            await apiCall();
            // Refetch to get consistent data
            const { data } = await api.get(`/admin/users/${id}`);
            const u = data.user || data;
            setUser(prev => ({
                ...prev, ...u,
                city: u.location || u.city || 'Non renseigné',
                wallet_balance: parseFloat(u.wallet || 0),
                is_active: !u.is_suspended,
                stats: data.stats || prev.stats,
                transactions: data.transactions || prev.transactions,
                recentOrders: data.recentOrders || prev.recentOrders,
                shops: data.shops || prev.shops,
            }));
        } catch (err) {
            console.error(err);
            alert("Erreur lors de la mise à jour");
        } finally {
            setToggleLoading(prev => ({ ...prev, [field]: false }));
        }
    };

    if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;

    const showBadge = user.is_verified || user.account_type === 'certifie' || user.account_type === 'entreprise' || user.has_certified_shop;
    const badgeColor = user.has_certified_shop || user.account_type === 'entreprise' ? '#D4A500' : '#1DA1F2';

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* ── Back ── */}
            <button onClick={() => navigate('/users')} className="flex items-center text-gray-400 hover:text-gray-600 transition text-sm">
                <ChevronLeftIcon className="h-4 w-4 mr-1" /> Retour aux utilisateurs
            </button>

            {/* ═══════════════════════════════════ */}
            {/* ══  PROFILE HEADER (FIXED LAYOUT)  */}
            {/* ═══════════════════════════════════ */}
            <div className="bg-white rounded-2xl shadow-sm overflow-hidden border border-gray-100">
                {/* Banner */}
                <div className="h-32 bg-gradient-to-r from-blue-600 via-indigo-500 to-emerald-400 relative">
                    <div className={`absolute top-4 right-4 backdrop-blur-sm rounded-full px-3.5 py-1.5 flex items-center text-xs font-bold border ${user.is_active ? 'bg-white/20 text-white border-white/30' : 'bg-red-500/30 text-white border-red-300/30'}`}>
                        {user.is_active ? 'ACTIF' : 'SUSPENDU'}
                        <div className={`ml-2 w-2 h-2 rounded-full ${user.is_active ? 'bg-green-400 animate-pulse' : 'bg-red-400'}`}></div>
                    </div>
                </div>

                {/* Profile Info - Separate section below banner */}
                <div className="px-6 md:px-8 pb-6 relative">
                    {/* Avatar - Positioned overlapping the banner */}
                    <div className="flex flex-col md:flex-row md:items-end gap-5">
                        <div className="relative -mt-12 flex-shrink-0">
                            <img
                                src={getImageUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff&size=256`}
                                alt={user.name}
                                className="w-24 h-24 rounded-2xl border-4 border-white shadow-lg object-cover bg-white"
                                onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`; }}
                            />
                            {showBadge && (
                                <div className="absolute -bottom-1 -right-1">
                                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                                        <path d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5c-1.51 0-2.816.917-3.437 2.25-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484z" fill={badgeColor} />
                                        <path d="M9.5 16.5L5.5 12.5l1.41-1.41L9.5 13.67l7.09-7.09L18 8l-8.5 8.5z" fill="white" />
                                    </svg>
                                </div>
                            )}
                        </div>

                        {/* Name & Info */}
                        <div className="flex-1 pt-2 md:pt-0 md:pb-1">
                            <h1 className="text-xl font-bold text-gray-900">{user.name || 'Sans nom'}</h1>
                            <div className="flex flex-wrap gap-x-4 gap-y-1 text-gray-500 text-xs mt-1">
                                <span className="flex items-center"><PhoneIcon className="h-3.5 w-3.5 mr-1" />{user.phone}</span>
                                <span className="flex items-center"><MapPinIcon className="h-3.5 w-3.5 mr-1" />{user.city}</span>
                                <span className="flex items-center"><CalendarDaysIcon className="h-3.5 w-3.5 mr-1" />Inscrit le {user.created_at ? new Date(user.created_at).toLocaleDateString('fr-FR') : '—'}</span>
                            </div>
                        </div>

                        {/* Quick Actions */}
                        <div className="flex gap-2 flex-shrink-0 pb-1">
                            <button
                                onClick={async () => {
                                    const msg = prompt("Message à " + (user.name || 'utilisateur') + " :");
                                    if (msg?.trim()) {
                                        try { await api.post(`/admin/users/${user.id}/message`, { content: msg }); alert("Message envoyé !"); }
                                        catch (err) { console.error(err); alert("Erreur envoi"); }
                                    }
                                }}
                                className="flex items-center px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium shadow-sm hover:bg-blue-700 transition"
                            >
                                <EnvelopeIcon className="h-4 w-4 mr-1.5" /> Message
                            </button>
                            <button
                                onClick={() => handleToggle('is_suspended', () => api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active }))}
                                className={`flex items-center px-4 py-2 text-white rounded-xl text-sm font-medium shadow-sm transition ${user.is_active ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}
                            >
                                <NoSymbolIcon className="h-4 w-4 mr-1.5" />
                                {user.is_active ? 'Bloquer' : 'Débloquer'}
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            {/* ═══════════════════════════════════ */}
            {/* ══  MAIN LAYOUT: 2 columns          */}
            {/* ═══════════════════════════════════ */}
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">

                {/* ── LEFT SIDEBAR: Admin Controls ── */}
                <div className="lg:col-span-1 space-y-4">
                    {/* Rôles & Permissions */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Rôles & Permissions</h3>
                        <div className="divide-y divide-gray-100">
                            <ToggleSwitch
                                label="Administrateur"
                                sublabel="Accès au panneau admin"
                                enabled={user.is_admin}
                                loading={toggleLoading.is_admin}
                                onChange={() => handleToggle('is_admin', () => api.patch(`/admin/users/${user.id}/role`, { is_admin: !user.is_admin }))}
                            />
                            <ToggleSwitch
                                label="Vendeur"
                                sublabel="Peut vendre des produits"
                                enabled={user.is_seller}
                                loading={toggleLoading.is_seller}
                                onChange={() => handleToggle('is_seller', () => api.patch(`/admin/users/${user.id}/role`, { is_seller: !user.is_seller }))}
                            />
                            <ToggleSwitch
                                label="Livreur"
                                sublabel="Peut livrer des commandes"
                                enabled={user.is_deliverer}
                                loading={toggleLoading.is_deliverer}
                                onChange={() => handleToggle('is_deliverer', () => api.patch(`/admin/users/${user.id}/role`, { is_deliverer: !user.is_deliverer }))}
                            />
                        </div>
                    </div>

                    {/* Certification & Vérification */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Vérification</h3>
                        <div className="divide-y divide-gray-100">
                            <ToggleSwitch
                                label="Compte vérifié"
                                sublabel="Badge bleu sur le profil"
                                enabled={user.is_verified}
                                loading={toggleLoading.is_verified}
                                onChange={() => handleToggle('is_verified', () => api.patch(`/admin/users/${user.id}/verify`, { verified: !user.is_verified }))}
                            />
                            <ToggleSwitch
                                label="Boutique certifiée"
                                sublabel="Badge or magasin"
                                enabled={user.has_certified_shop}
                                loading={toggleLoading.has_certified_shop}
                                onChange={() => handleToggle('has_certified_shop', () => api.patch(`/admin/users/${user.id}/account-type`, { has_certified_shop: !user.has_certified_shop }))}
                            />
                        </div>
                    </div>

                    {/* Type de compte */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Type de compte</h3>
                        <div className="space-y-2">
                            {[
                                { value: 'ordinaire', label: 'Ordinaire', desc: 'Compte standard', color: '#6b7280' },
                                { value: 'certifie', label: 'Certifié ✓', desc: 'Vendeur de confiance', color: '#3b82f6' },
                                { value: 'entreprise', label: 'Entreprise 🏢', desc: 'Compte professionnel', color: '#eab308' },
                            ].map(type => (
                                <button
                                    key={type.value}
                                    onClick={() => handleToggle('account_type', () => api.patch(`/admin/users/${user.id}/account-type`, { account_type: type.value }))}
                                    className={`w-full text-left px-4 py-3 rounded-xl border-2 transition-all ${user.account_type === type.value
                                            ? 'border-current shadow-sm'
                                            : 'border-gray-100 hover:border-gray-200'
                                        }`}
                                    style={{ borderColor: user.account_type === type.value ? type.color : undefined }}
                                >
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <p className="text-sm font-medium text-gray-900">{type.label}</p>
                                            <p className="text-xs text-gray-400">{type.desc}</p>
                                        </div>
                                        {user.account_type === type.value && (
                                            <div className="w-5 h-5 rounded-full flex items-center justify-center" style={{ backgroundColor: type.color }}>
                                                <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" /></svg>
                                            </div>
                                        )}
                                    </div>
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Statut du compte */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Statut</h3>
                        <ToggleSwitch
                            label="Compte actif"
                            sublabel={user.is_active ? "L'utilisateur peut se connecter" : "Compte bloqué"}
                            enabled={user.is_active}
                            loading={toggleLoading.is_suspended}
                            onChange={() => handleToggle('is_suspended', () => api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active }))}
                        />
                    </div>
                </div>

                {/* ── RIGHT CONTENT: Tabs ── */}
                <div className="lg:col-span-3 space-y-6">
                    {/* Tabs */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 px-3">
                        <div className="flex space-x-1 overflow-x-auto">
                            <TabButton label="Vue Générale" active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} />
                            <TabButton label="Finance" active={activeTab === 'finance'} onClick={() => setActiveTab('finance')} icon={CurrencyDollarIcon} />
                            <TabButton label="Commandes" active={activeTab === 'orders'} onClick={() => setActiveTab('orders')} icon={ShoppingCartIcon} />
                            <TabButton label="Marketplace" active={activeTab === 'marketplace'} onClick={() => setActiveTab('marketplace')} icon={BuildingStorefrontIcon} />
                            <TabButton label="Activité" active={activeTab === 'activity'} onClick={() => setActiveTab('activity')} icon={ChatBubbleLeftRightIcon} />
                        </div>
                    </div>

                    {/* ══ TAB: VUE GÉNÉRALE ══ */}
                    {activeTab === 'overview' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                                <MiniStat label="Wallet" value={`${user.wallet_balance.toLocaleString()} FC`} icon={CurrencyDollarIcon} color="green" />
                                <MiniStat label="Produits" value={user.stats?.products_count || 0} icon={BuildingStorefrontIcon} color="blue" subtitle={user.is_seller ? 'En vente' : ''} />
                                <MiniStat label="Commandes" value={user.stats?.orders?.total || 0} icon={ShoppingCartIcon} color="amber" subtitle={`${user.stats?.orders?.paid || 0} payées`} />
                                <MiniStat label="Dépensé" value={`${(user.stats?.orders?.total_spent || 0).toLocaleString()} $`} icon={CurrencyDollarIcon} color="rose" />
                                <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" subtitle={`${user.stats?.messages || 0} messages`} />
                                <MiniStat label="Ventes" value={user.stats?.seller_orders?.total || 0} icon={ShoppingCartIcon} color="indigo" subtitle={`${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $ CA`} />
                            </div>

                            {/* Boutiques */}
                            {user.shops?.length > 0 && (
                                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                                    <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2"><BuildingStorefrontIcon className="h-5 w-5 text-amber-500" /> Boutiques</h3>
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                        {user.shops.map(s => (
                                            <div key={s.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-xl">
                                                <img src={getImageUrl(s.logo_url) || `https://ui-avatars.com/api/?name=${s.name}&background=F59E0B&color=fff`} className="w-12 h-12 rounded-xl object-cover" alt={s.name} onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${s.name}&background=F59E0B&color=fff`; }} />
                                                <div>
                                                    <p className="font-semibold text-gray-900 text-sm">{s.name}</p>
                                                    <p className="text-xs text-gray-400">{s.category} · {s.location}</p>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* Aperçu produits */}
                            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                                <div className="flex justify-between items-center mb-4">
                                    <h3 className="font-bold text-gray-900">Produits</h3>
                                    <button onClick={() => setActiveTab('marketplace')} className="text-blue-600 text-sm font-medium hover:underline">Voir tout</button>
                                </div>
                                <UserProducts userId={id} limit={4} />
                            </div>

                            {/* Commandes récentes */}
                            {user.recentOrders?.length > 0 && (
                                <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                                    <div className="p-5 border-b border-gray-100 flex justify-between items-center">
                                        <h3 className="font-bold text-gray-900">Commandes récentes</h3>
                                        <button onClick={() => setActiveTab('orders')} className="text-blue-600 text-sm font-medium hover:underline">Voir tout</button>
                                    </div>
                                    <div className="divide-y divide-gray-50">
                                        {user.recentOrders.slice(0, 5).map(o => (
                                            <div key={o.id} className="px-5 py-3 flex justify-between items-center hover:bg-gray-50 transition">
                                                <div className="flex items-center gap-3">
                                                    <span className="text-xs text-gray-400 font-mono">#{String(o.id).slice(-6)}</span>
                                                    <span className="text-sm text-gray-500">{new Date(o.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' })}</span>
                                                </div>
                                                <div className="flex items-center gap-3">
                                                    <StatusBadge status={o.status} />
                                                    <span className="text-sm font-semibold text-gray-900">{parseFloat(o.total_amount || 0).toLocaleString()} $</span>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    )}

                    {/* ══ TAB: FINANCE ══ */}
                    {activeTab === 'finance' && (
                        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                            <div className="space-y-6">
                                <div className="bg-gradient-to-br from-blue-600 to-indigo-700 p-6 rounded-2xl text-white shadow-lg">
                                    <p className="text-blue-200 text-sm">Solde Wallet Oli</p>
                                    <p className="text-4xl font-bold mt-2">{user.wallet_balance.toLocaleString()} FC</p>
                                    <div className="border-t border-white/20 mt-4 pt-4 flex justify-between">
                                        <div><p className="text-blue-200 text-xs">Points</p><p className="text-xl font-bold">{user.reward_points} Pts</p></div>
                                        <div><p className="text-blue-200 text-xs">Dépensé</p><p className="text-xl font-bold">{(user.stats?.orders?.total_spent || 0).toLocaleString()} $</p></div>
                                    </div>
                                </div>
                                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                                    <h3 className="font-semibold text-gray-900 mb-4">Résumé financier</h3>
                                    <div className="space-y-2">
                                        {[
                                            { l: 'Commandes passées', v: user.stats?.orders?.total || 0 },
                                            { l: 'Commandes payées', v: user.stats?.orders?.paid || 0, green: true },
                                            ...(user.is_seller ? [
                                                { l: 'Ventes réalisées', v: user.stats?.seller_orders?.total || 0, amber: true },
                                                { l: "Chiffre d'affaires", v: `${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $`, amber: true },
                                            ] : []),
                                        ].map((r, i) => (
                                            <div key={i} className={`flex justify-between items-center p-3 rounded-xl ${r.amber ? 'bg-amber-50' : 'bg-gray-50'}`}>
                                                <span className="text-sm text-gray-600">{r.l}</span>
                                                <span className={`font-semibold ${r.green ? 'text-green-600' : r.amber ? 'text-amber-700' : 'text-gray-900'}`}>{r.v}</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                                <div className="p-5 border-b border-gray-100"><h3 className="font-semibold text-gray-900">Historique Transactions</h3></div>
                                <div className="divide-y divide-gray-50 max-h-[500px] overflow-y-auto">
                                    {user.transactions?.length > 0 ? user.transactions.map(tx => (
                                        <div key={tx.id} className="p-4 flex justify-between items-center hover:bg-gray-50 transition">
                                            <div className="flex gap-3 items-center">
                                                <span className="text-gray-400 text-xs font-mono">{new Date(tx.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' })}</span>
                                                <span className="text-gray-700 text-sm">{tx.description || tx.type}</span>
                                            </div>
                                            <span className={`font-semibold text-sm ${parseFloat(tx.amount) > 0 ? 'text-green-600' : 'text-red-600'}`}>
                                                {parseFloat(tx.amount) > 0 ? '+' : ''}{parseFloat(tx.amount).toLocaleString()} FC
                                            </span>
                                        </div>
                                    )) : <div className="p-10 text-center text-gray-400">Aucune transaction</div>}
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ══ TAB: COMMANDES ══ */}
                    {activeTab === 'orders' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                <MiniStat label="Total" value={user.stats?.orders?.total || 0} icon={ShoppingCartIcon} color="blue" />
                                <MiniStat label="Payées" value={user.stats?.orders?.paid || 0} icon={CheckCircleIcon} color="green" />
                                <MiniStat label="Dépensé" value={`${(user.stats?.orders?.total_spent || 0).toLocaleString()} $`} icon={CurrencyDollarIcon} color="amber" />
                            </div>
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                                <div className="p-5 border-b border-gray-100"><h3 className="font-bold text-gray-900">Toutes les commandes</h3></div>
                                {user.recentOrders?.length > 0 ? (
                                    <div className="divide-y divide-gray-50">
                                        {user.recentOrders.map(o => (
                                            <div key={o.id} className="px-5 py-4 flex justify-between items-center hover:bg-gray-50 transition">
                                                <div className="flex items-center gap-4">
                                                    <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center"><ShoppingCartIcon className="h-5 w-5 text-blue-500" /></div>
                                                    <div>
                                                        <p className="text-sm font-medium text-gray-900">Commande #{String(o.id).slice(-6)}</p>
                                                        <p className="text-xs text-gray-400">{new Date(o.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' })}</p>
                                                    </div>
                                                </div>
                                                <div className="flex items-center gap-4">
                                                    <StatusBadge status={o.status} />
                                                    <span className="text-sm font-bold text-gray-900">{parseFloat(o.total_amount || 0).toLocaleString()} $</span>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                ) : <div className="p-10 text-center text-gray-400">Aucune commande</div>}
                            </div>
                        </div>
                    )}

                    {/* ══ TAB: MARKETPLACE ══ */}
                    {activeTab === 'marketplace' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <MiniStat label="Produits" value={user.stats?.products_count || 0} icon={BuildingStorefrontIcon} color="blue" />
                                <MiniStat label="Ventes" value={user.stats?.seller_orders?.total || 0} icon={ShoppingCartIcon} color="green" subtitle={`${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $ CA`} />
                            </div>
                            {user.shops?.length > 0 && (
                                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                                    <h3 className="font-bold text-gray-900 mb-4">Boutiques</h3>
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                        {user.shops.map(s => (
                                            <div key={s.id} className="flex items-center gap-4 p-4 bg-amber-50 rounded-xl border border-amber-100">
                                                <img src={getImageUrl(s.logo_url) || `https://ui-avatars.com/api/?name=${s.name}&background=F59E0B&color=fff`} className="w-14 h-14 rounded-xl object-cover" alt={s.name} onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${s.name}&background=F59E0B&color=fff`; }} />
                                                <div>
                                                    <p className="font-bold text-gray-900">{s.name}</p>
                                                    <p className="text-xs text-gray-500">{s.category} · {s.location}</p>
                                                    <p className="text-xs text-gray-400 mt-1">Créée le {new Date(s.created_at).toLocaleDateString('fr-FR')}</p>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                            <UserProducts userId={id} />
                        </div>
                    )}

                    {/* ══ TAB: ACTIVITÉ ══ */}
                    {activeTab === 'activity' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" />
                                <MiniStat label="Messages envoyés" value={user.stats?.messages || 0} icon={EnvelopeIcon} color="blue" />
                            </div>
                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
                                <h3 className="font-bold text-gray-900 mb-4">Informations du compte</h3>
                                <div className="space-y-2">
                                    {[
                                        { l: 'ID utilisateur', v: user.id, mono: true },
                                        { l: 'ID Oli', v: user.id_oli || '—', mono: true },
                                        { l: "Date d'inscription", v: user.created_at ? new Date(user.created_at).toLocaleString('fr-FR') : '—' },
                                        { l: 'Dernière mise à jour', v: user.last_profile_update ? new Date(user.last_profile_update).toLocaleString('fr-FR') : 'Jamais' },
                                        { l: 'Type de compte', v: (user.account_type || 'ordinaire').charAt(0).toUpperCase() + (user.account_type || 'ordinaire').slice(1) },
                                    ].map((r, i) => (
                                        <div key={i} className="flex justify-between items-center p-3 bg-gray-50 rounded-xl">
                                            <span className="text-sm text-gray-600">{r.l}</span>
                                            <span className={`text-sm text-gray-900 ${r.mono ? 'font-mono' : 'font-medium'}`}>{r.v}</span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
