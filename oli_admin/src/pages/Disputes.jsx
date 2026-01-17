import { useEffect, useState } from 'react';
import api from '../services/api';
import { ExclamationTriangleIcon, CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/outline';

const STATUS_LABELS = {
    open: 'Ouvert',
    resolved: 'Résolu',
    rejected: 'Rejeté'
};

const STATUS_COLORS = {
    open: 'bg-yellow-100 text-yellow-800',
    resolved: 'bg-green-100 text-green-800',
    rejected: 'bg-gray-100 text-gray-800'
};

export default function Disputes() {
    const [disputes, setDisputes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedDispute, setSelectedDispute] = useState(null);
    const [resolutionNotes, setResolutionNotes] = useState('');

    useEffect(() => {
        fetchDisputes();
    }, []);

    const fetchDisputes = async () => {
        try {
            // En vrai app, on pourrait filtrer par status=open par défaut
            const { data } = await api.get('/admin/disputes');
            setDisputes(data);
        } catch (error) {
            console.error("Erreur disputes:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleResolve = async (status) => {
        if (!window.confirm(`Confirmer la résolution : ${STATUS_LABELS[status]} ?`)) return;

        try {
            await api.patch(`/admin/disputes/${selectedDispute.id}/resolve`, {
                status,
                resolution_notes: resolutionNotes
            });
            fetchDisputes();
            setSelectedDispute(null);
            setResolutionNotes('');
        } catch (error) {
            console.error("Erreur resolution:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    if (loading) return <div>Chargement des litiges...</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Gestion des Litiges</h1>

            {/* Stats rapides */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <div className="bg-white p-4 rounded shadow-sm border-l-4 border-yellow-500">
                    <div className="text-gray-500">En attente</div>
                    <div className="text-2xl font-bold">{disputes.filter(d => d.status === 'open').length}</div>
                </div>
                <div className="bg-white p-4 rounded shadow-sm border-l-4 border-green-500">
                    <div className="text-gray-500">Résolus</div>
                    <div className="text-2xl font-bold">{disputes.filter(d => d.status === 'resolved').length}</div>
                </div>
            </div>

            <div className="bg-white shadow overflow-hidden rounded-md">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Commande</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Signaleur</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Motif</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {disputes.map((dispute) => (
                            <tr key={dispute.id} className="hover:bg-gray-50">
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{dispute.id}</td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-blue-600">#{dispute.order_ref}</td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                    {dispute.reporter_name || 'Inconnu'} <br />
                                    <span className="text-gray-400 text-xs">{dispute.reporter_phone}</span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 truncate max-w-xs">{dispute.reason}</td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${STATUS_COLORS[dispute.status]}`}>
                                        {STATUS_LABELS[dispute.status]}
                                    </span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                    {new Date(dispute.created_at).toLocaleDateString()}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                    <button
                                        onClick={() => setSelectedDispute(dispute)}
                                        className="text-indigo-600 hover:text-indigo-900"
                                    >
                                        Gérer
                                    </button>
                                </td>
                            </tr>
                        ))}
                        {disputes.length === 0 && (
                            <tr>
                                <td colSpan="7" className="px-6 py-12 text-center text-gray-500">
                                    Aucun litige en cours 🎉
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>

            {/* Modal Résolution */}
            {selectedDispute && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
                    <div className="bg-white rounded-lg max-w-lg w-full p-6">
                        <h2 className="text-xl font-bold mb-4">Gérer le litige #{selectedDispute.id}</h2>

                        <div className="mb-4 bg-gray-50 p-3 rounded text-sm">
                            <p><strong>Commande :</strong> #{selectedDispute.order_ref}</p>
                            <p><strong>Signalé par :</strong> {selectedDispute.reporter_name} ({selectedDispute.reporter_phone})</p>
                            <p><strong>Contre :</strong> {selectedDispute.target_name || 'Vendeur'}</p>
                            <p className="mt-2"><strong>Motif :</strong> {selectedDispute.reason}</p>
                            <p className="mt-1 text-gray-600">"{selectedDispute.description || 'Pas de description'}"</p>
                        </div>

                        {selectedDispute.status === 'open' ? (
                            <div className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Note de résolution (Privé)</label>
                                    <textarea
                                        className="w-full border rounded p-2 text-sm"
                                        rows="3"
                                        placeholder="Expliquez la décision..."
                                        value={resolutionNotes}
                                        onChange={e => setResolutionNotes(e.target.value)}
                                    ></textarea>
                                </div>
                                <div className="flex justify-end space-x-3">
                                    <button
                                        onClick={() => setSelectedDispute(null)}
                                        className="px-4 py-2 border rounded text-gray-600 hover:bg-gray-50"
                                    >
                                        Annuler
                                    </button>
                                    <button
                                        onClick={() => handleResolve('rejected')}
                                        className="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300 flex items-center"
                                    >
                                        <XCircleIcon className="h-5 w-5 mr-1" /> Rejeter
                                    </button>
                                    <button
                                        onClick={() => handleResolve('resolved')}
                                        className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 flex items-center"
                                    >
                                        <CheckCircleIcon className="h-5 w-5 mr-1" /> Résoudre (Rembourser)
                                    </button>
                                </div>
                            </div>
                        ) : (
                            <div>
                                <div className="mb-4 p-3 bg-blue-50 text-blue-800 rounded text-sm">
                                    Ce litige est déjà <strong>{STATUS_LABELS[selectedDispute.status]}</strong>.
                                    {selectedDispute.resolution_notes && (
                                        <p className="mt-2 border-t border-blue-200 pt-2">
                                            <em>Note : {selectedDispute.resolution_notes}</em>
                                        </p>
                                    )}
                                </div>
                                <button
                                    onClick={() => setSelectedDispute(null)}
                                    className="w-full px-4 py-2 border rounded text-gray-600 hover:bg-gray-50"
                                >
                                    Fermer
                                </button>
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
