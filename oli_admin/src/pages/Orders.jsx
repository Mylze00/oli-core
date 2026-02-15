import { useEffect, useState } from 'react';
import api from '../services/api';
import {
    EyeIcon, ArrowPathIcon, FunnelIcon,
    ClockIcon, TruckIcon, CheckCircleIcon, XCircleIcon,
    CreditCardIcon, MapPinIcon, QrCodeIcon, ShoppingBagIcon,
    UserIcon, PhoneIcon, CalendarDaysIcon
} from '@heroicons/react/24/outline';

const STATUS_CONFIG = {
    pending: { label: 'En attente', color: 'bg-yellow-100 text-yellow-800', dot: 'bg-yellow-400' },
    paid: { label: 'Payée', color: 'bg-blue-100 text-blue-800', dot: 'bg-blue-400' },
    processing: { label: 'En préparation', color: 'bg-orange-100 text-orange-800', dot: 'bg-orange-400' },
    ready: { label: 'Prête', color: 'bg-cyan-100 text-cyan-800', dot: 'bg-cyan-400' },
    shipped: { label: 'Expédiée', color: 'bg-indigo-100 text-indigo-800', dot: 'bg-indigo-400' },
    delivered: { label: 'Livrée', color: 'bg-green-100 text-green-800', dot: 'bg-green-400' },
    cancelled: { label: 'Annulée', color: 'bg-red-100 text-red-800', dot: 'bg-red-400' },
};

const DELIVERY_METHODS = {
    oli_delivery: 'Oli Express',
    pick_go: 'Pick & Go',
    hand_delivery: 'Remise en main propre',
};

const PAYMENT_METHODS = {
    card: 'Carte bancaire',
    mobile_money: 'Mobile Money',
    cash: 'Cash',
    airtel_money: 'Airtel Money',
    orange_money: 'Orange Money',
    mpesa: 'M-Pesa',
};

