import { useState, useEffect, useRef } from 'react';
import {
    Package, Truck, CheckCircle, Clock, XCircle,
    ChevronDown, ChevronUp, Search, Filter,
    RefreshCw, Bell, Eye, Send,
    User, Phone, MapPin, CreditCard, QrCode,
    Calendar, ShoppingBag, Hash
} from 'lucide-react';
import { sellerAPI } from '../services/api';

const STATUS_CONFIG = {
    pending: { label: 'En attente', color: 'bg-gray-100 text-gray-700', icon: Clock },
    paid: { label: 'Payée', color: 'bg-blue-100 text-blue-700', icon: CheckCircle },
    processing: { label: 'En préparation', color: 'bg-yellow-100 text-yellow-700', icon: Package },
    shipped: { label: 'Expédiée', color: 'bg-purple-100 text-purple-700', icon: Truck },
    delivered: { label: 'Livrée', color: 'bg-green-100 text-green-700', icon: CheckCircle },
    cancelled: { label: 'Annulée', color: 'bg-red-100 text-red-700', icon: XCircle }
};

const TRANSITIONS = {
    paid: [{ to: 'processing', label: 'Préparer la commande', color: 'bg-yellow-500' }],
    processing: [{ to: 'shipped', label: 'Marquer comme expédiée', color: 'bg-purple-500' }],
    shipped: [{ to: 'delivered', label: 'Confirmer livraison', color: 'bg-green-500' }]
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

export default function OrderManagement() {
    const [orders, setOrders] = useState([]);
    const [statusCounts, setStatusCounts] = useState({});
    const [loading, setLoading] = useState(true);
    const [activeFilter, setActiveFilter] = useState('all');
    const [expandedOrder, setExpandedOrder] = useState(null);
    const [shippingModal, setShippingModal] = useState(null);
    const [shippingForm, setShippingForm] = useState({
        tracking_number: '',
        carrier: '',
        estimated_delivery: ''
    });

    useEffect(() => {
        loadOrders();
    }, [activeFilter]);

    // Auto-refresh toutes les 10s (silencieux, sans loader)
    useEffect(() => {
        const interval = setInterval(() => {
            silentRefresh();
        }, 10000);
        return () => clearInterval(interval);
    }, [activeFilter]);

    const loadOrders = async () => {
        try {
            setLoading(true);
            const filters = activeFilter !== 'all' ? { status: activeFilter } : {};
            const data = await sellerAPI.getOrders(filters);
            setOrders(data.orders || []);
            setStatusCounts(data.status_counts || {});
        } catch (err) {
            console.error('Erreur chargement commandes:', err);
        } finally {
            setLoading(false);
        }
    };

    const silentRefresh = async () => {
        try {
            const filters = activeFilter !== 'all' ? { status: activeFilter } : {};
            const data = await sellerAPI.getOrders(filters);
            setOrders(data.orders || []);
            setStatusCounts(data.status_counts || {});
        } catch (err) {
            // Silencieux — pas de log intrusif
        }
    };

    const handleStatusChange = async (orderId, newStatus, shippingData = null) => {
        try {
            const payload = { status: newStatus };
            if (shippingData) {
                Object.assign(payload, shippingData);
            }

            await sellerAPI.updateOrderStatus(orderId, payload);
            setShippingModal(null);
            setShippingForm({ tracking_number: '', carrier: '', estimated_delivery: '' });
            loadOrders();
        } catch (err) {
            console.error('Erreur mise à jour statut:', err);
            alert(err.response?.data?.error || 'Erreur lors de la mise à jour');
        }
    };

    const handleShipOrder = (orderId) => {
        // Pour 'shipped', on affiche le modal de suivi
        setShippingModal(orderId);
    };

    const submitShipping = () => {
        if (shippingModal) {
            handleStatusChange(shippingModal, 'shipped', shippingForm);
        }
    };

    const getFilterTabs = () => [
        { key: 'all', label: 'Toutes', count: Object.values(statusCounts).reduce((a, b) => a + b, 0) },
        { key: 'paid', label: 'À traiter', count: statusCounts.paid || 0 },
        { key: 'processing', label: 'En préparation', count: statusCounts.processing || 0 },
        { key: 'shipped', label: 'Expédiées', count: statusCounts.shipped || 0 },
        { key: 'delivered', label: 'Livrées', count: statusCounts.delivered || 0 }
    ];

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        return new Date(dateStr).toLocaleDateString('fr-FR', {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const formatPrice = (price) => {
        return parseFloat(price).toLocaleString('fr-FR', {
            style: 'currency',
            currency: 'USD'
        });
    };

    return (
        <div className="p-8">
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Gestion des Commandes</h1>
                    <p className="text-gray-500">Gérez le workflow de vos commandes</p>
                </div>
                <button
                    onClick={loadOrders}
                    className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                >
                    <RefreshCw size={18} /> Actualiser
                </button>
            </div>

            {/* Onglets de filtrage */}
            <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
                {getFilterTabs().map(tab => (
                    <button
                        key={tab.key}
                        onClick={() => setActiveFilter(tab.key)}
                        className={`px-4 py-2 rounded-lg font-medium whitespace-nowrap transition-colors ${activeFilter === tab.key
                            ? 'bg-blue-600 text-white'
                            : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                            }`}
                    >
                        {tab.label}
                        {tab.count > 0 && (
                            <span className={`ml-2 px-2 py-0.5 rounded-full text-xs ${activeFilter === tab.key ? 'bg-blue-500' : 'bg-gray-200'
                                }`}>
                                {tab.count}
                            </span>
                        )}
                    </button>
                ))}
            </div>

            {/* Liste des commandes */}
            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <RefreshCw className="animate-spin text-blue-600" size={32} />
                </div>
            ) : orders.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center">
                    <Package size={48} className="mx-auto mb-4 text-gray-300" />
                    <h3 className="text-lg font-medium text-gray-600 mb-2">Aucune commande</h3>
                    <p className="text-gray-400">Les commandes apparaîtront ici</p>
                </div>
            ) : (
                <div className="space-y-4">
                    {orders.map(order => {
                        const StatusIcon = STATUS_CONFIG[order.status]?.icon || Clock;
                        const isExpanded = expandedOrder === order.id;
                        const transitions = TRANSITIONS[order.status] || [];

                        return (
                            <div
                                key={order.id}
                                className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden"
                            >
                                {/* Header de commande */}
                                <div
                                    className="p-4 flex items-center justify-between cursor-pointer hover:bg-gray-50"
                                    onClick={() => setExpandedOrder(isExpanded ? null : order.id)}
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="text-center">
                                            <p className="text-xs text-gray-400">Commande</p>
                                            <p className="font-bold text-gray-900">#{order.id}</p>
                                        </div>
                                        <div className="h-10 w-px bg-gray-200" />
                                        <div>
                                            <p className="font-medium text-gray-900">{order.buyer_name}</p>
                                            <p className="text-sm text-gray-500">{order.buyer_phone}</p>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-4">
                                        <div className="text-right">
                                            <p className="font-bold text-gray-900">{formatPrice(order.total_amount)}</p>
                                            <p className="text-xs text-gray-400">{formatDate(order.created_at)}</p>
                                        </div>
                                        <span className={`px-3 py-1 rounded-full text-sm font-medium flex items-center gap-1 ${STATUS_CONFIG[order.status]?.color}`}>
                                            <StatusIcon size={14} />
                                            {STATUS_CONFIG[order.status]?.label}
                                        </span>
                                        {isExpanded ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                                    </div>
                                </div>

                                {/* Détails expandés */}
                                {isExpanded && (
                                    <div className="border-t border-gray-100 bg-gray-50">
                                        <div className="p-5 space-y-5">

                                            {/* ── Client & Livraison ── */}
                                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div className="bg-white rounded-xl p-4 border border-gray-100">
                                                    <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                                        <User size={14} /> Client
                                                    </h4>
                                                    <p className="font-medium text-gray-900">{order.buyer_name || 'Inconnu'}</p>
                                                    {order.buyer_phone && (
                                                        <p className="text-sm text-gray-600 flex items-center gap-1 mt-1">
                                                            <Phone size={13} /> {order.buyer_phone}
                                                        </p>
                                                    )}
                                                </div>
                                                <div className="bg-white rounded-xl p-4 border border-gray-100">
                                                    <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                                        <MapPin size={14} /> Livraison
                                                    </h4>
                                                    <p className="text-sm text-gray-800">
                                                        {order.delivery_address || 'Pas d\'adresse'}
                                                    </p>
                                                    <p className="text-xs text-gray-500 mt-1">
                                                        Mode: {DELIVERY_METHODS[order.delivery_method_id] || order.delivery_method_id || '—'}
                                                    </p>
                                                    {order.delivery_fee > 0 && (
                                                        <p className="text-xs text-gray-500 mt-0.5">
                                                            Frais: {formatPrice(order.delivery_fee)}
                                                        </p>
                                                    )}
                                                </div>
                                            </div>

                                            {/* ── Paiement ── */}
                                            <div className="bg-white rounded-xl p-4 border border-gray-100">
                                                <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                                    <CreditCard size={14} /> Paiement
                                                </h4>
                                                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                                                    <div>
                                                        <p className="text-xs text-gray-500">Montant total</p>
                                                        <p className="text-lg font-bold text-gray-900">{formatPrice(order.total_amount)}</p>
                                                    </div>
                                                    <div>
                                                        <p className="text-xs text-gray-500">Méthode</p>
                                                        <p className="text-sm font-medium">{PAYMENT_METHODS[order.payment_method] || order.payment_method || '—'}</p>
                                                    </div>
                                                    <div>
                                                        <p className="text-xs text-gray-500">Référence</p>
                                                        <p className="text-sm font-mono text-gray-700">{order.payment_reference || '—'}</p>
                                                    </div>
                                                    <div>
                                                        <p className="text-xs text-gray-500">Payée le</p>
                                                        <p className="text-sm">{formatDate(order.paid_at)}</p>
                                                    </div>
                                                </div>
                                            </div>

                                            {/* ── Codes (pickup & delivery) ── */}
                                            {(order.pickup_code || order.delivery_code) && (
                                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                    {order.pickup_code && (
                                                        <div className="bg-orange-50 border border-orange-200 rounded-xl p-4">
                                                            <h4 className="text-xs font-semibold text-orange-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                                                <QrCode size={14} /> Code Pickup (Livreur)
                                                            </h4>
                                                            <p className="text-2xl font-bold font-mono text-orange-900 tracking-[4px] text-center">
                                                                {order.pickup_code}
                                                            </p>
                                                        </div>
                                                    )}
                                                    {order.delivery_code && (
                                                        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
                                                            <h4 className="text-xs font-semibold text-green-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                                                <QrCode size={14} /> Code Livraison (Client)
                                                            </h4>
                                                            <p className="text-2xl font-bold font-mono text-green-900 tracking-[4px] text-center">
                                                                {order.delivery_code}
                                                            </p>
                                                        </div>
                                                    )}
                                                </div>
                                            )}

                                            {/* ── Produits ── */}
                                            <div>
                                                <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                                    <ShoppingBag size={14} /> Produits ({order.items?.length || 0})
                                                </h4>
                                                <div className="border border-gray-100 rounded-xl divide-y overflow-hidden">
                                                    {order.items?.map((item, idx) => (
                                                        <div key={idx} className="flex items-center gap-3 bg-white p-3 hover:bg-gray-50">
                                                            {item.product_image_url && (
                                                                <img
                                                                    src={item.product_image_url}
                                                                    alt={item.product_name}
                                                                    className="w-12 h-12 rounded-lg object-cover flex-shrink-0"
                                                                />
                                                            )}
                                                            <div className="flex-1 min-w-0">
                                                                <p className="font-medium text-gray-900 text-sm truncate">{item.product_name}</p>
                                                                <p className="text-xs text-gray-500">
                                                                    {formatPrice(item.price)} × {item.quantity}
                                                                </p>
                                                            </div>
                                                            <p className="font-semibold text-gray-900 text-sm">
                                                                {formatPrice(item.price * item.quantity)}
                                                            </p>
                                                        </div>
                                                    ))}
                                                    <div className="flex justify-between p-3 bg-gray-50 font-bold text-sm">
                                                        <span>Total</span>
                                                        <span>{formatPrice(order.total_amount)}</span>
                                                    </div>
                                                </div>
                                            </div>

                                            {/* ── Suivi ── */}
                                            {order.tracking_number && (
                                                <div className="bg-purple-50 border border-purple-200 rounded-xl p-4">
                                                    <h4 className="text-xs font-semibold text-purple-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                                        <Truck size={14} /> Suivi de colis
                                                    </h4>
                                                    <div className="grid grid-cols-2 gap-3 text-sm">
                                                        <div>
                                                            <p className="text-xs text-purple-600">N° de suivi</p>
                                                            <p className="font-mono font-medium">{order.tracking_number}</p>
                                                        </div>
                                                        {order.carrier && (
                                                            <div>
                                                                <p className="text-xs text-purple-600">Transporteur</p>
                                                                <p className="font-medium">{order.carrier}</p>
                                                            </div>
                                                        )}
                                                    </div>
                                                    {order.estimated_delivery && (
                                                        <p className="text-sm text-purple-600 mt-2">
                                                            Livraison estimée: {new Date(order.estimated_delivery).toLocaleDateString('fr-FR')}
                                                        </p>
                                                    )}
                                                </div>
                                            )}

                                            {/* ── Timeline ── */}
                                            <div className="bg-white rounded-xl p-4 border border-gray-100">
                                                <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                                                    <Calendar size={14} /> Historique
                                                </h4>
                                                <div className="space-y-2 text-sm">
                                                    <div className="flex justify-between">
                                                        <span className="text-gray-600">Créée</span>
                                                        <span className="font-medium">{formatDate(order.created_at)}</span>
                                                    </div>
                                                    {order.paid_at && (
                                                        <div className="flex justify-between">
                                                            <span className="text-blue-600">Payée</span>
                                                            <span className="font-medium">{formatDate(order.paid_at)}</span>
                                                        </div>
                                                    )}
                                                    {order.shipped_at && (
                                                        <div className="flex justify-between">
                                                            <span className="text-purple-600">Expédiée</span>
                                                            <span className="font-medium">{formatDate(order.shipped_at)}</span>
                                                        </div>
                                                    )}
                                                    {order.delivered_at && (
                                                        <div className="flex justify-between">
                                                            <span className="text-green-600">Livrée</span>
                                                            <span className="font-medium">{formatDate(order.delivered_at)}</span>
                                                        </div>
                                                    )}
                                                    {order.updated_at && (
                                                        <div className="flex justify-between">
                                                            <span className="text-gray-400">Dernière MAJ</span>
                                                            <span className="text-gray-500">{formatDate(order.updated_at)}</span>
                                                        </div>
                                                    )}
                                                </div>
                                            </div>

                                            {/* ── Actions ── */}
                                            {transitions.length > 0 && (
                                                <div className="flex gap-2 pt-2 border-t border-gray-200">
                                                    {transitions.map(t => (
                                                        <button
                                                            key={t.to}
                                                            onClick={(e) => {
                                                                e.stopPropagation();
                                                                if (t.to === 'shipped') {
                                                                    handleShipOrder(order.id);
                                                                } else {
                                                                    handleStatusChange(order.id, t.to);
                                                                }
                                                            }}
                                                            className={`${t.color} text-white px-4 py-2 rounded-lg font-medium hover:opacity-90 transition-opacity flex items-center gap-2`}
                                                        >
                                                            <Send size={16} />
                                                            {t.label}
                                                        </button>
                                                    ))}
                                                </div>
                                            )}

                                        </div>
                                    </div>
                                )}
                            </div>
                        );
                    })}
                </div>
            )}

            {/* Modal d'expédition */}
            {shippingModal && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                    <div className="bg-white rounded-xl p-6 w-full max-w-md mx-4">
                        <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                            <Truck className="text-purple-600" size={24} />
                            Informations d'expédition
                        </h3>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Numéro de suivi
                                </label>
                                <input
                                    type="text"
                                    className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-purple-500 outline-none"
                                    placeholder="Ex: 1Z999AA10123456784"
                                    value={shippingForm.tracking_number}
                                    onChange={(e) => setShippingForm({ ...shippingForm, tracking_number: e.target.value })}
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Transporteur
                                </label>
                                <select
                                    className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-purple-500 outline-none"
                                    value={shippingForm.carrier}
                                    onChange={(e) => setShippingForm({ ...shippingForm, carrier: e.target.value })}
                                >
                                    <option value="">Sélectionner...</option>
                                    <option value="DHL">DHL</option>
                                    <option value="FedEx">FedEx</option>
                                    <option value="UPS">UPS</option>
                                    <option value="La Poste">La Poste</option>
                                    <option value="Colissimo">Colissimo</option>
                                    <option value="Chronopost">Chronopost</option>
                                    <option value="Autre">Autre</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Date de livraison estimée
                                </label>
                                <input
                                    type="date"
                                    className="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-purple-500 outline-none"
                                    value={shippingForm.estimated_delivery}
                                    onChange={(e) => setShippingForm({ ...shippingForm, estimated_delivery: e.target.value })}
                                />
                            </div>
                        </div>

                        <div className="flex gap-3 mt-6">
                            <button
                                onClick={() => setShippingModal(null)}
                                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={submitShipping}
                                className="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium"
                            >
                                Confirmer l'expédition
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
