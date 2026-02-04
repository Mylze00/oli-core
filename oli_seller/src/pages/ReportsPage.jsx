import { useState, useEffect, useCallback } from 'react';
import {
    BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
    XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';
import {
    FileDown, TrendingUp, TrendingDown, Package, Users,
    ShoppingCart, DollarSign, RefreshCw, Calendar, FileText
} from 'lucide-react';
import { sellerAPI } from '../services/api';

const PERIODS = [
    { value: '7d', label: '7 derniers jours' },
    { value: '30d', label: '30 derniers jours' },
    { value: '90d', label: '90 derniers jours' },
    { value: '12m', label: '12 derniers mois' }
];

const COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899'];

const STATUS_COLORS = {
    pending: '#9CA3AF',
    paid: '#3B82F6',
    processing: '#F59E0B',
    shipped: '#8B5CF6',
    delivered: '#10B981',
    cancelled: '#EF4444'
};

export default function ReportsPage() {
    const [activeTab, setActiveTab] = useState('sales');
    const [period, setPeriod] = useState('30d');
    const [loading, setLoading] = useState(true);
    const [salesData, setSalesData] = useState(null);
    const [productsData, setProductsData] = useState(null);
    const [customersData, setCustomersData] = useState(null);

    const loadReports = useCallback(async () => {
        try {
            setLoading(true);
            if (activeTab === 'sales') {
                const data = await sellerAPI.getSalesReport(period);
                setSalesData(data);
            } else if (activeTab === 'products') {
                const data = await sellerAPI.getProductsReport(period);
                setProductsData(data);
            } else if (activeTab === 'customers') {
                const data = await sellerAPI.getCustomersReport(period);
                setCustomersData(data);
            }
        } catch (err) {
            console.error('Erreur chargement rapports:', err);
        } finally {
            setLoading(false);
        }
    }, [activeTab, period]);

    useEffect(() => {
        loadReports();
    }, [loadReports]);

    const handleExportPDF = async () => {
        try {
            const response = await sellerAPI.exportReportPDF(period, activeTab);
            // Ouvrir dans nouvel onglet pour impression/PDF
            const blob = new Blob([response], { type: 'text/html' });
            const url = URL.createObjectURL(blob);
            const newWindow = window.open(url, '_blank');
            if (newWindow) {
                newWindow.onload = () => {
                    newWindow.print();
                };
            }
        } catch (err) {
            console.error('Erreur export PDF:', err);
            alert('Erreur lors de l\'export');
        }
    };

    const formatCurrency = (value) => {
        return parseFloat(value || 0).toLocaleString('fr-FR', {
            style: 'currency',
            currency: 'USD'
        });
    };

    const formatDate = (dateStr) => {
        return new Date(dateStr).toLocaleDateString('fr-FR', {
            day: '2-digit',
            month: 'short'
        });
    };

    const MetricCard = ({ icon: Icon, label, value, change, prefix = '', suffix = '' }) => (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <div className="flex justify-between items-start mb-3">
                <div className="p-2 bg-blue-50 rounded-lg">
                    <Icon className="text-blue-600" size={20} />
                </div>
                {change !== null && change !== undefined && (
                    <span className={`text-sm font-medium flex items-center gap-1 ${parseFloat(change) >= 0 ? 'text-green-600' : 'text-red-600'
                        }`}>
                        {parseFloat(change) >= 0 ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
                        {Math.abs(parseFloat(change))}%
                    </span>
                )}
            </div>
            <p className="text-2xl font-bold text-gray-900">{prefix}{value}{suffix}</p>
            <p className="text-sm text-gray-500 mt-1">{label}</p>
        </div>
    );

    const renderSalesReport = () => {
        if (!salesData) return null;
        const summary = salesData.summary || {};
        const chartData = salesData.chart_data || [];
        const byStatus = salesData.by_status || [];

        return (
            <div className="space-y-6">
                {/* KPIs */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <MetricCard
                        icon={DollarSign}
                        label="Chiffre d'affaires"
                        value={formatCurrency(summary.total_revenue)}
                        change={summary.revenue_change_percent}
                    />
                    <MetricCard
                        icon={ShoppingCart}
                        label="Commandes"
                        value={summary.total_orders || 0}
                    />
                    <MetricCard
                        icon={Package}
                        label="Articles vendus"
                        value={summary.total_items || 0}
                    />
                    <MetricCard
                        icon={Users}
                        label="Clients uniques"
                        value={summary.unique_customers || 0}
                    />
                </div>

                {/* Graphique des ventes */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Évolution des ventes</h3>
                    <ResponsiveContainer width="100%" height={300}>
                        <LineChart data={chartData}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                            <XAxis dataKey="date" tickFormatter={formatDate} stroke="#9CA3AF" />
                            <YAxis stroke="#9CA3AF" />
                            <Tooltip
                                formatter={(value, name) => [
                                    name === 'revenue' ? formatCurrency(value) : value,
                                    name === 'revenue' ? 'Revenus' : name === 'orders' ? 'Commandes' : 'Articles'
                                ]}
                                labelFormatter={(label) => formatDate(label)}
                            />
                            <Legend />
                            <Line type="monotone" dataKey="revenue" name="Revenus" stroke="#3B82F6" strokeWidth={2} dot={false} />
                            <Line type="monotone" dataKey="orders" name="Commandes" stroke="#10B981" strokeWidth={2} dot={false} />
                        </LineChart>
                    </ResponsiveContainer>
                </div>

                {/* Répartition par statut */}
                <div className="grid md:grid-cols-2 gap-6">
                    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                        <h3 className="text-lg font-semibold text-gray-900 mb-4">Par statut</h3>
                        <ResponsiveContainer width="100%" height={250}>
                            <PieChart>
                                <Pie
                                    data={byStatus}
                                    dataKey="count"
                                    nameKey="status"
                                    cx="50%"
                                    cy="50%"
                                    outerRadius={80}
                                    label={({ status, count }) => `${status}: ${count}`}
                                >
                                    {byStatus.map((entry, index) => (
                                        <Cell key={entry.status} fill={STATUS_COLORS[entry.status] || COLORS[index]} />
                                    ))}
                                </Pie>
                                <Tooltip formatter={(value) => [value, 'Commandes']} />
                            </PieChart>
                        </ResponsiveContainer>
                    </div>

                    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                        <h3 className="text-lg font-semibold text-gray-900 mb-4">Revenus par statut</h3>
                        <div className="space-y-3">
                            {byStatus.map(item => (
                                <div key={item.status} className="flex items-center">
                                    <div
                                        className="w-3 h-3 rounded-full mr-3"
                                        style={{ backgroundColor: STATUS_COLORS[item.status] }}
                                    />
                                    <span className="flex-1 text-gray-600 capitalize">{item.status}</span>
                                    <span className="font-medium text-gray-900">{formatCurrency(item.revenue)}</span>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        );
    };

    const renderProductsReport = () => {
        if (!productsData) return null;
        const stats = productsData.stats || {};
        const topProducts = productsData.top_products || [];
        const lowStock = productsData.low_stock || [];

        return (
            <div className="space-y-6">
                {/* Stats */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <MetricCard icon={Package} label="Total produits" value={stats.total_products || 0} />
                    <MetricCard icon={Package} label="Produits actifs" value={stats.active_products || 0} />
                    <MetricCard icon={Package} label="Stock total" value={stats.total_stock || 0} suffix=" unités" />
                    <MetricCard icon={Package} label="Stock faible" value={stats.low_stock_count || 0} />
                </div>

                {/* Top produits */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Produits</h3>
                    <ResponsiveContainer width="100%" height={300}>
                        <BarChart data={topProducts.slice(0, 10)} layout="vertical">
                            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                            <XAxis type="number" stroke="#9CA3AF" />
                            <YAxis dataKey="name" type="category" width={150} stroke="#9CA3AF" tick={{ fontSize: 12 }} />
                            <Tooltip formatter={(value) => [formatCurrency(value), 'Revenus']} />
                            <Bar dataKey="revenue" fill="#3B82F6" radius={[0, 4, 4, 0]} />
                        </BarChart>
                    </ResponsiveContainer>
                </div>

                {/* Stock faible */}
                {lowStock.length > 0 && (
                    <div className="bg-orange-50 border border-orange-200 rounded-xl p-6">
                        <h3 className="text-lg font-semibold text-orange-800 mb-4">⚠️ Produits en stock faible</h3>
                        <div className="grid md:grid-cols-2 gap-3">
                            {lowStock.map(product => (
                                <div key={product.id} className="flex items-center gap-3 bg-white p-3 rounded-lg">
                                    <span className="font-medium text-gray-900 flex-1">{product.name}</span>
                                    <span className="px-2 py-1 bg-orange-100 text-orange-700 rounded text-sm font-bold">
                                        {product.stock} restant{product.stock > 1 ? 's' : ''}
                                    </span>
                                </div>
                            ))}
                        </div>
                    </div>
                )}
            </div>
        );
    };

    const renderCustomersReport = () => {
        if (!customersData) return null;
        const stats = customersData.stats || {};
        const topCustomers = customersData.top_customers || [];
        const newVsReturning = customersData.new_vs_returning || [];

        return (
            <div className="space-y-6">
                {/* Stats */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <MetricCard icon={Users} label="Total clients" value={stats.total_customers || 0} />
                    <MetricCard icon={Users} label="Clients uniques" value={stats.one_time_buyers || 0} />
                    <MetricCard icon={Users} label="Clients récurrents" value={stats.repeat_buyers || 0} />
                    <MetricCard icon={ShoppingCart} label="Commandes/client" value={stats.avg_orders_per_customer || 0} />
                </div>

                {/* Nouveaux vs Récurrents */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Nouveaux vs Clients récurrents</h3>
                    <ResponsiveContainer width="100%" height={300}>
                        <BarChart data={newVsReturning}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                            <XAxis dataKey="date" tickFormatter={formatDate} stroke="#9CA3AF" />
                            <YAxis stroke="#9CA3AF" />
                            <Tooltip labelFormatter={(label) => formatDate(label)} />
                            <Legend />
                            <Bar dataKey="new_customers" name="Nouveaux" fill="#10B981" stackId="a" />
                            <Bar dataKey="returning_customers" name="Récurrents" fill="#3B82F6" stackId="a" />
                        </BarChart>
                    </ResponsiveContainer>
                </div>

                {/* Top clients */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Meilleurs clients</h3>
                    <div className="overflow-x-auto">
                        <table className="w-full">
                            <thead className="bg-gray-50 text-xs uppercase text-gray-500">
                                <tr>
                                    <th className="text-left p-3">Client</th>
                                    <th className="text-center p-3">Commandes</th>
                                    <th className="text-right p-3">Total dépensé</th>
                                    <th className="text-right p-3">Dernière commande</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {topCustomers.map(customer => (
                                    <tr key={customer.id} className="hover:bg-gray-50">
                                        <td className="p-3">
                                            <p className="font-medium text-gray-900">{customer.name}</p>
                                            <p className="text-sm text-gray-500">{customer.phone}</p>
                                        </td>
                                        <td className="p-3 text-center font-medium">{customer.orders_count}</td>
                                        <td className="p-3 text-right font-bold text-blue-600">
                                            {formatCurrency(customer.total_spent)}
                                        </td>
                                        <td className="p-3 text-right text-sm text-gray-500">
                                            {new Date(customer.last_order).toLocaleDateString('fr-FR')}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        );
    };

    return (
        <div className="p-8">
            {/* Header */}
            <div className="flex flex-wrap justify-between items-center gap-4 mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Rapports & Analyses</h1>
                    <p className="text-gray-500">Analysez les performances de votre boutique</p>
                </div>
                <div className="flex gap-3">
                    <select
                        value={period}
                        onChange={(e) => setPeriod(e.target.value)}
                        className="border border-gray-300 rounded-lg px-4 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                    >
                        {PERIODS.map(p => (
                            <option key={p.value} value={p.value}>{p.label}</option>
                        ))}
                    </select>
                    <button
                        onClick={loadReports}
                        className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200"
                    >
                        <RefreshCw size={18} />
                    </button>
                    <button
                        onClick={handleExportPDF}
                        className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium"
                    >
                        <FileDown size={18} /> Exporter PDF
                    </button>
                </div>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 mb-6 border-b border-gray-200 pb-2">
                {[
                    { key: 'sales', label: 'Ventes', icon: DollarSign },
                    { key: 'products', label: 'Produits', icon: Package },
                    { key: 'customers', label: 'Clients', icon: Users }
                ].map(tab => (
                    <button
                        key={tab.key}
                        onClick={() => setActiveTab(tab.key)}
                        className={`flex items-center gap-2 px-4 py-2 rounded-t-lg font-medium transition-colors ${activeTab === tab.key
                            ? 'bg-blue-600 text-white'
                            : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                            }`}
                    >
                        <tab.icon size={18} />
                        {tab.label}
                    </button>
                ))}
            </div>

            {/* Content */}
            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <RefreshCw className="animate-spin text-blue-600" size={32} />
                </div>
            ) : (
                <>
                    {activeTab === 'sales' && renderSalesReport()}
                    {activeTab === 'products' && renderProductsReport()}
                    {activeTab === 'customers' && renderCustomersReport()}
                </>
            )}
        </div>
    );
}
