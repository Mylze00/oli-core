import { useState, useEffect } from 'react';
import { sellerAPI } from '../services/api';
import { TrendingUp, Package, ShoppingCart, DollarSign } from 'lucide-react';

export default function SellerDashboard() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        loadDashboard();
    }, []);

    const loadDashboard = async () => {
        try {
            setLoading(true);
            const data = await sellerAPI.getDashboard();
            setStats(data);
        } catch (err) {
            console.error('Error loading dashboard:', err);
            setError('Erreur de chargement des statistiques');
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-screen">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="p-8">
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
                    {error}
                </div>
            </div>
        );
    }

    const statCards = [
        {
            title: 'Produits Actifs',
            value: stats?.active_products || 0,
            total: stats?.total_products || 0,
            icon: Package,
            color: 'blue',
            subtitle: `${stats?.total_products || 0} total`
        },
        {
            title: 'Commandes (Mois)',
            value: stats?.orders_this_month || 0,
            icon: ShoppingCart,
            color: 'green',
            subtitle: `${stats?.pending_orders || 0} en attente`
        },
        {
            title: 'Revenu (Mois)',
            value: `$${parseFloat(stats?.revenue_this_month || 0).toFixed(2)}`,
            icon: DollarSign,
            color: 'purple',
            subtitle: `$${parseFloat(stats?.total_revenue || 0).toFixed(2)} total`
        },
        {
            title: 'Ventes Totales',
            value: stats?.total_sales || 0,
            icon: TrendingUp,
            color: 'orange',
            subtitle: 'Articles vendus'
        }
    ];

    const colorClasses = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        purple: 'bg-purple-50 text-purple-600',
        orange: 'bg-orange-50 text-orange-600'
    };

    return (
        <div className="p-8">
            <div className="mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Tableau de bord</h1>
                <p className="text-gray-500 mt-1">Vue d'ensemble de votre activité</p>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                {statCards.map((stat, index) => {
                    const Icon = stat.icon;
                    return (
                        <div key={index} className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
                            <div className="flex items-center justify-between mb-4">
                                <h3 className="text-gray-500 text-sm font-medium">{stat.title}</h3>
                                <div className={`p-2 rounded-lg ${colorClasses[stat.color]}`}>
                                    <Icon size={20} />
                                </div>
                            </div>
                            <p className="text-3xl font-bold text-gray-900 mb-1">{stat.value}</p>
                            <span className="text-sm text-gray-400">{stat.subtitle}</span>
                        </div>
                    );
                })}
            </div>

            {/* Quick Actions */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Actions Rapides</h2>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <a
                        href="/products/new"
                        className="flex items-center gap-3 p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors"
                    >
                        <Package className="text-blue-600" size={24} />
                        <div>
                            <p className="font-medium text-gray-900">Nouveau Produit</p>
                            <p className="text-sm text-gray-500">Ajouter un article</p>
                        </div>
                    </a>
                    <a
                        href="/products"
                        className="flex items-center gap-3 p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-green-500 hover:bg-green-50 transition-colors"
                    >
                        <ShoppingCart className="text-green-600" size={24} />
                        <div>
                            <p className="font-medium text-gray-900">Mes Produits</p>
                            <p className="text-sm text-gray-500">Gérer le catalogue</p>
                        </div>
                    </a>
                    <a
                        href="/orders"
                        className="flex items-center gap-3 p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-colors"
                    >
                        <TrendingUp className="text-purple-600" size={24} />
                        <div>
                            <p className="font-medium text-gray-900">Commandes</p>
                            <p className="text-sm text-gray-500">Voir les commandes</p>
                        </div>
                    </a>
                </div>
            </div>

            {/* Welcome Message for New Sellers */}
            {stats?.total_products === 0 && (
                <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-6">
                    <h3 className="text-lg font-semibold text-blue-900 mb-2">
                        Bienvenue sur Oli Seller Center ! 🎉
                    </h3>
                    <p className="text-blue-700 mb-4">
                        Commencez par ajouter votre premier produit pour démarrer vos ventes.
                    </p>
                    <a
                        href="/products/new"
                        className="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
                    >
                        Ajouter mon premier produit
                    </a>
                </div>
            )}
        </div>
    );
}
