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
    EyeIcon,
    EyeSlashIcon,
    PencilSquareIcon,
    ArrowPathIcon,
} from '@heroicons/react/24/solid';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

// ═══════════════════════════════════
// ══  TOGGLE SWITCH
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
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-200 focus:outline-none ${
                    isLoading ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
                } ${enabled ? 'bg-blue-600' : 'bg-gray-200'}`}
            >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow-sm transition-transform duration-200 ${enabled ? 'translate-x-6' : 'translate-x-1'}`} />
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
            className={`flex items-center gap-1.5 px-4 py-3 text-sm font-medium border-b-2 whitespace-nowrap transition-colors ${
                active ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
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
    const colors = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        amber: 'bg-amber-50 text-amber-600',
        rose: 'bg-rose-50 text-rose-600',
        purple: 'bg-purple-50 text-purple-600',
        indigo: 'bg-indigo-50 text-indigo-600',
    };
    return (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className={`inline-flex p-2 rounded-xl mb-3 ${colors[color]}`}>
                <Icon className="h-5 w-5" />
            </div>
            <p className="text-xs text-gray-500 uppercase tracking-wide font-medium">{label}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
            {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
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
        cancelled: { l: 'Annulée', c: 'bg-red-100 text-red-700' }
    };
    const s = m[status] || { l: status, c: 'bg-gray-100 text-gray-600' };
    return <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${s.c}`}>{s.l}</span>;
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
    if (!products.length) return <div className="p-8 text-center text-gray-400 bg-gray-50 rounded-2xl border border-dashed border-gray-200">Aucun produit mis en vente.</div>;
    return (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map(p => (
                <div key={p.id} className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition">
                    <div className="h-40 bg-gray-100 relative">
                        <img src={p.image_url || getImageUrl(p.images?.[0]) || 'https://via.placeholder.com/300x200?text=Pas+d%27image'} alt={p.name} className="w-full h-full object-cover" onError={(e) => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/300x200?text=Pas+d%27image'; }} />
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
// ══  USER CONVERSATIONS LIST
// ═══════════════════════════════════
function UserConversations({ userId }) {
    const [convos, setConvos] = useState([]);
    const [loading, setLoading] = useState(true);
    useEffect(() => {
        (async () => {
            try { const { data } = await api.get(`/admin/users/${userId}/conversations`); setConvos(data); }
            catch (e) { console.error(e); }
            finally { setLoading(false); }
        })();
    }, [userId]);
    if (loading) return <div className="p-4 text-center text-gray-400">Chargement des conversations...</div>;
    if (!convos.length) return <div className="p-8 text-center text-gray-400 bg-gray-50 rounded-2xl border border-dashed border-gray-200">Aucune conversation.</div>;

    const fmtTime = (d) => {
        if (!d) return '';
        const dt = new Date(d);
        const now = new Date();
        const diff = now - dt;
        if (diff < 60000) return 'À l\'instant';
        if (diff < 3600000) return `${Math.floor(diff / 60000)} min`;
        if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`;
        return dt.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
    };

    return (
        <div className="divide-y divide-gray-50">
            {convos.map(c => (
                <div key={c.conversation_id} className="p-4 hover:bg-gray-50 transition flex items-center gap-4">
                    <div className="relative flex-shrink-0">
                        <img src={getImageUrl(c.other_avatar) || `https://ui-avatars.com/api/?name=${c.other_name || 'U'}&background=6366F1&color=fff`} className="w-12 h-12 rounded-full object-cover" alt={c.other_name} onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${c.other_name || 'U'}&background=6366F1&color=fff`; }} />
                    </div>
                    <div className="flex-1 min-w-0">
                        <div className="flex justify-between items-start">
                            <div>
                                <p className="font-semibold text-gray-900 text-sm">{c.other_name || c.other_phone}</p>
                                <p className="text-xs text-gray-400">{c.other_phone}</p>
                            </div>
                            <div className="text-right flex-shrink-0 ml-2">
                                <p className="text-xs text-gray-400">{fmtTime(c.last_time)}</p>
                                <p className="text-xs text-gray-300 mt-0.5">{c.total_messages} msg</p>
                            </div>
                        </div>
                        <p className="text-sm text-gray-500 truncate mt-1">
                            {c.last_message_type === 'image' ? '📷 Image' :
                                c.last_message_type === 'voice' ? '🎤 Message vocal' :
                                    c.last_message_type === 'money' ? '💰 Transfert' :
                                        c.last_message || 'Aucun message'}
                        </p>
                        {c.product_name && (
                            <div className="flex items-center gap-2 mt-2 p-2 bg-blue-50 rounded-lg">
                                {c.product_image && <img src={c.product_image} className="w-8 h-8 rounded object-cover" alt="" />}
                                <div className="min-w-0">
                                    <p className="text-xs font-medium text-blue-700 truncate">{c.product_name}</p>
                                    <p className="text-xs text-blue-500">{c.product_price} $</p>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            ))}
        </div>
    );
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

    // ── Finance: taux de change & devise ──
    const [exchangeRate, setExchangeRate] = useState(2850); // FC par USD (fallback)
    const [rateUpdatedAt, setRateUpdatedAt] = useState(null);
    const [currencyMode, setCurrencyMode] = useState('FC'); // 'FC' | 'USD'

    // ── Modification du solde wallet ──
    const [walletEditOpen, setWalletEditOpen] = useState(false);
    const [walletEditAmount, setWalletEditAmount] = useState('');
    const [walletEditReason, setWalletEditReason] = useState('');
    const [walletEditLoading, setWalletEditLoading] = useState(false);
    const [walletEditMsg, setWalletEditMsg] = useState(null);

    useEffect(() => { fetchUser(); }, [id]);

    // Récupérer le taux de change du jour
    useEffect(() => {
        api.get('/api/exchange-rate/current')
            .then(({ data }) => {
                if (data?.data?.rate) {
                    setExchangeRate(parseFloat(data.data.rate));
                    setRateUpdatedAt(data.data.timestamp);
                }
            })
            .catch(() => {}); // Utilise le fallback 2850
    }, []);

    const fetchUser = async () => {
        try {
            const { data } = await api.get(`/admin/users/${id}`);
            const u = data.user || data;
            setUser({
                ...u,
                city: u.location || u.city || 'Non renseigné',
                // Utiliser wallet_balance retourné par le backend (depuis wallets table)
                wallet_balance: parseFloat(data.wallet_balance ?? u.wallet ?? 0),
                reward_points: u.reward_points || 0,
                is_active: !u.is_suspended,
                is_hidden: u.is_hidden || false,
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

    const handleToggle = async (field, apiCall) => {
        setToggleLoading(prev => ({ ...prev, [field]: true }));
        try {
            await apiCall();
            const { data } = await api.get(`/admin/users/${id}`);
            const u = data.user || data;
            setUser(prev => ({
                ...prev, ...u,
                city: u.location || u.city || 'Non renseigné',
                wallet_balance: parseFloat(data.wallet_balance ?? u.wallet ?? prev.wallet_balance),
                is_active: !u.is_suspended,
                is_hidden: u.is_hidden || false,
                stats: data.stats || prev.stats,
                transactions: data.transactions || prev.transactions,
                recentOrders: data.recentOrders || prev.recentOrders,
                shops: data.shops || prev.shops,
            }));
        } catch (e) {
            console.error("Erreur toggle:", e);
            alert(e.response?.data?.error || "Erreur lors de la mise à jour");
        } finally {
            setToggleLoading(prev => ({ ...prev, [field]: false }));
        }
    };

    // Modifier le solde du wallet
    const handleWalletEdit = async (e) => {
        e.preventDefault();
        const amount = parseFloat(walletEditAmount);
        if (isNaN(amount) || amount < 0) {
            setWalletEditMsg({ type: 'error', text: 'Montant invalide' });
            return;
        }
        setWalletEditLoading(true);
        setWalletEditMsg(null);
        try {
            const { data } = await api.patch(`/admin/users/${id}/wallet`, {
                amount,
                reason: walletEditReason || 'Ajustement administrateur',
            });
            setUser(prev => ({ ...prev, wallet_balance: data.newBalance }));
            setWalletEditMsg({ type: 'success', text: data.message });
            setWalletEditAmount('');
            setWalletEditReason('');
            setTimeout(() => { setWalletEditOpen(false); setWalletEditMsg(null); }, 2000);
        } catch (err) {
            setWalletEditMsg({ type: 'error', text: err.response?.data?.error || 'Erreur serveur' });
        } finally {
            setWalletEditLoading(false);
        }
    };

    // Convertir FC ↔ USD pour l'affichage
    const fmtAmount = (fc) => {
        if (currencyMode === 'USD') {
            return `${(fc / exchangeRate).toFixed(2)} $`;
        }
        return `${fc.toLocaleString('fr-CD')} FC`;
    };

    if (loading) return (
        <div className="min-h-screen flex items-center justify-center">
            <div className="text-center">
                <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
                <p className="text-gray-500 text-sm">Chargement du profil...</p>
            </div>
        </div>
    );

    if (!user) return <div className="p-8 text-center text-gray-500">Utilisateur non trouvé</div>;

    const showBadge = user.is_verified || user.account_type === 'certifie' || user.account_type === 'entreprise';
    const badgeColor = user.account_type === 'entreprise' ? '#F59E0B' : '#3B82F6';

    const accountTypes = [
        { value: 'ordinaire', label: 'Ordinaire', desc: 'Compte standard', color: '#6B7280' },
        { value: 'certifie', label: 'Certifié ✓', desc: 'Vendeur de confiance', color: '#3B82F6' },
        { value: 'premium', label: 'Premium ★', desc: 'Compte premium', color: '#8B5CF6' },
        { value: 'entreprise', label: 'Entreprise 🏢', desc: 'Compte pro', color: '#F59E0B' },
    ];

    return (
        <div className="space-y-6 pb-10">
            {/* ── Retour ── */}
            <button onClick={() => navigate('/users')} className="flex items-center gap-2 text-gray-500 hover:text-gray-700 transition text-sm font-medium">
                <ChevronLeftIcon className="h-4 w-4" />
                Retour aux utilisateurs
            </button>

            {/* ── Header Card ── */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="h-24 bg-gradient-to-r from-slate-800 to-slate-700 relative">
                    <div className="absolute top-3 right-3">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold flex items-center gap-1.5 ${user.is_active ? 'bg-green-500/20 text-green-200 border border-green-500/30' : 'bg-red-500/20 text-red-200 border border-red-500/30'}`}>
                            {user.is_active ? 'ACTIF' : 'SUSPENDU'}
                            <div className={`ml-2 w-2 h-2 rounded-full ${user.is_active ? 'bg-green-400 animate-pulse' : 'bg-red-400'}`}></div>
                        </span>
                    </div>
                </div>
                <div className="px-6 md:px-8 pb-6 relative">
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
                        <div className="flex-1 pt-2 md:pt-0 md:pb-1">
                            <h1 className="text-xl font-bold text-gray-900">{user.name || 'Sans nom'}</h1>
                            <div className="flex flex-wrap gap-x-4 gap-y-1 text-gray-500 text-xs mt-1">
                                <span className="flex items-center"><PhoneIcon className="h-3.5 w-3.5 mr-1" />{user.phone}</span>
                                <span className="flex items-center"><MapPinIcon className="h-3.5 w-3.5 mr-1" />{user.city}</span>
                                <span className="flex items-center"><CalendarDaysIcon className="h-3.5 w-3.5 mr-1" />Inscrit le {user.created_at ? new Date(user.created_at).toLocaleDateString('fr-FR') : '—'}</span>
                            </div>
                        </div>
                        <div className="flex gap-2 flex-shrink-0 pb-1">
                            <button
                                onClick={async () => {
                                    const msg = prompt("Message à " + (user.name || 'utilisateur') + " :");
                                    if (msg?.trim()) { try { await api.post(`/admin/users/${user.id}/message`, { content: msg }); alert("Message envoyé !"); } catch (err) { console.error(err); alert("Erreur envoi"); } }
                                }}
                                className="flex items-center px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium shadow-sm hover:bg-blue-700 transition"
                            ><EnvelopeIcon className="h-4 w-4 mr-1.5" /> Message</button>
                            <button
                                onClick={() => handleToggle('is_hidden', () => api.post(`/admin/users/${user.id}/hide`, { hidden: !user.is_hidden }))}
                                className={`flex items-center px-4 py-2 text-white rounded-xl text-sm font-medium shadow-sm transition ${user.is_hidden ? 'bg-orange-600 hover:bg-orange-700' : 'bg-gray-600 hover:bg-gray-700'}`}
                            >{user.is_hidden ? <><EyeIcon className="h-4 w-4 mr-1.5" /> Afficher</> : <><EyeSlashIcon className="h-4 w-4 mr-1.5" /> Masquer</>}</button>
                            <button
                                onClick={() => handleToggle('is_suspended', () => api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active }))}
                                className={`flex items-center px-4 py-2 text-white rounded-xl text-sm font-medium shadow-sm transition ${user.is_active ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}
                            ><NoSymbolIcon className="h-4 w-4 mr-1.5" />{user.is_active ? 'Bloquer' : 'Débloquer'}</button>
                        </div>
                    </div>
                </div>
            </div>

            {/* ═══════════════════════════════════ */}
            {/* ══  MAIN LAYOUT: Sidebar + Tabs     */}
            {/* ═══════════════════════════════════ */}
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">

                {/* ── LEFT SIDEBAR: Admin Controls ── */}
                <div className="lg:col-span-1 space-y-4">
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Rôles & Permissions</h3>
                        <div className="divide-y divide-gray-100">
                            <ToggleSwitch label="Administrateur" sublabel="Accès au panneau admin" enabled={user.is_admin} loading={toggleLoading.is_admin}
                                onChange={() => handleToggle('is_admin', () => api.patch(`/admin/users/${user.id}/role`, { is_admin: !user.is_admin }))} />
                            <ToggleSwitch label="Vendeur" sublabel="Peut vendre des produits" enabled={user.is_seller} loading={toggleLoading.is_seller}
                                onChange={() => handleToggle('is_seller', () => api.patch(`/admin/users/${user.id}/role`, { is_seller: !user.is_seller }))} />
                            <ToggleSwitch label="Livreur" sublabel="Peut livrer des commandes" enabled={user.is_deliverer} loading={toggleLoading.is_deliverer}
                                onChange={() => handleToggle('is_deliverer', () => api.patch(`/admin/users/${user.id}/role`, { is_deliverer: !user.is_deliverer }))} />
                        </div>
                    </div>

                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Vérification</h3>
                        <div className="divide-y divide-gray-100">
                            <ToggleSwitch label="Compte vérifié" sublabel="Badge bleu sur le profil" enabled={user.is_verified} loading={toggleLoading.is_verified}
                                onChange={() => handleToggle('is_verified', () => api.patch(`/admin/users/${user.id}/verify`, { verified: !user.is_verified }))} />
                            <ToggleSwitch label="Boutique certifiée" sublabel="Badge or magasin" enabled={user.has_certified_shop} loading={toggleLoading.has_certified_shop}
                                onChange={() => handleToggle('has_certified_shop', () => api.patch(`/admin/users/${user.id}/account-type`, { has_certified_shop: !user.has_certified_shop }))} />
                        </div>
                    </div>

                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Type de compte</h3>
                        <div className="space-y-2">
                            {accountTypes.map(type => (
                                <button key={type.value}
                                    onClick={() => handleToggle('account_type', () => api.patch(`/admin/users/${user.id}/account-type`, { account_type: type.value }))}
                                    className={`w-full flex items-center justify-between p-3 rounded-xl border transition text-left ${user.account_type === type.value ? 'border-blue-200 bg-blue-50' : 'border-gray-100 bg-gray-50 hover:bg-gray-100'}`}
                                >
                                    <div>
                                        <p className="text-sm font-medium text-gray-900">{type.label}</p>
                                        <p className="text-xs text-gray-400">{type.desc}</p>
                                    </div>
                                    {user.account_type === type.value && (
                                        <div className="w-5 h-5 rounded-full flex items-center justify-center" style={{ backgroundColor: type.color }}>
                                            <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" /></svg>
                                        </div>
                                    )}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                        <h3 className="text-sm font-bold text-gray-900 uppercase tracking-wide mb-3">Statut</h3>
                        <ToggleSwitch label="Compte actif" sublabel={user.is_active ? "L'utilisateur peut se connecter" : "Compte bloqué"} enabled={user.is_active} loading={toggleLoading.is_suspended}
                            onChange={() => handleToggle('is_suspended', () => api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active }))} />
                    </div>
                </div>

                {/* ── RIGHT CONTENT: Tabs ── */}
                <div className="lg:col-span-3 space-y-6">
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 px-3">
                        <div className="flex space-x-1 overflow-x-auto">
                            <TabButton label="Vue Générale" active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} />
                            <TabButton label="Finance" active={activeTab === 'finance'} onClick={() => setActiveTab('finance')} icon={CurrencyDollarIcon} />
                            <TabButton label="Commandes" active={activeTab === 'orders'} onClick={() => setActiveTab('orders')} icon={ShoppingCartIcon} />
                            <TabButton label="Marketplace" active={activeTab === 'marketplace'} onClick={() => setActiveTab('marketplace')} icon={BuildingStorefrontIcon} />
                            <TabButton label="Conversations" active={activeTab === 'conversations'} onClick={() => setActiveTab('conversations')} icon={ChatBubbleLeftRightIcon} />
                        </div>
                    </div>

                    {/* ══ TAB: VUE GÉNÉRALE ══ */}
                    {activeTab === 'overview' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                                <MiniStat label="Wallet" value={`${user.wallet_balance.toLocaleString('fr-CD')} FC`} icon={CurrencyDollarIcon} color="green" />
                                <MiniStat label="Produits" value={user.stats?.products_count || 0} icon={BuildingStorefrontIcon} color="blue" subtitle={user.is_seller ? 'En vente' : ''} />
                                <MiniStat label="Commandes" value={user.stats?.orders?.total || 0} icon={ShoppingCartIcon} color="amber" subtitle={`${user.stats?.orders?.paid || 0} payées`} />
                                <MiniStat label="Dépensé" value={`${(user.stats?.orders?.total_spent || 0).toLocaleString()} $`} icon={CurrencyDollarIcon} color="rose" />
                                <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" subtitle={`${user.stats?.messages || 0} messages`} />
                                <MiniStat label="Ventes" value={user.stats?.seller_orders?.total || 0} icon={ShoppingCartIcon} color="indigo" subtitle={`${(user.stats?.seller_orders?.revenue || 0).toLocaleString()} $ CA`} />
                            </div>

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

                            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                                <div className="flex justify-between items-center mb-4">
                                    <h3 className="font-bold text-gray-900">Produits</h3>
                                    <button onClick={() => setActiveTab('marketplace')} className="text-blue-600 text-sm font-medium hover:underline">Voir tout</button>
                                </div>
                                <UserProducts userId={id} limit={4} />
                            </div>

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
                        <div className="space-y-6">
                            {/* ── Contrôles: devise + rafraîchir ── */}
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-xl p-1 shadow-sm">
                                    <button
                                        onClick={() => setCurrencyMode('FC')}
                                        className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition ${currencyMode === 'FC' ? 'bg-blue-600 text-white shadow' : 'text-gray-500 hover:text-gray-700'}`}
                                    >FC</button>
                                    <button
                                        onClick={() => setCurrencyMode('USD')}
                                        className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition ${currencyMode === 'USD' ? 'bg-green-600 text-white shadow' : 'text-gray-500 hover:text-gray-700'}`}
                                    >USD $</button>
                                </div>
                                <div className="flex items-center gap-3">
                                    {rateUpdatedAt && (
                                        <p className="text-xs text-gray-400">
                                            1 $ = {exchangeRate.toLocaleString('fr-CD')} FC
                                            <span className="ml-1 text-gray-300">· {new Date(rateUpdatedAt).toLocaleDateString('fr-FR')}</span>
                                        </p>
                                    )}
                                    <button
                                        onClick={fetchUser}
                                        className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-gray-500 bg-gray-100 rounded-lg hover:bg-gray-200 transition"
                                    >
                                        <ArrowPathIcon className="h-3.5 w-3.5" /> Actualiser
                                    </button>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                                <div className="space-y-6">
                                    {/* ── Carte solde ── */}
                                    <div className="bg-gradient-to-br from-blue-600 to-indigo-700 p-6 rounded-2xl text-white shadow-lg relative overflow-hidden">
                                        <div className="absolute top-0 right-0 w-40 h-40 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2" />
                                        <div className="absolute bottom-0 left-0 w-24 h-24 bg-white/5 rounded-full translate-y-1/2 -translate-x-1/2" />
                                        <div className="relative">
                                            <div className="flex justify-between items-start mb-2">
                                                <p className="text-blue-200 text-sm font-medium">Solde Wallet Oli</p>
                                                <button
                                                    onClick={() => { setWalletEditOpen(true); setWalletEditAmount(user.wallet_balance.toString()); }}
                                                    className="flex items-center gap-1 px-3 py-1 bg-white/20 hover:bg-white/30 text-white text-xs font-medium rounded-lg transition backdrop-blur-sm"
                                                    title="Modifier le solde"
                                                >
                                                    <PencilSquareIcon className="h-3.5 w-3.5" />
                                                    Modifier
                                                </button>
                                            </div>
                                            <p className="text-4xl font-bold mt-1">{fmtAmount(user.wallet_balance)}</p>
                                            {currencyMode === 'FC' && (
                                                <p className="text-blue-300 text-xs mt-1">≈ {(user.wallet_balance / exchangeRate).toFixed(2)} $</p>
                                            )}
                                            {currencyMode === 'USD' && (
                                                <p className="text-blue-300 text-xs mt-1">= {user.wallet_balance.toLocaleString('fr-CD')} FC</p>
                                            )}
                                            <div className="border-t border-white/20 mt-4 pt-4 flex justify-between">
                                                <div><p className="text-blue-200 text-xs">Points fidélité</p><p className="text-xl font-bold">{user.reward_points} Pts</p></div>
                                                <div><p className="text-blue-200 text-xs">Dépensé</p><p className="text-xl font-bold">{(user.stats?.orders?.total_spent || 0).toLocaleString()} $</p></div>
                                            </div>
                                        </div>
                                    </div>

                                    {/* ── Formulaire modification solde ── */}
                                    {walletEditOpen && (
                                        <div className="bg-white rounded-2xl border border-amber-200 shadow-md p-5">
                                            <h4 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                                                <PencilSquareIcon className="h-5 w-5 text-amber-500" />
                                                Modifier le solde du wallet
                                            </h4>
                                            <form onSubmit={handleWalletEdit} className="space-y-3">
                                                <div>
                                                    <label className="block text-xs font-medium text-gray-700 mb-1">Nouveau solde (FC)</label>
                                                    <input
                                                        type="number"
                                                        min="0"
                                                        step="1"
                                                        value={walletEditAmount}
                                                        onChange={(e) => setWalletEditAmount(e.target.value)}
                                                        placeholder="Ex: 5000"
                                                        className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                                                        required
                                                    />
                                                    {walletEditAmount && !isNaN(parseFloat(walletEditAmount)) && (
                                                        <p className="text-xs text-gray-400 mt-1">
                                                            ≈ {(parseFloat(walletEditAmount) / exchangeRate).toFixed(2)} $ · Actuel: {user.wallet_balance.toLocaleString('fr-CD')} FC
                                                        </p>
                                                    )}
                                                </div>
                                                <div>
                                                    <label className="block text-xs font-medium text-gray-700 mb-1">Motif (optionnel)</label>
                                                    <input
                                                        type="text"
                                                        value={walletEditReason}
                                                        onChange={(e) => setWalletEditReason(e.target.value)}
                                                        placeholder="Ex: Remboursement, correction, bonus..."
                                                        className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                                                    />
                                                </div>
                                                {walletEditMsg && (
                                                    <div className={`px-3 py-2 rounded-lg text-xs font-medium ${walletEditMsg.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>
                                                        {walletEditMsg.text}
                                                    </div>
                                                )}
                                                <div className="flex gap-2 pt-1">
                                                    <button
                                                        type="submit"
                                                        disabled={walletEditLoading}
                                                        className="flex-1 py-2 bg-blue-600 text-white text-sm font-medium rounded-xl hover:bg-blue-700 transition disabled:opacity-50"
                                                    >
                                                        {walletEditLoading ? 'Mise à jour...' : 'Confirmer'}
                                                    </button>
                                                    <button
                                                        type="button"
                                                        onClick={() => { setWalletEditOpen(false); setWalletEditMsg(null); }}
                                                        className="px-4 py-2 text-gray-600 text-sm font-medium bg-gray-100 rounded-xl hover:bg-gray-200 transition"
                                                    >
                                                        Annuler
                                                    </button>
                                                </div>
                                            </form>
                                        </div>
                                    )}

                                    {/* ── Résumé financier ── */}
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

                                {/* ── Historique transactions ── */}
                                <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                                    <div className="p-5 border-b border-gray-100 flex justify-between items-center">
                                        <h3 className="font-semibold text-gray-900">Historique Transactions</h3>
                                        <span className="text-xs text-gray-400">{user.transactions?.length || 0} entrées</span>
                                    </div>
                                    <div className="divide-y divide-gray-50 max-h-[500px] overflow-y-auto">
                                        {user.transactions?.length > 0 ? user.transactions.map((tx, idx) => (
                                            <div key={tx.id || idx} className="p-4 flex justify-between items-center hover:bg-gray-50 transition">
                                                <div className="flex gap-3 items-center min-w-0">
                                                    <div className={`w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 text-xs ${parseFloat(tx.amount) >= 0 ? 'bg-green-100' : 'bg-red-100'}`}>
                                                        {parseFloat(tx.amount) >= 0 ? '↑' : '↓'}
                                                    </div>
                                                    <div className="min-w-0">
                                                        <p className="text-gray-700 text-sm truncate">{tx.description || tx.type}</p>
                                                        <p className="text-gray-400 text-xs">{new Date(tx.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit' })}</p>
                                                    </div>
                                                </div>
                                                <span className={`font-semibold text-sm flex-shrink-0 ml-2 ${parseFloat(tx.amount) >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                                                    {parseFloat(tx.amount) >= 0 ? '+' : ''}
                                                    {currencyMode === 'FC'
                                                        ? `${parseFloat(tx.amount).toLocaleString('fr-CD')} FC`
                                                        : `${(parseFloat(tx.amount) / exchangeRate).toFixed(2)} $`}
                                                </span>
                                            </div>
                                        )) : <div className="p-10 text-center text-gray-400">Aucune transaction</div>}
                                    </div>
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

                    {/* ══ TAB: CONVERSATIONS ══ */}
                    {activeTab === 'conversations' && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <MiniStat label="Conversations" value={user.stats?.conversations || 0} icon={ChatBubbleLeftRightIcon} color="purple" />
                                <MiniStat label="Messages envoyés" value={user.stats?.messages || 0} icon={EnvelopeIcon} color="blue" />
                            </div>

                            <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                                <div className="p-5 border-b border-gray-100">
                                    <h3 className="font-bold text-gray-900">Toutes les conversations</h3>
                                    <p className="text-xs text-gray-400 mt-1">Échanges entre cet utilisateur et les autres membres de la plateforme</p>
                                </div>
                                <UserConversations userId={id} />
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
