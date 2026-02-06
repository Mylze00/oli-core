import { useState, useEffect } from 'react';
import { sellerAPI, shopAPI } from '../services/api';
import socketService from '../services/socket';
import {
    TrendingUp, Package, ShoppingCart, DollarSign,
    Eye, Percent, BarChart3, AlertTriangle, Clock,
    ArrowUpRight, ArrowDownRight, RefreshCw
} from 'lucide-react';
import CertificationStatus from '../components/CertificationStatus';
import ProfileSettings from '../components/ProfileSettings';

export default function SellerDashboard() {
    const [stats, setStats] = useState(null);
    const [analytics, setAnalytics] = useState(null);
    const [topProducts, setTopProducts] = useState([]);
    const [productsToOptimize, setProductsToOptimize] = useState([]);
    const [recentOrders, setRecentOrders] = useState([]);
    const [salesChart, setSalesChart] = useState(null);
    const [certification, setCertification] = useState(null);
    const [shop, setShop] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [chartPeriod, setChartPeriod] = useState('7d');
    const [showNotification, setShowNotification] = useState(false);
    const [notificationMessage, setNotificationMessage] = useState('');

    useEffect(() => {
        loadDashboard();

        // Initialize Socket.IO for real-time notifications
        const token = localStorage.getItem('seller_token');
        if (token) {
            socketService.connect(token);

            // Listen for new order notifications
            socketService.on('new_notification', (data) => {
                console.log('📨 Notification reçue:', data);

                if (data.type === 'order') {
                    // Show toast notification
                    setNotificationMessage(data.title || 'Nouvelle commande !');
                    setShowNotification(true);
                    setTimeout(() => setShowNotification(false), 5000);

                    // Refresh dashboard data
                    loadDashboard();
                }
            });
        }

        // Cleanup on unmount
        return () => {
            socketService.off('new_notification');
            socketService.disconnect();
        };
    }, []);

    useEffect(() => {
        loadSalesChart(chartPeriod);
    }, [chartPeriod]);

    const loadDashboard = async () => {
        try {
            setLoading(true);
            const [
                analyticsData,
                topProductsData,
                productsWithoutSalesData,
                recentOrdersData,
                certData,
                shopsData
            ] = await Promise.all([
                sellerAPI.getAnalyticsOverview().catch(() => null),
                sellerAPI.getTopProducts(5).catch(() => []),
                sellerAPI.getProductsWithoutSales(30).catch(() => []),
                sellerAPI.getRecentOrders(5).catch(() => []),
                sellerAPI.getCertification().catch(() => null),
                shopAPI.getMyShops().catch(() => [])
            ]);

            setAnalytics(analyticsData);
            setStats(analyticsData); // For backward compatibility
            setTopProducts(topProductsData);
            setProductsToOptimize(productsWithoutSalesData);
            setRecentOrders(recentOrdersData);
            setCertification(certData);

            if (shopsData && shopsData.length > 0) {
                setShop(shopsData[0]);
            }

            // Load initial chart
            await loadSalesChart('7d');
        } catch (err) {
            console.error('Error loading dashboard:', err);
            setError('Erreur de chargement des statistiques');
        } finally {
            setLoading(false);
        }
    };

    const loadSalesChart = async (period) => {
        try {
            const chartData = await sellerAPI.getAnalyticsSalesChart(period);
            setSalesChart(chartData);
        } catch (err) {
            console.error('Error loading sales chart:', err);
        }
    };

    const formatCurrency = (amount) => {
        const num = parseFloat(amount) || 0;
        if (num >= 1000000) {
            return `$${(num / 1000000).toFixed(1)}M`;
        } else if (num >= 1000) {
            return `$${(num / 1000).toFixed(1)}K`;
        }
        return `$${num.toFixed(2)}`;
    };

    const getImageUrl = (images) => {
        if (!images || images.length === 0) return null;
        const firstImage = Array.isArray(images) ? images[0] : images;
        if (firstImage.startsWith('http')) return firstImage;
        const CLOUD_NAME = 'dbfpnxjmm';
        return `https://res.cloudinary.com/${CLOUD_NAME}/image/upload/${firstImage}`;
    };

    const getStatusColor = (status) => {
        const colors = {
            pending: 'bg-yellow-100 text-yellow-800',
            confirmed: 'bg-blue-100 text-blue-800',
            processing: 'bg-indigo-100 text-indigo-800',
            shipped: 'bg-purple-100 text-purple-800',
            delivered: 'bg-green-100 text-green-800',
            cancelled: 'bg-red-100 text-red-800'
        };
        return colors[status] || 'bg-gray-100 text-gray-800';
    };

    const getStatusLabel = (status) => {
        const labels = {
            pending: 'En attente',
            confirmed: 'Confirmée',
            processing: 'En préparation',
            shipped: 'Expédiée',
            delivered: 'Livrée',
            cancelled: 'Annulée'
        };
        return labels[status] || status;
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
                    <button
                        onClick={loadDashboard}
                        className="ml-4 text-red-600 underline hover:no-underline"
                    >
                        Réessayer
                    </button>
                </div>
            </div>
        );
    }

    // KPI Cards Configuration
    const kpiCards = [
        {
            title: 'Revenu du Mois',
            value: formatCurrency(analytics?.revenue_this_month || 0),
            subtitle: `${formatCurrency(analytics?.total_revenue || 0)} total`,
            icon: DollarSign,
            color: 'emerald',
            trend: '+12%' // TODO: Calculate real trend
        },
        {
            title: 'Commandes',
            value: analytics?.orders_this_month || 0,
            subtitle: `${analytics?.pending_orders || 0} en attente`,
            icon: ShoppingCart,
            color: 'blue',
            alert: analytics?.pending_orders > 0
        },
        {
            title: 'Taux de Conversion',
            value: `${analytics?.conversion_rate || 0}%`,
            subtitle: 'Visiteurs → Acheteurs',
            icon: Percent,
            color: 'violet'
        },
        {
            title: 'Panier Moyen',
            value: formatCurrency(analytics?.average_cart || 0),
            subtitle: 'Par commande',
            icon: BarChart3,
            color: 'amber'
        },
        {
            title: 'Vues Totales',
            value: analytics?.total_views || 0,
            subtitle: 'Sur vos produits',
            icon: Eye,
            color: 'cyan'
        },
        {
            title: 'Produits Actifs',
            value: analytics?.active_products || 0,
            subtitle: `${analytics?.total_products || 0} total`,
            icon: Package,
            color: 'rose'
        }
    ];

    const colorClasses = {
        emerald: 'bg-emerald-50 text-emerald-600 border-emerald-200',
        blue: 'bg-blue-50 text-blue-600 border-blue-200',
        violet: 'bg-violet-50 text-violet-600 border-violet-200',
        amber: 'bg-amber-50 text-amber-600 border-amber-200',
        cyan: 'bg-cyan-50 text-cyan-600 border-cyan-200',
        rose: 'bg-rose-50 text-rose-600 border-rose-200'
    };

    return (
        <div className="p-8 bg-gray-50 min-h-screen">
            {/* Toast Notification */}
            {showNotification && (
                <div className="fixed top-4 right-4 z-50 bg-green-500 text-white px-6 py-4 rounded-lg shadow-lg animate-bounce">
                    <div className="flex items-center gap-3">
                        <ShoppingCart size={24} />
                        <div>
                            <p className="font-semibold">{notificationMessage}</p>
                            <p className="text-sm text-green-100">Le dashboard a été actualisé</p>
                        </div>
                    </div>
                </div>
            )}

            {/* Header */}
            <div className="flex justify-between items-center mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900">Tableau de bord</h1>
                    <p className="text-gray-500 mt-1">Vue d'ensemble de votre activité</p>
                </div>
                <button
                    onClick={loadDashboard}
                    className="flex items-center gap-2 px-4 py-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
                >
                    <RefreshCw size={18} />
                    Actualiser
                </button>
            </div>

            {/* KPI Cards Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-8">
                {kpiCards.map((kpi, index) => {
                    const Icon = kpi.icon;
                    return (
                        <div
                            key={index}
                            className={`bg-white p-5 rounded-xl shadow-sm border ${kpi.alert ? 'border-orange-300 ring-2 ring-orange-100' : 'border-gray-100'} hover:shadow-md transition-shadow`}
                        >
                            <div className="flex items-center justify-between mb-3">
                                <div className={`p-2.5 rounded-lg ${colorClasses[kpi.color]}`}>
                                    <Icon size={20} />
                                </div>
                                {kpi.trend && (
                                    <span className="flex items-center text-xs text-emerald-600 font-medium">
                                        <ArrowUpRight size={14} />
                                        {kpi.trend}
                                    </span>
                                )}
                            </div>
                            <p className="text-2xl font-bold text-gray-900 mb-1">{kpi.value}</p>
                            <p className="text-xs text-gray-500">{kpi.title}</p>
                            <p className="text-xs text-gray-400 mt-1">{kpi.subtitle}</p>
                        </div>
                    );
                })}
            </div>

            {/* Main Content Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">

                {/* Sales Chart */}
                <div className="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex justify-between items-center mb-6">
                        <h2 className="text-lg font-semibold text-gray-900">Evolution des Ventes</h2>
                        <div className="flex gap-2">
                            {['7d', '30d', '12m'].map((period) => (
                                <button
                                    key={period}
                                    onClick={() => setChartPeriod(period)}
                                    className={`px-3 py-1.5 text-sm rounded-lg transition-colors ${chartPeriod === period
                                        ? 'bg-blue-600 text-white'
                                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                                        }`}
                                >
                                    {period === '7d' ? '7 jours' : period === '30d' ? '30 jours' : '12 mois'}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Simple Chart Visualization */}
                    <div className="h-64 flex items-end justify-between gap-2 px-4">
                        {salesChart?.data?.length > 0 ? (
                            salesChart.data.slice(-14).map((item, index) => {
                                const maxRevenue = Math.max(...salesChart.data.map(d => parseFloat(d.revenue) || 0), 1);
                                const height = ((parseFloat(item.revenue) || 0) / maxRevenue) * 100;
                                return (
                                    <div key={index} className="flex-1 flex flex-col items-center group">
                                        <div className="relative w-full">
                                            <div
                                                className="w-full bg-gradient-to-t from-blue-500 to-blue-400 rounded-t-md transition-all group-hover:from-blue-600 group-hover:to-blue-500"
                                                style={{ height: `${Math.max(height, 4)}%`, minHeight: '8px' }}
                                            />
                                            <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 bg-gray-800 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                                                {formatCurrency(item.revenue)}
                                            </div>
                                        </div>
                                        <span className="text-xs text-gray-400 mt-2 truncate max-w-full">
                                            {item.date?.slice(-5)}
                                        </span>
                                    </div>
                                );
                            })
                        ) : (
                            <div className="flex-1 flex items-center justify-center text-gray-400">
                                <div className="text-center">
                                    <BarChart3 size={48} className="mx-auto mb-2 opacity-50" />
                                    <p>Pas encore de données de ventes</p>
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Recent Orders */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-semibold text-gray-900">Commandes Récentes</h2>
                        <a href="/orders" className="text-sm text-blue-600 hover:underline">Voir tout</a>
                    </div>

                    {recentOrders.length > 0 ? (
                        <div className="space-y-3">
                            {recentOrders.map((order) => (
                                <div key={order.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                                    <div className="flex-1">
                                        <p className="font-medium text-gray-900 text-sm">
                                            {order.customer_name || 'Client'}
                                        </p>
                                        <p className="text-xs text-gray-500">
                                            {order.items_count} article(s) • {new Date(order.created_at).toLocaleDateString('fr-FR')}
                                        </p>
                                    </div>
                                    <div className="text-right">
                                        <p className="font-semibold text-gray-900 text-sm">
                                            {formatCurrency(order.total_amount)}
                                        </p>
                                        <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${getStatusColor(order.status)}`}>
                                            {getStatusLabel(order.status)}
                                        </span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="text-center py-8 text-gray-400">
                            <Clock size={40} className="mx-auto mb-2 opacity-50" />
                            <p>Aucune commande récente</p>
                        </div>
                    )}
                </div>
            </div>

            {/* Top Products & Products to Optimize */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">

                {/* Top Products */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                            <TrendingUp size={20} className="text-emerald-500" />
                            Top Produits
                        </h2>
                    </div>

                    {topProducts.length > 0 ? (
                        <div className="space-y-3">
                            {topProducts.map((product, index) => (
                                <div key={product.id} className="flex items-center gap-4 p-3 bg-gray-50 rounded-lg">
                                    <span className="w-6 h-6 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center text-sm font-bold">
                                        {index + 1}
                                    </span>
                                    {getImageUrl(product.images) ? (
                                        <img
                                            src={getImageUrl(product.images)}
                                            alt={product.name}
                                            className="w-10 h-10 rounded-lg object-cover"
                                        />
                                    ) : (
                                        <div className="w-10 h-10 rounded-lg bg-gray-200 flex items-center justify-center">
                                            <Package size={16} className="text-gray-400" />
                                        </div>
                                    )}
                                    <div className="flex-1 min-w-0">
                                        <p className="font-medium text-gray-900 text-sm truncate">{product.name}</p>
                                        <p className="text-xs text-gray-500">{product.units_sold} vendus • {product.views} vues</p>
                                    </div>
                                    <div className="text-right">
                                        <p className="font-semibold text-emerald-600 text-sm">{formatCurrency(product.revenue)}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="text-center py-8 text-gray-400">
                            <TrendingUp size={40} className="mx-auto mb-2 opacity-50" />
                            <p>Pas encore de ventes</p>
                        </div>
                    )}
                </div>

                {/* Products to Optimize */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                            <AlertTriangle size={20} className="text-amber-500" />
                            À Optimiser
                        </h2>
                        <span className="text-xs text-gray-500">Sans ventes (30j)</span>
                    </div>

                    {productsToOptimize.length > 0 ? (
                        <div className="space-y-3">
                            {productsToOptimize.slice(0, 5).map((product) => (
                                <div key={product.id} className="flex items-center gap-4 p-3 bg-amber-50 rounded-lg border border-amber-100">
                                    {getImageUrl(product.images) ? (
                                        <img
                                            src={getImageUrl(product.images)}
                                            alt={product.name}
                                            className="w-10 h-10 rounded-lg object-cover"
                                        />
                                    ) : (
                                        <div className="w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center">
                                            <Package size={16} className="text-amber-600" />
                                        </div>
                                    )}
                                    <div className="flex-1 min-w-0">
                                        <p className="font-medium text-gray-900 text-sm truncate">{product.name}</p>
                                        <p className="text-xs text-amber-600">{product.views} vues • 0 ventes</p>
                                    </div>
                                    <a
                                        href={`/products/${product.id}/edit`}
                                        className="px-3 py-1 text-xs bg-amber-500 text-white rounded-lg hover:bg-amber-600 transition-colors"
                                    >
                                        Optimiser
                                    </a>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="text-center py-8 text-emerald-500">
                            <div className="w-12 h-12 rounded-full bg-emerald-100 flex items-center justify-center mx-auto mb-2">
                                ✓
                            </div>
                            <p className="font-medium">Tous vos produits se vendent !</p>
                        </div>
                    )}
                </div>
            </div>

            {/* Profile & Shop Appearance */}
            {shop && (
                <ProfileSettings
                    shopId={shop.id}
                    currentAvatar={shop.owner_avatar}
                    currentBanner={shop.banner_url}
                    onUpdate={loadDashboard}
                />
            )}

            {/* Certification Section */}
            {certification && (
                <div className="mb-8">
                    <CertificationStatus certification={certification} />
                </div>
            )}

            {/* Quick Actions */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
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
            {analytics?.total_products === 0 && (
                <div className="mt-6 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-xl p-6 text-white">
                    <h3 className="text-xl font-bold mb-2">
                        Bienvenue sur Oli Seller Center ! 🎉
                    </h3>
                    <p className="text-blue-100 mb-4">
                        Commencez par ajouter votre premier produit pour démarrer vos ventes.
                    </p>
                    <a
                        href="/products/new"
                        className="inline-block bg-white text-blue-600 px-6 py-2 rounded-lg font-medium hover:bg-blue-50 transition-colors"
                    >
                        Ajouter mon premier produit
                    </a>
                </div>
            )}
        </div>
    );
}
