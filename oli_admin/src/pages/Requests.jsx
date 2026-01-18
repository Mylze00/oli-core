import { useEffect, useState } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import { CheckCircleIcon, XCircleIcon, ClockIcon, StarIcon, UserIcon, BuildingStorefrontIcon } from '@heroicons/react/24/solid';

const REQUEST_TYPES = {
    'product_sponsorship': { label: 'Sponsorisation Produit', icon: StarIcon, color: 'text-yellow-500' },
    'user_verification': { label: 'Vérification Utilisateur', icon: UserIcon, color: 'text-blue-500' },
    'shop_certification': { label: 'Certification Boutique', icon: BuildingStorefrontIcon, color: 'text-green-500' }
};

const STATUS_BADGES = {
    'pending': { label: 'En attente', bgColor: 'bg-yellow-100', textColor: 'text-yellow-800' },
    'approved': { label: 'Approuvé', bgColor: 'bg-green-100', textColor: 'text-green-800' },
    'rejected': { label: 'Rejeté', bgColor: 'bg-red-100', textColor: 'text-red-800' }
};

const PAYMENT_BADGES = {
    'pending': { label: 'Non payé', bgColor: 'bg-gray-100', textColor: 'text-gray-600' },
    'paid': { label: 'Payé', bgColor: 'bg-green-100', textColor: 'text-green-800' },
    'failed': { label: 'Échec', bgColor: 'bg-red-100', textColor: 'text-red-800' }
};

