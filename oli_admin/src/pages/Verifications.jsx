import { useEffect, useState } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

const TABS = [
    { id: 'pending', label: 'En attente', count: true },
    { id: 'approved', label: 'Certifiés' },
    { id: 'rejected', label: 'Rejetés' },
];

const PlanBadge = ({ plan }) => {
    const config = {
        certified: { label: 'Certifié', color: 'bg-blue-100 text-blue-700 border-blue-200', icon: '✓' },
        enterprise: { label: 'Entreprise', color: 'bg-amber-100 text-amber-700 border-amber-200', icon: '🏆' },
    };
    const c = config[plan] || config.certified;
    return (
        <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold border ${c.color}`}>
            {c.icon} {c.label}
        </span>
    );
};

const DocTypeBadge = ({ type }) => {
    const label = type === 'passeport' ? '🛂 Passeport' : '🪪 Carte d\'identité';
    return <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded-full">{label}</span>;
};

export default function Verifications() {
    const [activeTab, setActiveTab] = useState('pending');
    const [pendingRequests, setPendingRequests] = useState([]);
    const [allRequests, setAllRequests] = useState([]);
    const [certifiedUsers, setCertifiedUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedImage, setSelectedImage] = useState(null);
    const [rejectModal, setRejectModal] = useState(null);
    const [rejectReason, setRejectReason] = useState('');
    const [notification, setNotification] = useState(null);

    useEffect(() => {
        fetchData();
    }, []);

    const showNotif = (message, type = 'success') => {
        setNotification({ message, type });
        setTimeout(() => setNotification(null), 4000);
    };

    const fetchData = async () => {
        setLoading(true);
        try {
            const [pending, certified, all] = await Promise.all([
                api.get('/admin/verifications/pending'),
                api.get('/admin/verifications'),
                api.get('/admin/verifications/all?status=rejected'),
            ]);
            setPendingRequests(pending.data);
            setCertifiedUsers(certified.data);
            setAllRequests(all.data);
        } catch (error) {
            console.error("Erreur fetch:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleApprove = async (requestId) => {
        if (!window.confirm("Approuver cette demande de certification ?")) return;
        try {
            await api.post(`/admin/verifications/${requestId}/approve`);
            showNotif("Certification approuvée ✅");
            fetchData();
        } catch (error) {
            showNotif(error.response?.data?.message || "Erreur", 'error');
        }
    };

    const handleReject = async () => {
        if (!rejectModal) return;
        try {
            await api.post(`/admin/verifications/${rejectModal}/reject`, { reason: rejectReason });
            showNotif("Demande rejetée");
            setRejectModal(null);
            setRejectReason('');
            fetchData();
        } catch (error) {
            showNotif(error.response?.data?.message || "Erreur", 'error');
        }
    };

    const handleRevoke = async (userId) => {
        if (!window.confirm("Révoquer cette certification ?")) return;
        try {
            await api.post(`/admin/verifications/${userId}/revoke`);
            showNotif("Certification révoquée");
            fetchData();
        } catch (error) {
            showNotif("Erreur lors de la révocation", 'error');
        }
    };

    if (loading) return <div className="flex justify-center items-center h-64 text-gray-500">Chargement...</div>;

    const renderPending = () => (
        <div className="space-y-4">
            {pendingRequests.length === 0 ? (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 text-center">
                    <p className="text-gray-400 text-lg">🎉 Aucune demande en attente</p>
                    <p className="text-gray-300 text-sm mt-2">Toutes les demandes ont été traitées</p>
                </div>
            ) : (
                pendingRequests.map((req) => (
                    <div key={req.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition-shadow">
                        <div className="p-6">
                            <div className="flex flex-col lg:flex-row gap-6">
                                {/* User Info */}
                                <div className="flex items-start gap-4 flex-1">
                                    <img
                                        className="h-14 w-14 rounded-full object-cover border-2 border-gray-100"
                                        src={getImageUrl(req.avatar_url) || `https://ui-avatars.com/api/?name=${req.user_name || 'U'}&background=0B1727&color=fff`}
                                        alt=""
                                    />
                                    <div className="flex-1">
                                        <h3 className="text-lg font-semibold text-gray-900">{req.user_name}</h3>
                                        <p className="text-sm text-gray-500">{req.user_phone}</p>
                                        <div className="flex items-center gap-2 mt-2">
                                            <PlanBadge plan={req.plan} />
                                            <DocTypeBadge type={req.document_type} />
                                        </div>
                                        <p className="text-xs text-gray-400 mt-2">
                                            Demandé le {new Date(req.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                                        </p>
                                    </div>
                                </div>

                                {/* ID Card Preview */}
                                <div className="flex-shrink-0">
                                    <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Document d'identité</p>
                                    <img
                                        src={getImageUrl(req.id_card_url)}
                                        alt="Carte d'identité"
                                        className="w-64 h-40 object-cover rounded-xl border-2 border-gray-200 cursor-pointer hover:border-blue-400 transition-colors"
                                        onClick={() => setSelectedImage(getImageUrl(req.id_card_url))}
                                    />
                                    <p className="text-xs text-blue-500 mt-1 cursor-pointer hover:underline" onClick={() => setSelectedImage(getImageUrl(req.id_card_url))}>
                                        Cliquer pour agrandir
                                    </p>
                                </div>
                            </div>

                            {/* Actions */}
                            <div className="flex items-center gap-3 mt-6 pt-4 border-t border-gray-100">
                                <button
                                    onClick={() => handleApprove(req.id)}
                                    className="flex-1 sm:flex-none px-6 py-2.5 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-xl text-sm font-semibold hover:from-emerald-600 hover:to-emerald-700 transition-all shadow-sm hover:shadow-md"
                                >
                                    ✅ Approuver
                                </button>
                                <button
                                    onClick={() => { setRejectModal(req.id); setRejectReason(''); }}
                                    className="flex-1 sm:flex-none px-6 py-2.5 bg-white border-2 border-red-200 text-red-600 rounded-xl text-sm font-semibold hover:bg-red-50 transition-all"
                                >
                                    ❌ Rejeter
                                </button>
                            </div>
                        </div>
                    </div>
                ))
            )}
        </div>
    );

    const renderCertified = () => (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                    <tr>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Utilisateur</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Plan</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Statut</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Expiration</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Actions</th>
                    </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                    {certifiedUsers.length === 0 && (
                        <tr><td colSpan="5" className="px-6 py-8 text-center text-gray-400">Aucun utilisateur certifié</td></tr>
                    )}
                    {certifiedUsers.map((user) => (
                        <tr key={user.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                                <div className="flex items-center gap-3">
                                    <img
                                        className="h-10 w-10 rounded-full object-cover"
                                        src={getImageUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`}
                                        alt=""
                                    />
                                    <div>
                                        <div className="text-sm font-medium text-gray-900">{user.name}</div>
                                        <div className="text-sm text-gray-500">{user.phone}</div>
                                    </div>
                                </div>
                            </td>
                            <td className="px-6 py-4"><PlanBadge plan={user.subscription_plan} /></td>
                            <td className="px-6 py-4">
                                <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${user.subscription_status === 'active' ? 'bg-green-100 text-green-700' :
                                        user.subscription_status === 'expired' ? 'bg-yellow-100 text-yellow-700' :
                                            'bg-red-100 text-red-700'
                                    }`}>
                                    {user.subscription_status}
                                </span>
                            </td>
                            <td className="px-6 py-4 text-sm text-gray-500">
                                {user.subscription_end_date ? new Date(user.subscription_end_date).toLocaleDateString('fr-FR') : '-'}
                            </td>
                            <td className="px-6 py-4">
                                <button
                                    onClick={() => handleRevoke(user.id)}
                                    className="text-red-500 hover:text-red-700 text-xs font-bold border border-red-200 px-3 py-1.5 rounded-lg bg-red-50 hover:bg-red-100 transition-colors"
                                >
                                    Révoquer
                                </button>
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );

    const renderRejected = () => (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                    <tr>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Utilisateur</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Plan</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Raison du rejet</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Document</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Date</th>
                    </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                    {allRequests.length === 0 && (
                        <tr><td colSpan="5" className="px-6 py-8 text-center text-gray-400">Aucune demande rejetée</td></tr>
                    )}
                    {allRequests.map((req) => (
                        <tr key={req.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4">
                                <div className="flex items-center gap-3">
                                    <img
                                        className="h-10 w-10 rounded-full object-cover"
                                        src={getImageUrl(req.avatar_url) || `https://ui-avatars.com/api/?name=${req.user_name || 'U'}&background=0B1727&color=fff`}
                                        alt=""
                                    />
                                    <div>
                                        <div className="text-sm font-medium text-gray-900">{req.user_name}</div>
                                        <div className="text-sm text-gray-500">{req.user_phone}</div>
                                    </div>
                                </div>
                            </td>
                            <td className="px-6 py-4"><PlanBadge plan={req.plan} /></td>
                            <td className="px-6 py-4 text-sm text-red-600 max-w-[250px]">{req.rejection_reason || '-'}</td>
                            <td className="px-6 py-4">
                                <img
                                    src={getImageUrl(req.id_card_url)}
                                    alt="ID"
                                    className="w-16 h-10 object-cover rounded cursor-pointer border hover:border-blue-400"
                                    onClick={() => setSelectedImage(getImageUrl(req.id_card_url))}
                                />
                            </td>
                            <td className="px-6 py-4 text-sm text-gray-500">
                                {new Date(req.created_at).toLocaleDateString('fr-FR')}
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* Notification Toast */}
            {notification && (
                <div className={`fixed top-6 right-6 z-50 px-5 py-3 rounded-xl shadow-lg text-white text-sm font-medium ${notification.type === 'error' ? 'bg-red-500' : 'bg-green-500'}`}>
                    {notification.message}
                </div>
            )}

            {/* Image Modal */}
            {selectedImage && (
                <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4" onClick={() => setSelectedImage(null)}>
                    <div className="relative max-w-4xl max-h-[90vh]">
                        <img src={selectedImage} alt="Document" className="max-w-full max-h-[85vh] object-contain rounded-2xl" />
                        <button
                            onClick={() => setSelectedImage(null)}
                            className="absolute -top-3 -right-3 w-8 h-8 bg-white rounded-full shadow-lg flex items-center justify-center text-gray-600 hover:text-gray-900"
                        >
                            ✕
                        </button>
                    </div>
                </div>
            )}

            {/* Reject Modal */}
            {rejectModal && (
                <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
                        <h3 className="text-lg font-bold text-gray-900 mb-4">Rejeter la demande</h3>
                        <textarea
                            value={rejectReason}
                            onChange={(e) => setRejectReason(e.target.value)}
                            placeholder="Raison du rejet (ex: Document illisible, Photo floue...)"
                            rows={3}
                            className="w-full border border-gray-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-red-500 focus:border-red-500 outline-none resize-none"
                        />
                        <div className="flex gap-3 mt-4">
                            <button
                                onClick={() => setRejectModal(null)}
                                className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-medium hover:bg-gray-200"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={handleReject}
                                className="flex-1 px-4 py-2.5 bg-red-500 text-white rounded-xl text-sm font-semibold hover:bg-red-600"
                            >
                                Confirmer le rejet
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Header */}
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
                        🛡️ Certifications
                    </h1>
                    <p className="text-sm text-gray-500 mt-1">Gérer les demandes de certification et les utilisateurs vérifiés</p>
                </div>
                <button
                    onClick={fetchData}
                    className="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50"
                >
                    ↻ Rafraîchir
                </button>
            </div>

            {/* Tabs */}
            <div className="flex gap-1 bg-white rounded-xl p-1 shadow-sm mb-8 border border-gray-100 w-fit">
                {TABS.map((tab) => (
                    <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all ${activeTab === tab.id
                                ? tab.id === 'pending' ? 'bg-amber-500 text-white shadow-md' : tab.id === 'rejected' ? 'bg-red-500 text-white shadow-md' : 'bg-emerald-500 text-white shadow-md'
                                : 'text-gray-600 hover:bg-gray-100'
                            }`}
                    >
                        {tab.label}
                        {tab.count && pendingRequests.length > 0 && (
                            <span className={`text-xs px-1.5 py-0.5 rounded-full ${activeTab === tab.id ? 'bg-white/30' : 'bg-amber-100 text-amber-700'}`}>
                                {pendingRequests.length}
                            </span>
                        )}
                    </button>
                ))}
            </div>

            {/* Tab Content */}
            {activeTab === 'pending' && renderPending()}
            {activeTab === 'approved' && renderCertified()}
            {activeTab === 'rejected' && renderRejected()}
        </div>
    );
}
