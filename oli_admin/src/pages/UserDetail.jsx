import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    EnvelopeIcon,
    NoSymbolIcon,
    CheckCircleIcon,
    TagIcon,
    MapPinIcon,
    PhoneIcon,
    ChevronLeftIcon
} from '@heroicons/react/24/solid';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

// Composant Helper pour les onglets
function TabButton({ label, active, onClick }) {
    return (
        <button
            onClick={onClick}
            className={`px-6 py-4 text-sm font-medium border-b-2 transition-colors ${active
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
        >
            {label}
        </button>
    );
}

export default function UserDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('finance');
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // En mode démo, on simule un user si l'API n'est pas encore prête pour ce niveau de détail
        // Mais essayons de fetcher d'abord
        fetchUser();
    }, [id]);

    const fetchUser = async () => {
        try {
            const { data } = await api.get(`/admin/users/${id}`);
            // Mapping des données API vers le format attendu par l'UI
            const userData = data.user || data; // Gérer structure {user: {...}, stats: {...}} ou direct
            const stats = data.stats || {};

            const roles = [];
            if (userData.is_admin) roles.push('admin');
            if (userData.is_seller) roles.push('seller');
            if (userData.is_deliverer) roles.push('deliverer');
            // Mock pour verified/premium tant que pas dans DB
            if (userData.is_verified || userData.verified_at) roles.push('verified');
            if (userData.is_premium) roles.push('premium');

            setUser({
                ...userData,
                city: userData.location || userData.city || 'Kinshasa', // Fallback
                roles: roles,
                wallet_balance: parseFloat(userData.wallet || 0),
                reward_points: userData.reward_points || 0,
                is_active: !userData.is_suspended,
                is_active: !userData.is_suspended,
                stats: stats,
                transactions: data.transactions || []
            });
        } catch (error) {
            console.error("Erreur user:", error);
            // Fallback pour éviter page blanche si erreur
            setUser({
                id: id,
                name: 'Utilisateur Inconnu',
                phone: 'N/A',
                city: 'N/A',
                avatar: null,
                roles: [],
                wallet_balance: 0,
                reward_points: 0,
                is_active: false
            });
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div>Chargement...</div>;

    return (
        <div className="space-y-6">
            {/* Navigation Retour */}
            <button onClick={() => navigate('/users')} className="flex items-center text-gray-500 hover:text-gray-700">
                <ChevronLeftIcon className="h-4 w-4 mr-1" /> Retour aux utilisateurs
            </button>

            {/* Header Carte Profil */}
            <div className="bg-white rounded-lg shadow-sm overflow-hidden border border-gray-100">
                {/* Bandeau Coloré */}
                <div className="h-24 bg-gradient-to-r from-blue-600 to-green-500 relative">
                    <div className="absolute top-4 right-4 bg-white/20 backdrop-blur rounded-full px-3 py-1 flex items-center text-white text-xs font-bold border border-white/30">
                        ACTIF <div className="ml-2 w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
                    </div>
                </div>

                <div className="px-8 pb-8 flex flex-col md:flex-row items-start md:items-end -mt-12 gap-6">
                    {/* Avatar */}
                    <div className="relative">
                        <img
                            src={getImageUrl(user.avatar) || "https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80"}
                            alt={user.name}
                            className="w-32 h-32 rounded-full border-4 border-white shadow-md object-cover bg-white"
                            onError={(e) => {
                                e.target.onerror = null;
                                e.target.src = "https://ui-avatars.com/api/?name=" + (user.name || 'User') + "&background=random";
                            }}
                        />
                    </div>

                    {/* Infos Principales */}
                    <div className="flex-1 pt-14 md:pt-0">
                        <h1 className="text-2xl font-bold text-gray-900">{user.name}</h1>

                        <div className="flex flex-col sm:flex-row gap-4 text-gray-500 text-sm mt-2">
                            <div className="flex items-center">
                                <PhoneIcon className="h-4 w-4 mr-1" /> {user.phone}
                            </div>
                            <div className="flex items-center">
                                <MapPinIcon className="h-4 w-4 mr-1" /> {user.city}
                            </div>
                        </div>

                        {/* Actions Badges (Clickable) */}
                        <div className="flex gap-2 mt-3">
                            <button
                                onClick={() => {
                                    if (window.confirm('Changer le statut Vérifié ?')) {
                                        // TODO: Call API
                                        alert('Statut mis à jour (Simulation)');
                                    }
                                }}
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border cursor-pointer hover:opacity-80 transition ${user.roles?.includes('verified')
                                    ? 'bg-green-100 text-green-800 border-green-200'
                                    : 'bg-gray-100 text-gray-500 border-gray-200'
                                    }`}
                            >
                                <TagIcon className="h-3 w-3 mr-1" />
                                {user.roles?.includes('verified') ? 'Vendeur Vérifié' : 'Non Vérifié'}
                            </button>

                            <button
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border cursor-pointer hover:opacity-80 transition ${user.roles?.includes('premium')
                                    ? 'bg-blue-100 text-blue-800 border-blue-200'
                                    : 'bg-gray-100 text-gray-500 border-gray-200'
                                    }`}
                            >
                                {user.roles?.includes('premium') ? 'Premium' : 'Standard'}
                            </button>
                        </div>
                    </div>

                    {/* Actions Buttons */}
                    <div className="flex gap-3 mt-4 md:mt-0">
                        <a
                            href={`sms:${user.phone}`}
                            className="flex items-center px-4 py-2 bg-blue-600 text-white rounded shadow-sm hover:bg-blue-700 transition"
                        >
                            <EnvelopeIcon className="h-4 w-4 mr-2" />
                            Envoyer Message
                        </a>
                        <button
                            onClick={() => {
                                if (window.confirm('Voulez-vous vraiment BLOQUER cet utilisateur ?')) {
                                    // TODO: Call API /admin/users/:id/block
                                    alert('Utilisateur bloqué (Simulation)');
                                }
                            }}
                            className="flex items-center px-4 py-2 bg-red-600 text-white rounded shadow-sm hover:bg-red-700 transition"
                        >
                            <NoSymbolIcon className="h-4 w-4 mr-2" />
                            BLOQUER COMPTE
                        </button>
                    </div>
                </div>
            </div>

            {/* Navigation Onglets */}
            <div className="bg-white rounded-lg shadow-sm border-b border-gray-200 px-2 lg:px-8">
                <div className="flex space-x-2 overflow-x-auto">
                    <TabButton label="Vue Générale" active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} />
                    <TabButton label="Finance & Wallet" active={activeTab === 'finance'} onClick={() => setActiveTab('finance')} />
                    <TabButton label="Marketplace" active={activeTab === 'marketplace'} onClick={() => setActiveTab('marketplace')} />
                    <TabButton label="Livreur" active={activeTab === 'delivery'} onClick={() => setActiveTab('delivery')} />
                    <TabButton label="Sécurité" active={activeTab === 'security'} onClick={() => setActiveTab('security')} />
                </div>
            </div>

            {/* Contenu Onglets */}
            {activeTab === 'finance' && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

                    {/* Colonne Gauche: Wallet & Methods */}
                    <div className="space-y-6">
                        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                            <div className="space-y-4">
                                <div>
                                    <p className="text-gray-500 font-medium">Solde Wallet Oli</p>
                                    <p className="text-3xl font-bold text-gray-900">{user.wallet_balance.toLocaleString()} FC</p>
                                </div>
                                <div className="border-t pt-4">
                                    <p className="text-gray-500 font-medium">Points Récompense</p>
                                    <p className="text-xl font-bold text-gray-900">{user.reward_points} Pts</p>
                                </div>
                            </div>
                        </div>

                        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                            <h3 className="font-semibold text-gray-900 mb-4">Comptes Mobile Money Liés</h3>
                            <div className="space-y-3">
                                <div className="flex justify-between items-center p-3 bg-gray-50 rounded border border-gray-200">
                                    <span className="text-gray-700">Orange Money (***9988)</span>
                                    <CheckCircleIcon className="h-5 w-5 text-green-500" />
                                </div>
                                <div className="flex justify-between items-center p-3 bg-gray-50 rounded border border-gray-200">
                                    <span className="text-gray-700">Airtel Money (***1122)</span>
                                    <CheckCircleIcon className="h-5 w-5 text-green-500" />
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Colonne Droite: Historique */}
                    <div className="bg-white rounded-lg shadow-sm border border-gray-100">
                        <div className="p-4 border-b border-gray-100">
                            <h3 className="font-semibold text-gray-900">Historique des Transactions</h3>
                        </div>
                        <div className="divide-y divide-gray-100">
                            {(user.transactions && user.transactions.length > 0) ? (
                                user.transactions.map((tx) => (
                                    <div key={tx.id} className="p-4 flex justify-between items-center hover:bg-gray-50">
                                        <div className="flex gap-3">
                                            <span className="text-gray-500 text-sm font-mono">
                                                {new Date(tx.created_at).toLocaleDateString(undefined, { day: '2-digit', month: '2-digit' })}
                                            </span>
                                            <span className="text-gray-700 text-sm">{tx.description || tx.type}</span>
                                        </div>
                                        <span className={`font-medium text-sm ${parseFloat(tx.amount) > 0 ? 'text-green-600' : 'text-red-600'}`}>
                                            {parseFloat(tx.amount) > 0 ? '+' : ''}{parseFloat(tx.amount).toLocaleString()} FC
                                        </span>
                                    </div>
                                ))
                            ) : (
                                <div className="p-6 text-center text-gray-400 italic">
                                    Aucune transaction récente
                                </div>
                            )}
                        </div>
                        <div className="p-3 text-center border-t border-gray-100">
                            <button className="text-blue-600 text-sm font-medium hover:underline">Voir tout l'historique</button>
                        </div>
                    </div>

                </div>
            )}

            {/* Placeholder pour autres onglets */}
            {activeTab !== 'finance' && (
                <div className="bg-white p-12 rounded-lg text-center text-gray-500 border border-gray-100 border-dashed">
                    Contenu de l'onglet <strong>{activeTab}</strong> en cours de dévelopement...
                </div>
            )}
        </div>
    );
}