export default function Requests() {
    const [requests, setRequests] = useState([]);
    const [stats, setStats] = useState({});
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('pending');
    const [typeFilter, setTypeFilter] = useState('all');

    useEffect(() => {
        fetchRequests();
        fetchStats();
    }, [filter, typeFilter]);

    const fetchRequests = async () => {
        try {
            let url = '/admin/requests?';
            if (filter !== 'all') url += `status=${filter}&`;
            if (typeFilter !== 'all') url += `type=${typeFilter}`;
            const { data } = await api.get(url);
            setRequests(data);
        } catch (error) {
            console.error("Erreur requests:", error);
        } finally {
            setLoading(false);
        }
    };

    const fetchStats = async () => {
        try {
            const { data } = await api.get('/admin/requests/stats');
            setStats(data);
        } catch (error) {
            console.error("Erreur stats:", error);
        }
    };

    const handleAction = async (requestId, action) => {
        const notes = action === 'reject' ? prompt('Raison du rejet (optionnel):') : null;
        if (!window.confirm(`${action === 'approve' ? 'Approuver' : 'Rejeter'} cette demande ?`)) return;

        try {
            await api.patch(`/admin/requests/${requestId}`, { action, notes });
            fetchRequests();
            fetchStats();
            alert(action === 'approve' ? 'Demande approuvée !' : 'Demande rejetée');
        } catch (error) {
            console.error("Erreur action:", error);
            alert(error.response?.data?.error || "Erreur lors de l'action");
        }
    };

    if (loading) return <div className="flex justify-center items-center h-64">Chargement...</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Demandes de Services</h1>

            {/* Stats */}
            <div className="grid grid-cols-3 gap-4 mb-6">
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <div className="flex items-center gap-2">
                        <ClockIcon className="h-5 w-5 text-yellow-500" />
                        <p className="text-gray-500 text-sm">En attente</p>
                    </div>
                    <p className="text-2xl font-bold text-yellow-600">{stats.pending_count || 0}</p>
                </div>
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <div className="flex items-center gap-2">
                        <CheckCircleIcon className="h-5 w-5 text-green-500" />
                        <p className="text-gray-500 text-sm">Approuvées</p>
                    </div>
                    <p className="text-2xl font-bold text-green-600">{stats.approved_count || 0}</p>
                </div>
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <div className="flex items-center gap-2">
                        <XCircleIcon className="h-5 w-5 text-red-500" />
                        <p className="text-gray-500 text-sm">Rejetées</p>
                    </div>
                    <p className="text-2xl font-bold text-red-600">{stats.rejected_count || 0}</p>
                </div>
            </div>

            {/* Filters */}
            <div className="flex gap-4 mb-6">
                <select
                    className="border rounded px-3 py-2 bg-white"
                    value={filter}
                    onChange={(e) => setFilter(e.target.value)}
                >
                    <option value="all">Tous les statuts</option>
                    <option value="pending">En attente</option>
                    <option value="approved">Approuvées</option>
                    <option value="rejected">Rejetées</option>
                </select>
                <select
                    className="border rounded px-3 py-2 bg-white"
                    value={typeFilter}
                    onChange={(e) => setTypeFilter(e.target.value)}
                >
                    <option value="all">Tous les types</option>
                    <option value="product_sponsorship">Sponsorisation</option>
                    <option value="user_verification">Vérification</option>
                    <option value="shop_certification">Certification</option>
                </select>
            </div>

            {/* Requests List */}
            <div className="bg-white shadow rounded-lg overflow-hidden">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Demandeur</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cible</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Montant</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Paiement</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                        {requests.length === 0 ? (
                            <tr>
                                <td colSpan="7" className="px-6 py-8 text-center text-gray-500">
                                    Aucune demande trouvée
                                </td>
                            </tr>
                        ) : (
                            requests.map((req) => {
                                const typeInfo = REQUEST_TYPES[req.request_type] || {};
                                const TypeIcon = typeInfo.icon || StarIcon;
                                const statusBadge = STATUS_BADGES[req.admin_status] || STATUS_BADGES.pending;
                                const paymentBadge = PAYMENT_BADGES[req.payment_status] || PAYMENT_BADGES.pending;

                                return (
                                    <tr key={req.id} className="hover:bg-gray-50">
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <div className="flex items-center">
                                                <img
                                                    src={getImageUrl(req.user_avatar) || `https://ui-avatars.com/api/?name=${req.user_name || 'U'}`}
                                                    alt=""
                                                    className="h-8 w-8 rounded-full object-cover"
                                                    onError={(e) => e.target.src = `https://ui-avatars.com/api/?name=${req.user_name || 'U'}`}
                                                />
                                                <div className="ml-3">
                                                    <div className="text-sm font-medium text-gray-900">{req.user_name || 'Inconnu'}</div>
                                                    <div className="text-xs text-gray-500">{req.user_phone}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <div className="flex items-center gap-2">
                                                <TypeIcon className={`h-5 w-5 ${typeInfo.color}`} />
                                                <span className="text-sm">{typeInfo.label}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                            {req.product_name || req.shop_name || '-'}
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                            {req.amount} $
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <span className={`px-2 py-1 text-xs rounded-full ${paymentBadge.bgColor} ${paymentBadge.textColor}`}>
                                                {paymentBadge.label}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <span className={`px-2 py-1 text-xs rounded-full ${statusBadge.bgColor} ${statusBadge.textColor}`}>
                                                {statusBadge.label}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            {req.admin_status === 'pending' && (
                                                <div className="flex gap-2">
                                                    <button
                                                        onClick={() => handleAction(req.id, 'approve')}
                                                        disabled={req.payment_status !== 'paid'}
                                                        className={`px-3 py-1 rounded text-white text-sm transition ${req.payment_status === 'paid'
                                                                ? 'bg-green-500 hover:bg-green-600'
                                                                : 'bg-gray-300 cursor-not-allowed'
                                                            }`}
                                                        title={req.payment_status !== 'paid' ? 'Paiement requis' : 'Approuver'}
                                                    >
                                                        Approuver
                                                    </button>
                                                    <button
                                                        onClick={() => handleAction(req.id, 'reject')}
                                                        className="px-3 py-1 rounded bg-red-500 hover:bg-red-600 text-white text-sm transition"
                                                    >
                                                        Rejeter
                                                    </button>
                                                </div>
                                            )}
                                            {req.admin_status !== 'pending' && (
                                                <span className="text-xs text-gray-400">Traité</span>
                                            )}
                                        </td>
                                    </tr>
                                );
                            })
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
