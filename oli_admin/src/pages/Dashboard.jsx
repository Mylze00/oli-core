import { useEffect, useState } from 'react';
import {
    UserGroupIcon,
    ShoppingBagIcon,
    CurrencyDollarIcon,
    CubeIcon,
    ExclamationTriangleIcon,
    TruckIcon,
    ChatBubbleLeftRightIcon,
    BuildingStorefrontIcon,
} from '@heroicons/react/24/outline';
import api from '../services/api';
import StatsCard from '../components/Dashboard/StatsCard';
import RevenueChart from '../components/Dashboard/RevenueChart';
import UserGrowthChart from '../components/Dashboard/UserGrowthChart';
import RecentOrdersTable from '../components/Dashboard/RecentOrdersTable';

const STATUS_LABELS = {
    user_registered: { label: 'Nouvel utilisateur', emoji: '👤', color: 'bg-blue-500' },
    order_created: { label: 'Nouvelle commande', emoji: '📦', color: 'bg-green-500' },
    product_added: { label: 'Nouveau produit', emoji: '🛍️', color: 'bg-violet-500' },
    shop_created: { label: 'Nouvelle boutique', emoji: '🏪', color: 'bg-amber-500' },
};

export default function Dashboard() {
    const [stats, setStats] = useState(null);
    const [activity, setActivity] = useState([]);
    const [loading, setLoading] = useState(true);
    const [timeRange, setTimeRange] = useState('7d');

    useEffect(() => {
        fetchStats();
    }, [timeRange]);

    const fetchStats = async () => {
        setLoading(true);
        try {
            const results = await Promise.allSettled([
                api.get(`/admin/stats/overview?range=${timeRange}`),
                api.get('/admin/stats/revenue'),
                api.get('/admin/stats/users-growth'),
                api.get('/admin/orders/recent'),
                api.get('/admin/stats/activity'),
            ]);

            const [overview, revenue, growth, recent, activityRes] = results;

            setStats({
                ...(overview.status === 'fulfilled' ? overview.value.data : {}),
                revenueData: revenue.status === 'fulfilled' ? revenue.value.data : [],
                usersGrowth: growth.status === 'fulfilled' ? growth.value.data : [],
                recentOrders: recent.status === 'fulfilled' ? recent.value.data : [],
            });

            if (activityRes.status === 'fulfilled') {
                setActivity(activityRes.value.data);
            }
        } catch (error) {
            console.error("Erreur dashboard:", error);
        } finally {
            setLoading(false);
        }
    };

    const timeAgo = (date) => {
        const seconds = Math.floor((new Date() - new Date(date)) / 1000);
        if (seconds < 60) return 'À l\'instant';
        if (seconds < 3600) return `Il y a ${Math.floor(seconds / 60)} min`;
        if (seconds < 86400) return `Il y a ${Math.floor(seconds / 3600)}h`;
        return `Il y a ${Math.floor(seconds / 86400)}j`;
    };

    if (loading && !stats) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="text-center">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
                    <p className="text-gray-500 font-medium">Chargement du centre de commande...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* ── Header ── */}
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Centre de Commande Oli</h1>
                    <p className="text-sm text-gray-500 mt-1">Vue d'ensemble en temps réel de l'écosystème</p>
                </div>
                <div className="flex gap-1 bg-white rounded-xl p-1 shadow-sm border border-gray-100">
                    {['24h', '7d', '30d', '1y'].map((range) => (
                        <button
                            key={range}
                            onClick={() => setTimeRange(range)}
                            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${timeRange === range
                                ? 'bg-blue-600 text-white shadow-md'
                                : 'text-gray-500 hover:bg-gray-100'
                                }`}
                        >
                            {range.toUpperCase()}
                        </button>
                    ))}
                </div>
            </div>

            {/* ── Ligne 1 : 8 KPIs ── */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                <StatsCard
                    title="Chiffre d'Affaires"
                    value={`${Number(stats?.orders?.revenue_total || 0).toLocaleString()} $`}
                    trend={stats?.orders?.revenue_trend}
                    icon={<CurrencyDollarIcon className="h-6 w-6 text-green-600" />}
                    subtitle={`${Number(stats?.orders?.revenue_period || 0).toLocaleString()} $ cette période`}
                    link="/orders"
                />
                <StatsCard
                    title="Utilisateurs"
                    value={Number(stats?.users?.total || 0).toLocaleString()}
                    trend={stats?.users?.trend}
                    icon={<UserGroupIcon className="h-6 w-6 text-blue-600" />}
                    subtitle={`${stats?.users?.today || 0} aujourd'hui · ${stats?.users?.sellers || 0} vendeurs`}
                    link="/users"
                />
                <StatsCard
                    title="Produits Actifs"
                    value={Number(stats?.products?.active || 0).toLocaleString()}
                    trend={stats?.products?.trend}
                    icon={<CubeIcon className="h-6 w-6 text-violet-600" />}
                    subtitle={`${stats?.products?.total || 0} total`}
                    link="/products"
                />
                <StatsCard
                    title="Commandes"
                    value={Number(stats?.orders?.total || 0).toLocaleString()}
                    trend={stats?.orders?.orders_trend}
                    icon={<ShoppingBagIcon className="h-6 w-6 text-indigo-600" />}
                    subtitle={`${stats?.orders?.paid || 0} payées · ${stats?.orders?.pending_shipping || 0} en attente`}
                    link="/orders"
                />
                <StatsCard
                    title="Boutiques"
                    value={stats?.shops?.total || 0}
                    icon={<BuildingStorefrontIcon className="h-6 w-6 text-amber-600" />}
                    subtitle={`${stats?.shops?.period || 0} nouvelles cette période`}
                    link="/shops"
                />
                <StatsCard
                    title="Conversations"
                    value={Number(stats?.chat?.total_conversations || 0).toLocaleString()}
                    icon={<ChatBubbleLeftRightIcon className="h-6 w-6 text-cyan-600" />}
                    subtitle={`${stats?.chat?.messages_period || 0} messages cette période`}
                    link="/disputes"
                />
                <StatsCard
                    title="Livraisons"
                    value={stats?.deliveries?.completed || 0}
                    icon={<TruckIcon className="h-6 w-6 text-emerald-600" />}
                    subtitle={`${stats?.deliveries?.pending || 0} en cours`}
                    color={stats?.deliveries?.pending > 0 ? 'bg-emerald-50' : 'bg-white'}
                    link="/delivery"
                />
                <StatsCard
                    title="Tickets Support"
                    value={stats?.tickets?.active || 0}
                    icon={<ExclamationTriangleIcon className="h-6 w-6 text-red-600" />}
                    subtitle={`${stats?.tickets?.total || 0} total`}
                    color={stats?.tickets?.active > 0 ? 'bg-red-50' : 'bg-white'}
                    link="/support"
                />
            </div>

            {/* ── Ligne 2 : Graphiques ── */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                    <h3 className="text-lg font-semibold mb-4 text-gray-800">Analyse des Revenus</h3>
                    <RevenueChart data={stats?.revenueData} />
                </div>
                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                    <h3 className="text-lg font-semibold mb-4 text-gray-800">Acquisition Utilisateurs</h3>
                    <UserGrowthChart data={stats?.usersGrowth} />
                </div>
            </div>

            {/* ── Ligne 3 : Commandes + Catégories + Activité ── */}
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
                {/* Commandes Récentes */}
                <div className="xl:col-span-1 bg-white rounded-2xl shadow-sm border border-gray-100">
                    <div className="p-5 border-b border-gray-100 flex justify-between items-center">
                        <h3 className="text-base font-semibold text-gray-800">Dernières Commandes</h3>
                    </div>
                    <RecentOrdersTable orders={stats?.recentOrders} />
                </div>

                {/* Top Catégories */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                    <h3 className="text-base font-semibold text-gray-800 mb-4">Top Catégories</h3>
                    {stats?.top_categories?.length > 0 ? (
                        <div className="space-y-3">
                            {stats.top_categories.map((cat, i) => {
                                const maxCount = stats.top_categories[0]?.count || 1;
                                const percentage = Math.round((cat.count / maxCount) * 100);
                                return (
                                    <div key={i}>
                                        <div className="flex justify-between items-center mb-1">
                                            <span className="text-sm font-medium text-gray-700">{cat.name}</span>
                                            <span className="text-xs font-semibold text-gray-500">{cat.count} produits</span>
                                        </div>
                                        <div className="w-full bg-gray-100 rounded-full h-2">
                                            <div
                                                className="h-2 rounded-full bg-gradient-to-r from-blue-500 to-violet-500 transition-all duration-500"
                                                style={{ width: `${percentage}%` }}
                                            />
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    ) : (
                        <p className="text-gray-400 text-sm text-center py-6">Aucune catégorie</p>
                    )}
                </div>

                {/* Activité Récente */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                    <div className="p-5 border-b border-gray-100">
                        <h3 className="text-base font-semibold text-gray-800">Activité Récente</h3>
                    </div>
                    <div className="divide-y divide-gray-50 max-h-[400px] overflow-y-auto">
                        {activity.length > 0 ? activity.map((item, i) => {
                            const meta = STATUS_LABELS[item.type] || { label: 'Activité', emoji: '📌', color: 'bg-gray-500' };
                            return (
                                <div key={i} className="px-5 py-3 flex items-start gap-3 hover:bg-gray-50 transition-colors">
                                    <div className={`w-8 h-8 ${meta.color} rounded-full flex items-center justify-center text-white text-sm flex-shrink-0`}>
                                        {meta.emoji}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm text-gray-800 font-medium truncate">
                                            {item.type === 'user_registered' && `${item.name || 'Utilisateur'} inscrit`}
                                            {item.type === 'order_created' && `Commande de ${Number(item.total_amount || 0).toLocaleString()} $`}
                                            {item.type === 'product_added' && `${item.name} ajouté`}
                                            {item.type === 'shop_created' && `Boutique "${item.name}" créée`}
                                        </p>
                                        <p className="text-xs text-gray-400 mt-0.5">
                                            {item.user_name || item.seller_name || item.owner_name || ''} · {timeAgo(item.created_at)}
                                        </p>
                                    </div>
                                </div>
                            );
                        }) : (
                            <div className="p-6 text-center text-gray-400 text-sm">Aucune activité récente</div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
