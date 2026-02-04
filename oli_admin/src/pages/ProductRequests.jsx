import { useEffect, useState } from 'react';
import api from '../services/api';
import {
    ChatBubbleLeftIcon,
    ClockIcon,
    CheckCircleIcon,
    XCircleIcon,
    EnvelopeIcon,
    PhoneIcon,
    PhotoIcon
} from '@heroicons/react/24/solid';

const STATUS_CONFIG = {
    pending: { label: 'En attente', bg: 'bg-yellow-100', text: 'text-yellow-800', icon: ClockIcon },
    reviewed: { label: 'En cours', bg: 'bg-blue-100', text: 'text-blue-800', icon: ChatBubbleLeftIcon },
    responded: { label: 'Répondu', bg: 'bg-green-100', text: 'text-green-800', icon: CheckCircleIcon },
    closed: { label: 'Fermée', bg: 'bg-gray-100', text: 'text-gray-600', icon: XCircleIcon }
};

export default function ProductRequests() {
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('pending');
    const [selectedRequest, setSelectedRequest] = useState(null);
    const [responseText, setResponseText] = useState('');

    useEffect(() => {
        fetchRequests();
    }, [filter]);

    const fetchRequests = async () => {
        try {
            setLoading(true);
            const { data } = await api.get('/api/product-requests');
            // Filtrer localement pour simplifier (pas besoin de modifier le backend)
            const filtered = filter === 'all'
                ? data
                : data.filter(r => r.status === filter);
            setRequests(filtered);
        } catch (error) {
            console.error("Erreur:", error);
        } finally {
            setLoading(false);
        }
    };

    const updateStatus = async (id, status, adminResponse = null) => {
        try {
            await api.patch(`/api/product-requests/${id}/status`, {
                status,
                admin_response: adminResponse
            });
            fetchRequests();
            setSelectedRequest(null);
            setResponseText('');
            alert('Statut mis à jour !');
        } catch (error) {
            console.error("Erreur:", error);
            alert('Erreur lors de la mise à jour');
        }
    };

    const handleRespond = () => {
        if (!responseText.trim()) {
            alert('Veuillez saisir une réponse');
            return;
        }
        updateStatus(selectedRequest.id, 'responded', responseText);
    };

    const deleteRequest = async (id) => {
        if (!window.confirm('Supprimer cette demande ?')) return;
        try {
            await api.delete(`/api/product-requests/${id}`);
            fetchRequests();
            alert('Demande supprimée');
        } catch (error) {
            console.error("Erreur:", error);
        }
    };

    const formatDate = (dateStr) => {
        return new Date(dateStr).toLocaleDateString('fr-FR', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    // Stats
    const pendingCount = requests.filter(r => r.status === 'pending').length;

    if (loading) return <div className="flex justify-center items-center h-64">Chargement...</div>;

    return (
        <div>
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">📦 Demandes de Produit</h1>
                    <p className="text-gray-500 text-sm mt-1">
                        Messages des utilisateurs cherchant des produits spécifiques
                    </p>
                </div>

                {pendingCount > 0 && (
                    <div className="bg-orange-100 text-orange-800 px-4 py-2 rounded-full flex items-center gap-2">
                        <EnvelopeIcon className="h-5 w-5" />
                        <span className="font-bold">{pendingCount}</span>
                        <span>nouvelle(s) demande(s)</span>
                    </div>
                )}
            </div>

            {/* Filtres */}
            <div className="flex gap-2 mb-6">
                {['all', 'pending', 'reviewed', 'responded', 'closed'].map(status => (
                    <button
                        key={status}
                        onClick={() => setFilter(status)}
                        className={`px-4 py-2 rounded-full text-sm font-medium transition ${filter === status
                                ? 'bg-indigo-600 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                            }`}
                    >
                        {status === 'all' ? 'Toutes' : STATUS_CONFIG[status]?.label || status}
                    </button>
                ))}
            </div>

            {/* Liste des demandes */}
            <div className="grid gap-4">
                {requests.length === 0 ? (
                    <div className="bg-white rounded-lg p-8 text-center text-gray-500">
                        Aucune demande trouvée
                    </div>
                ) : (
                    requests.map((req) => {
                        const statusConfig = STATUS_CONFIG[req.status] || STATUS_CONFIG.pending;
                        const StatusIcon = statusConfig.icon;

                        return (
                            <div
                                key={req.id}
                                className="bg-white rounded-lg shadow-sm border p-6 hover:shadow-md transition"
                            >
                                <div className="flex justify-between items-start">
                                    {/* Header */}
                                    <div className="flex items-start gap-4">
                                        <div className="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full flex items-center justify-center text-white font-bold text-lg">
                                            {req.user_name?.[0]?.toUpperCase() || 'U'}
                                        </div>
                                        <div>
                                            <h3 className="font-semibold text-gray-900">{req.user_name || 'Utilisateur'}</h3>
                                            {req.user_phone && (
                                                <p className="text-sm text-gray-500 flex items-center gap-1">
                                                    <PhoneIcon className="h-3 w-3" />
                                                    {req.user_phone}
                                                </p>
                                            )}
                                            <p className="text-xs text-gray-400 mt-1">{formatDate(req.created_at)}</p>
                                        </div>
                                    </div>

                                    {/* Status Badge */}
                                    <span className={`px-3 py-1 rounded-full text-xs font-medium flex items-center gap-1 ${statusConfig.bg} ${statusConfig.text}`}>
                                        <StatusIcon className="h-3 w-3" />
                                        {statusConfig.label}
                                    </span>
                                </div>

                                {/* Description */}
                                <div className="mt-4 p-4 bg-gray-50 rounded-lg">
                                    <p className="text-gray-700 whitespace-pre-wrap">{req.description}</p>
                                </div>

                                {/* Image si présente */}
                                {req.image_url && (
                                    <div className="mt-4">
                                        <div className="flex items-center gap-1 text-sm text-gray-500 mb-2">
                                            <PhotoIcon className="h-4 w-4" />
                                            Image jointe
                                        </div>
                                        <img
                                            src={req.image_url}
                                            alt="Pièce jointe"
                                            className="max-w-xs rounded-lg border"
                                        />
                                    </div>
                                )}

                                {/* Réponse admin si existante */}
                                {req.admin_response && (
                                    <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
                                        <p className="text-sm font-medium text-green-800 mb-1">Réponse de l'équipe OLI :</p>
                                        <p className="text-green-700">{req.admin_response}</p>
                                    </div>
                                )}

                                {/* Actions */}
                                <div className="mt-4 flex gap-2 justify-end">
                                    {req.status === 'pending' && (
                                        <>
                                            <button
                                                onClick={() => updateStatus(req.id, 'reviewed')}
                                                className="px-4 py-2 bg-blue-100 text-blue-700 rounded-lg text-sm font-medium hover:bg-blue-200"
                                            >
                                                Marquer "En cours"
                                            </button>
                                            <button
                                                onClick={() => setSelectedRequest(req)}
                                                className="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600"
                                            >
                                                Répondre
                                            </button>
                                        </>
                                    )}
                                    {req.status === 'reviewed' && (
                                        <button
                                            onClick={() => setSelectedRequest(req)}
                                            className="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600"
                                        >
                                            Répondre
                                        </button>
                                    )}
                                    {req.status === 'responded' && (
                                        <button
                                            onClick={() => updateStatus(req.id, 'closed')}
                                            className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-medium hover:bg-gray-200"
                                        >
                                            Clôturer
                                        </button>
                                    )}
                                    <button
                                        onClick={() => deleteRequest(req.id)}
                                        className="px-4 py-2 bg-red-100 text-red-700 rounded-lg text-sm font-medium hover:bg-red-200"
                                    >
                                        Supprimer
                                    </button>
                                </div>
                            </div>
                        );
                    })
                )}
            </div>

            {/* Modal réponse */}
            {selectedRequest && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                    <div className="bg-white rounded-xl p-6 w-full max-w-lg mx-4">
                        <h3 className="text-lg font-bold mb-4">Répondre à {selectedRequest.user_name}</h3>

                        <div className="bg-gray-50 p-3 rounded-lg mb-4 text-sm text-gray-600">
                            "{selectedRequest.description?.substring(0, 150)}..."
                        </div>

                        <textarea
                            value={responseText}
                            onChange={(e) => setResponseText(e.target.value)}
                            placeholder="Votre réponse..."
                            className="w-full border rounded-lg p-3 h-32 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                        />

                        <div className="flex gap-2 mt-4 justify-end">
                            <button
                                onClick={() => {
                                    setSelectedRequest(null);
                                    setResponseText('');
                                }}
                                className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={handleRespond}
                                className="px-4 py-2 bg-green-500 text-white rounded-lg font-medium"
                            >
                                Envoyer la réponse
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