export default function Orders() {
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedOrder, setSelectedOrder] = useState(null);
    const [activeFilter, setActiveFilter] = useState('all');

    useEffect(() => {
        fetchOrders();
    }, []);

    // Auto-refresh toutes les 10s (silencieux)
    useEffect(() => {
        const interval = setInterval(() => {
            silentRefresh();
        }, 10000);
        return () => clearInterval(interval);
    }, []);

    const fetchOrders = async () => {
        try {
            setLoading(true);
            const { data } = await api.get('/admin/orders');
            setOrders(data);
        } catch (error) {
            console.error("Erreur orders:", error);
        } finally {
            setLoading(false);
        }
    };

    const silentRefresh = async () => {
        try {
            const { data } = await api.get('/admin/orders');
            setOrders(data);
            // Mettre à jour le modal ouvert si besoin
            if (selectedOrder) {
                const updated = data.find(o => o.id === selectedOrder.id);
                if (updated) setSelectedOrder(updated);
            }
        } catch (err) { /* silencieux */ }
    };

    const handleStatusChange = async (orderId, newStatus) => {
        if (!window.confirm(`Passer la commande #${orderId} en statut : ${STATUS_CONFIG[newStatus]?.label || newStatus} ?`)) return;
        try {
            await api.patch(`/admin/orders/${orderId}/status`, { status: newStatus });
            fetchOrders();
            if (selectedOrder) setSelectedOrder(null);
        } catch (error) {
            console.error("Erreur update status:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('fr-FR', {
            day: 'numeric', month: 'short', year: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    };

    const formatPrice = (price) => {
        if (!price) return '0.00 $';
        return parseFloat(price).toLocaleString('fr-FR', { style: 'currency', currency: 'USD' });
    };

    // Compteurs par statut
    const statusCounts = orders.reduce((acc, o) => {
        acc[o.status] = (acc[o.status] || 0) + 1;
        return acc;
    }, {});

    const filteredOrders = activeFilter === 'all'
        ? orders
        : orders.filter(o => o.status === activeFilter);

    const filterTabs = [
        { key: 'all', label: 'Toutes', count: orders.length },
        { key: 'paid', label: 'Payées', count: statusCounts.paid || 0 },
        { key: 'processing', label: 'En préparation', count: statusCounts.processing || 0 },
        { key: 'ready', label: 'Prêtes', count: statusCounts.ready || 0 },
        { key: 'shipped', label: 'Expédiées', count: statusCounts.shipped || 0 },
        { key: 'delivered', label: 'Livrées', count: statusCounts.delivered || 0 },
        { key: 'cancelled', label: 'Annulées', count: statusCounts.cancelled || 0 },
    ];

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <ArrowPathIcon className="h-8 w-8 animate-spin text-blue-600" />
            </div>
        );
    }

    return (
        <div>
            {/* Header */}
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Commandes</h1>
                    <p className="text-sm text-gray-500">{orders.length} commandes au total</p>
                </div>
                <button
                    onClick={fetchOrders}
                    className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                >
                    <ArrowPathIcon className="h-4 w-4" /> Actualiser
                </button>
            </div>

            {/* Onglets de filtre */}
            <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
                {filterTabs.map(tab => (
                    <button
                        key={tab.key}
                        onClick={() => setActiveFilter(tab.key)}
                        className={`px-4 py-2 rounded-lg font-medium whitespace-nowrap transition-colors text-sm ${activeFilter === tab.key
                                ? 'bg-blue-600 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                            }`}
                    >
                        {tab.label}
                        {tab.count > 0 && (
                            <span className={`ml-2 px-2 py-0.5 rounded-full text-xs ${activeFilter === tab.key ? 'bg-blue-500 text-white' : 'bg-gray-200'
                                }`}>
                                {tab.count}
                            </span>
                        )}
                    </button>
                ))}
            </div>

            {/* Table */}
            <div className="bg-white shadow-sm rounded-xl border border-gray-100 overflow-hidden">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Client</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Montant</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Paiement</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Livraison</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {filteredOrders.map((order) => (
                            <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-bold text-gray-900">
                                    #{order.id}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm font-medium text-gray-900">{order.buyer_name || 'Inconnu'}</div>
                                    <div className="text-xs text-gray-500">{order.buyer_phone}</div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-bold text-gray-900">
                                    {formatPrice(order.total_amount)}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-xs text-gray-600">
                                    {PAYMENT_METHODS[order.payment_method] || order.payment_method || '—'}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-xs text-gray-600">
                                    {DELIVERY_METHODS[order.delivery_method_id] || order.delivery_method_id || '—'}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${STATUS_CONFIG[order.status]?.color || 'bg-gray-100'}`}>
                                        <span className={`w-1.5 h-1.5 rounded-full ${STATUS_CONFIG[order.status]?.dot || 'bg-gray-400'}`} />
                                        {STATUS_CONFIG[order.status]?.label || order.status}
                                    </span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-xs text-gray-500">
                                    {formatDate(order.created_at)}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <button
                                        onClick={() => setSelectedOrder(order)}
                                        className="text-blue-600 hover:text-blue-800 flex items-center gap-1 text-sm font-medium"
                                    >
                                        <EyeIcon className="h-4 w-4" /> Détails
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>

                {filteredOrders.length === 0 && (
                    <div className="p-12 text-center">
                        <ShoppingBagIcon className="h-12 w-12 mx-auto mb-3 text-gray-300" />
                        <p className="text-gray-500">Aucune commande trouvée</p>
                    </div>
                )}
            </div>

            {/* ══════ Modal Détails Commande ══════ */}
            {selectedOrder && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
                    <div className="bg-white rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-2xl">
                        {/* Header du modal */}
                        <div className="sticky top-0 bg-white border-b px-6 py-4 flex justify-between items-center rounded-t-2xl z-10">
                            <div className="flex items-center gap-3">
                                <h2 className="text-xl font-bold text-gray-900">Commande #{selectedOrder.id}</h2>
                                <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${STATUS_CONFIG[selectedOrder.status]?.color}`}>
                                    <span className={`w-1.5 h-1.5 rounded-full ${STATUS_CONFIG[selectedOrder.status]?.dot}`} />
                                    {STATUS_CONFIG[selectedOrder.status]?.label}
                                </span>
                            </div>
                            <button
                                onClick={() => setSelectedOrder(null)}
                                className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
                            >
                                &times;
                            </button>
                        </div>

                        <div className="p-6 space-y-6">
                            {/* ── Client & Livraison ── */}
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div className="bg-gray-50 rounded-xl p-4">
                                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                        <UserIcon className="h-4 w-4" /> Client
                                    </h3>
                                    <p className="font-medium text-gray-900">{selectedOrder.buyer_name || 'Inconnu'}</p>
                                    {selectedOrder.buyer_phone && (
                                        <p className="text-sm text-gray-600 flex items-center gap-1 mt-1">
                                            <PhoneIcon className="h-3.5 w-3.5" /> {selectedOrder.buyer_phone}
                                        </p>
                                    )}
                                </div>

                                <div className="bg-gray-50 rounded-xl p-4">
                                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                        <MapPinIcon className="h-4 w-4" /> Livraison
                                    </h3>
                                    <p className="text-sm text-gray-800">
                                        {selectedOrder.shipping_address || selectedOrder.delivery_address || 'Pas d\'adresse'}
                                    </p>
                                    <p className="text-xs text-gray-500 mt-1">
                                        Mode: {DELIVERY_METHODS[selectedOrder.delivery_method_id] || selectedOrder.delivery_method_id || '—'}
                                    </p>
                                </div>
                            </div>

                            {/* ── Paiement ── */}
                            <div className="bg-gray-50 rounded-xl p-4">
                                <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                    <CreditCardIcon className="h-4 w-4" /> Paiement
                                </h3>
                                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                                    <div>
                                        <p className="text-xs text-gray-500">Montant total</p>
                                        <p className="text-lg font-bold text-gray-900">{formatPrice(selectedOrder.total_amount)}</p>
                                    </div>
                                    <div>
                                        <p className="text-xs text-gray-500">Méthode</p>
                                        <p className="text-sm font-medium">{PAYMENT_METHODS[selectedOrder.payment_method] || selectedOrder.payment_method || '—'}</p>
                                    </div>
                                    <div>
                                        <p className="text-xs text-gray-500">Référence</p>
                                        <p className="text-sm font-mono">{selectedOrder.payment_reference || '—'}</p>
                                    </div>
                                    <div>
                                        <p className="text-xs text-gray-500">Payée le</p>
                                        <p className="text-sm">{formatDate(selectedOrder.paid_at)}</p>
                                    </div>
                                </div>
                            </div>

                            {/* ── Codes de vérification ── */}
                            {(selectedOrder.pickup_code || selectedOrder.delivery_code) && (
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    {selectedOrder.pickup_code && (
                                        <div className="bg-orange-50 border border-orange-200 rounded-xl p-4">
                                            <h3 className="text-xs font-semibold text-orange-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                                <QrCodeIcon className="h-4 w-4" /> Code Pickup (Livreur)
                                            </h3>
                                            <p className="text-2xl font-bold font-mono text-orange-900 tracking-[4px] text-center">
                                                {selectedOrder.pickup_code}
                                            </p>
                                        </div>
                                    )}
                                    {selectedOrder.delivery_code && (
                                        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
                                            <h3 className="text-xs font-semibold text-green-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                                <QrCodeIcon className="h-4 w-4" /> Code Livraison (Client)
                                            </h3>
                                            <p className="text-2xl font-bold font-mono text-green-900 tracking-[4px] text-center">
                                                {selectedOrder.delivery_code}
                                            </p>
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* ── Produits ── */}
                            <div>
                                <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                    <ShoppingBagIcon className="h-4 w-4" /> Produits ({selectedOrder.items?.length || 0})
                                </h3>
                                {selectedOrder.items ? (
                                    <div className="border rounded-xl divide-y overflow-hidden">
                                        {selectedOrder.items.map((item, idx) => (
                                            <div key={idx} className="flex items-center justify-between p-3 bg-white hover:bg-gray-50">
                                                <div className="flex-1">
                                                    <p className="font-medium text-gray-900 text-sm">{item.product_name}</p>
                                                    <p className="text-xs text-gray-500">
                                                        {formatPrice(item.price)} × {item.quantity}
                                                    </p>
                                                </div>
                                                <p className="font-semibold text-gray-900">
                                                    {formatPrice(item.price * item.quantity)}
                                                </p>
                                            </div>
                                        ))}
                                        <div className="flex justify-between p-3 bg-gray-50 font-bold">
                                            <span>Total</span>
                                            <span>{formatPrice(selectedOrder.total_amount)}</span>
                                        </div>
                                    </div>
                                ) : (
                                    <p className="text-gray-500 italic text-sm">Détails produits non disponibles</p>
                                )}
                            </div>

                            {/* ── Suivi de colis ── */}
                            {selectedOrder.tracking_number && (
                                <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-4">
                                    <h3 className="text-xs font-semibold text-indigo-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                        <TruckIcon className="h-4 w-4" /> Suivi de colis
                                    </h3>
                                    <div className="grid grid-cols-2 gap-3 text-sm">
                                        <div>
                                            <p className="text-xs text-indigo-600">N° de suivi</p>
                                            <p className="font-mono font-medium">{selectedOrder.tracking_number}</p>
                                        </div>
                                        {selectedOrder.carrier && (
                                            <div>
                                                <p className="text-xs text-indigo-600">Transporteur</p>
                                                <p className="font-medium">{selectedOrder.carrier}</p>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {/* ── Timeline (dates clés) ── */}
                            <div className="bg-gray-50 rounded-xl p-4">
                                <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                    <CalendarDaysIcon className="h-4 w-4" /> Historique
                                </h3>
                                <div className="space-y-2 text-sm">
                                    <div className="flex justify-between">
                                        <span className="text-gray-600">Créée</span>
                                        <span className="font-medium">{formatDate(selectedOrder.created_at)}</span>
                                    </div>
                                    {selectedOrder.paid_at && (
                                        <div className="flex justify-between">
                                            <span className="text-blue-600">Payée</span>
                                            <span className="font-medium">{formatDate(selectedOrder.paid_at)}</span>
                                        </div>
                                    )}
                                    {selectedOrder.shipped_at && (
                                        <div className="flex justify-between">
                                            <span className="text-indigo-600">Expédiée</span>
                                            <span className="font-medium">{formatDate(selectedOrder.shipped_at)}</span>
                                        </div>
                                    )}
                                    {selectedOrder.delivered_at && (
                                        <div className="flex justify-between">
                                            <span className="text-green-600">Livrée</span>
                                            <span className="font-medium">{formatDate(selectedOrder.delivered_at)}</span>
                                        </div>
                                    )}
                                    {selectedOrder.updated_at && (
                                        <div className="flex justify-between">
                                            <span className="text-gray-500">Dernière MAJ</span>
                                            <span className="text-gray-600">{formatDate(selectedOrder.updated_at)}</span>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* ── Actions ── */}
                            <div className="border-t pt-4 flex flex-wrap gap-2 justify-end">
                                {selectedOrder.status === 'pending' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'paid')}
                                        className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 text-sm font-medium"
                                    >
                                        Marquer Payée
                                    </button>
                                )}
                                {selectedOrder.status === 'paid' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'processing')}
                                        className="bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700 text-sm font-medium"
                                    >
                                        Mettre en préparation
                                    </button>
                                )}
                                {selectedOrder.status === 'processing' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'ready')}
                                        className="bg-cyan-600 text-white px-4 py-2 rounded-lg hover:bg-cyan-700 text-sm font-medium"
                                    >
                                        Marquer Prête
                                    </button>
                                )}
                                {selectedOrder.status === 'shipped' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'delivered')}
                                        className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-sm font-medium"
                                    >
                                        Marquer Livrée
                                    </button>
                                )}
                                {!['delivered', 'cancelled'].includes(selectedOrder.status) && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'cancelled')}
                                        className="bg-red-100 text-red-700 px-4 py-2 rounded-lg hover:bg-red-200 text-sm font-medium"
                                    >
                                        Annuler
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
