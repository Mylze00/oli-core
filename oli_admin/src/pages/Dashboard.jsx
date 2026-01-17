import { useEffect, useState } from 'react';
import {
    UserGroupIcon,
    ShoppingBagIcon,
    CurrencyDollarIcon,
    CubeIcon
} from '@heroicons/react/24/outline';
import api from '../services/api';
import StatsCard from '../components/Dashboard/StatsCard';
import RevenueChart from '../components/Dashboard/RevenueChart';
import UserGrowthChart from '../components/Dashboard/UserGrowthChart';

export default function Dashboard() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchStats();
    }, []);

    const fetchStats = async () => {
        try {
            const [overview, revenue, growth] = await Promise.all([
                api.get('/admin/stats/overview'),
                api.get('/admin/stats/revenue'),
                api.get('/admin/stats/users-growth')
            ]);

            setStats({
                ...overview.data,
                revenueData: revenue.data,
                usersGrowth: growth.data
            });
        } catch (error) {
            console.error("Erreur stats:", error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div>Chargement...</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-8">Vue d'ensemble</h1>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <StatsCard
                    title="Utilisateurs"
                    value={stats?.users?.total_users || 0}
                    icon={<UserGroupIcon className="h-6 w-6 text-blue-600" />}
                />
                <StatsCard
                    title="Produits Actifs"
                    value={stats?.products?.active_products || 0}
                    icon={<ShoppingBagIcon className="h-6 w-6 text-indigo-600" />}
                />
                <StatsCard
                    title="Commandes"
                    value={stats?.orders?.total_orders || 0}
                    icon={<CubeIcon className="h-6 w-6 text-amber-600" />}
                />
                <StatsCard
                    title="Revenus (24h)"
                    value={`$${stats?.orders?.revenue_today || 0}`}
                    icon={<CurrencyDollarIcon className="h-6 w-6 text-green-600" />}
                />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <RevenueChart data={stats?.revenueData} />
                <UserGrowthChart data={stats?.usersGrowth} />
            </div>
        </div>
    );
}
