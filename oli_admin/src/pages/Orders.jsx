import { useEffect, useState } from 'react';
import api from '../services/api';
import { EyeIcon } from '@heroicons/react/24/outline';

const STATUS_COLORS = {
    pending: 'bg-yellow-100 text-yellow-800',
    paid: 'bg-blue-100 text-blue-800',
    shipped: 'bg-indigo-100 text-indigo-800',
    delivered: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800',
};

const STATUS_LABELS = {
    pending: 'En attente',
    paid: 'Payée',
    shipped: 'Expédiée',
    delivered: 'Livrée',
    cancelled: 'Annulée',
};

export default function Orders() {
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedOrder, setSelectedOrder] = useState(null); // Pour le modal détail

    useEffect(() => {
        fetchOrders();
    }, []);

    const fetchOrders = async () => {
        try {
            const { data } = await api.get('/admin/orders');
            setOrders(data);
        } catch (error) {
            console.error("Erreur orders:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleStatusChange = async (orderId, newStatus) => {
        if (!window.confirm(`Passer la commande en statut : ${STATUS_LABELS[newStatus]} ?`)) return;

        try {
            await api.patch(`/admin/orders/${orderId}/status`, { status: newStatus });
            fetchOrders(); // Refresh
            if (selectedOrder) setSelectedOrder(null); // Fermer modal si ouvert
        } catch (error) {
            console.error("Erreur update status:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    if (loading) return <div>Chargement...</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Commandes</h1>

            <div className="bg-white shadow overflow-hidden rounded-md">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Client</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Montant</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {orders.map((order) => (
                            <tr key={order.id}>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                    #{order.id}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm text-gray-900">{order.buyer_name || 'Inconnu'}</div>
                                    <div className="text-sm text-gray-500">{order.buyer_phone}</div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-bold">
                                    {order.total_amount} $
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${STATUS_COLORS[order.status] || 'bg-gray-100'}`}>
                                        {STATUS_LABELS[order.status] || order.status}
                                    </span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                    {new Date(order.created_at).toLocaleDateString()}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                    <button
                                        onClick={() => setSelectedOrder(order)}
                                        className="text-indigo-600 hover:text-indigo-900 flex items-center"
                                    >
                                        <EyeIcon className="h-5 w-5 mr-1" /> Détails
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>

                {orders.length === 0 && (
                    <div className="p-8 text-center text-gray-500">Aucune commande trouvée</div>
                )}
            </div>

            {/* Modal Détails Commande */}
            {selectedOrder && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
                    <div className="bg-white rounded-lg max-w-2xl w-full p-6 max-h-[90vh] overflow-y-auto">
                        <div className="flex justify-between items-start mb-6">
                            <h2 className="text-xl font-bold">Commande #{selectedOrder.id}</h2>
                            <button
                                onClick={() => setSelectedOrder(null)}
                                className="text-gray-400 hover:text-gray-600 text-2xl"
                            >
                                &times;
                            </button>
                        </div>

                        <div className="grid grid-cols-2 gap-4 mb-6">
                            <div>
                                <h3 className="font-semibold text-gray-700">Client</h3>
                                <p>{selectedOrder.buyer_name}</p>
                                <p className="text-gray-500">{selectedOrder.buyer_phone}</p>
                            </div>
                            <div>
                                <h3 className="font-semibold text-gray-700">Livraison</h3>
                                <p>{selectedOrder.shipping_address || 'Pas d\'adresse'}</p>
                            </div>
                        </div>

                        <div className="mb-6">
                            <h3 className="font-semibold text-gray-700 mb-2">Produits</h3>
                            {selectedOrder.items ? ( // Supposant que le back renvoie les items (TODO: Check backend)
                                <ul className="border rounded divide-y">
                                    {selectedOrder.items.map((item, idx) => (
                                        <li key={idx} className="p-2 flex justify-between">
                                            <span>{item.product_name} x{item.quantity}</span>
                                            <span>{item.price} $</span>
                                        </li>
                                    ))}
                                </ul>
                            ) : (
                                <p className="text-gray-500 italic">Détails produits non chargés (Backend à mettre à jour)</p>
                            )}
                        </div>

                        <div className="border-t pt-4 flex justify-between items-center">
                            <div className="text-sm text-gray-500">
                                Créée le {new Date(selectedOrder.created_at).toLocaleString()}
                            </div>
                            <div className="flex space-x-2">
                                {selectedOrder.status === 'pending' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'paid')}
                                        className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                                    >
                                        Marquer Payée
                                    </button>
                                )}
                                {selectedOrder.status === 'paid' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'shipped')}
                                        className="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700"
                                    >
                                        Marquer Expédiée
                                    </button>
                                )}
                                {selectedOrder.status === 'shipped' && (
                                    <button
                                        onClick={() => handleStatusChange(selectedOrder.id, 'delivered')}
                                        className="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
                                    >
                                        Marquer Livrée
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
