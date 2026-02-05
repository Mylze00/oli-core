import { useEffect, useState } from 'react';
import {
    UserGroupIcon,
    ShoppingBagIcon,
    CurrencyDollarIcon,
    CubeIcon,
    ExclamationTriangleIcon, // Pour les alertes
    TruckIcon,               // Pour la logistique
    ArrowTrendingUpIcon      // Pour le taux de conversion
} from '@heroicons/react/24/outline';
import api from '../services/api';
import StatsCard from '../components/Dashboard/StatsCard';
import RevenueChart from '../components/Dashboard/RevenueChart';
import UserGrowthChart from '../components/Dashboard/UserGrowthChart';
import RecentOrdersTable from '../components/Dashboard/RecentOrdersTable'; // À créer

export default function Dashboard() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [timeRange, setTimeRange] = useState('7d'); // Filtre temporel dynamique

    useEffect(() => {
        fetchStats();
    }, [timeRange]);

    const fetchStats = async () => {
        setLoading(true);
        try {
            const [overview, revenue, growth, recent] = await Promise.all([
                api.get(`/admin/stats/overview?range=${timeRange}`),
                api.get('/admin/stats/revenue'),
                api.get('/admin/stats/users-growth'),
                api.get('/admin/orders/recent') // Nouveau
            ]);

            setStats({
                ...overview.data,
                revenueData: revenue.data,
                usersGrowth: growth.data,
                recentOrders: recent.data
            });
        } catch (error) {
            console.error("Erreur lors de l'actualisation des données:", error);
        } finally {
            setLoading(false);
        }
    };

    if (loading && !stats) return <div className="p-8 text-center">Initialisation du centre de commande...</div>;

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* Header avec sélecteur de période */}
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Vue d'ensemble de la Marketplace</h1>
                    <p className="text-sm text-gray-500">Données en temps réel sur l'activité globale.</p>
                </div>
                <div className="flex gap-2">
                    {['24h', '7d', '30d', '1y'].map((range) => (
                        <button
                            key={range}
                            onClick={() => setTimeRange(range)}
                            className={`px-4 py-2 rounded-lg text-sm font-medium transition ${timeRange === range ? 'bg-blue-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-100'
                                }`}
                        >
                            {range.toUpperCase()}
                        </button>
                    ))}
                </div>
            </div>

            {/* Grille de KPIs étendue */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <StatsCard
                    title="Chiffre d'Affaires"
                    value={`${Number(stats?.orders?.revenue_total || 0).toLocaleString()} $`}
                    trend="+12.5%" // Idéalement calculé par le back-end
                    icon={<CurrencyDollarIcon className="h-6 w-6 text-green-600" />}
                />
                <StatsCard
                    title="Commandes à Expédier"
                    value={stats?.orders?.pending_shipping || 0}
                    icon={<TruckIcon className="h-6 w-6 text-amber-600" />}
                    color="bg-amber-50"
                />
                <StatsCard
                    title="Taux de Conversion"
                    value="3.24 %"
                    icon={<ArrowTrendingUpIcon className="h-6 w-6 text-indigo-600" />}
                />
                <StatsCard
                    title="Litiges Ouverts"
                    value={stats?.tickets?.active_disputes || 0}
                    icon={<ExclamationTriangleIcon className="h-6 w-6 text-red-600" />}
                    color="bg-red-50"
                />
            </div>

            {/* Graphiques principaux */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h3 className="text-lg font-semibold mb-4">Analyse des Revenus</h3>
                    <RevenueChart data={stats?.revenueData} />
                </div>
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h3 className="text-lg font-semibold mb-4">Acquisition Utilisateurs</h3>
                    <UserGrowthChart data={stats?.usersGrowth} />
                </div>
            </div>

            {/* Section basse : Table des commandes récentes & Top Produits */}
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
                <div className="xl:col-span-2 bg-white rounded-xl shadow-sm border border-gray-100">
                    <div className="p-6 border-b border-gray-100 flex justify-between items-center">
                        <h3 className="text-lg font-semibold">Dernières Transactions</h3>
                        <button className="text-blue-600 text-sm hover:underline">Voir tout</button>
                    </div>
                    <RecentOrdersTable orders={stats?.recentOrders} />
                </div>

                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h3 className="text-lg font-semibold mb-4">Top Catégories</h3>
                    {/* Un simple composant de liste ici */}
                    <ul className="space-y-4">
                        {stats?.top_categories?.map((cat, i) => (
                            <li key={i} className="flex justify-between items-center">
                                <span className="text-gray-600">{cat.name}</span>
                                <span className="font-semibold text-gray-900">{cat.sales} ventes</span>
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
        </div>
    );
}
