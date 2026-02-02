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
// import EnterpriseProfile from './EnterpriseProfile'; // TODO: À créer

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

// Sous-composant pour lister les produits
function UserProducts({ userId, limit }) {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchProducts = async () => {
            try {
                const { data } = await api.get(`/admin/users/${userId}/products`);
                setProducts(limit ? data.slice(0, limit) : data);
            } catch (error) {
                console.error("Erreur loading user products", error);
            } finally {
                setLoading(false);
            }
        };
        fetchProducts();
    }, [userId, limit]);

    if (loading) return <div className="p-4 text-center">Chargement des produits...</div>;

    if (products.length === 0) {
        return <div className="p-8 text-center text-gray-500 bg-white rounded shadow-sm border border-gray-100">Aucun produit mis en vente par cet utilisateur.</div>;
    }

    return (
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map(product => (
                <div key={product.id} className="bg-white border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition">
                    <div className="h-40 bg-gray-100 relative">
                        <img
                            src={getImageUrl(product.image_url)}
                            alt={product.name}
                            className="w-full h-full object-cover"
                            onError={(e) => e.target.src = 'https://via.placeholder.com/300?text=No+Image'}
                        />
                        <span className={`absolute top-2 right-2 px-2 py-1 text-xs rounded-full ${product.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                            }`}>
                            {product.status}
                        </span>
                    </div>
                    <div className="p-3">
                        <h4 className="font-bold text-gray-900 truncate">{product.name}</h4>
                        <div className="flex justify-between items-center mt-2">
                            <span className="text-blue-600 font-bold">{product.price} $</span>
                            <span className="text-xs text-gray-500">{new Date(product.created_at).toLocaleDateString()}</span>
                        </div>
                    </div>
                </div>
            ))}
        </div>
    );
}

export default function UserDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('overview');
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

            setUser({
                ...userData,
                city: userData.location || userData.city || 'Kinshasa', // Fallback
                roles: roles,
                wallet_balance: parseFloat(userData.wallet || 0),
                reward_points: userData.reward_points || 0,
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

    // Redirection vers le profil Entreprise si c'est un compte entreprise ou magasin certifié
    // On passe toggleView pour permettre de revenir à la vue admin classique si besoin (optionnel)
    // TODO: Créer le composant EnterpriseProfile
    /* if (user.account_type === 'entreprise' || user.has_certified_shop) {
        return <EnterpriseProfile user={user} onBack={() => navigate('/users')} />;
    } */

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
                            src={getImageUrl(user.avatar_url || user.avatar) || `https://ui-avatars.com/api/?name=${user.name || 'User'}&background=0B1727&color=fff&size=256`}
                            alt={user.name}
                            className="w-32 h-32 rounded-full border-4 border-white shadow-md object-cover bg-white"
                            onError={(e) => {
                                e.target.onerror = null;
                                e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'User'}&background=0B1727&color=fff`;
                            }}
                        />
                        {/* Twitter-style Scalloped Verification Badge */}
                        {(user.is_verified || user.account_type === 'certifie' || user.account_type === 'entreprise' || user.has_certified_shop) && (
                            <div className="absolute bottom-0 right-0">
                                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                    <path
                                        d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5c-1.51 0-2.816.917-3.437 2.25-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484z"
                                        fill={
                                            user.has_certified_shop ? '#D4A500' :
                                                user.account_type === 'entreprise' ? '#D4A500' :
                                                    '#1DA1F2'
                                        }
                                    />
                                    <path d="M9.5 16.5L5.5 12.5l1.41-1.41L9.5 13.67l7.09-7.09L18 8l-8.5 8.5z" fill="white" />
                                </svg>
                            </div>
                        )}
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
                                onClick={async () => {
                                    const newValue = !user.is_verified;
                                    if (window.confirm(`${newValue ? 'Vérifier' : 'Retirer la vérification de'} cet utilisateur ?`)) {
                                        try {
                                            await api.patch(`/admin/users/${user.id}/verify`, { verified: newValue });
                                            setUser({ ...user, is_verified: newValue });
                                            alert(newValue ? 'Utilisateur vérifié !' : 'Vérification retirée');
                                        } catch (err) {
                                            console.error(err);
                                            alert("Erreur lors de la mise à jour");
                                        }
                                    }
                                }}
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border cursor-pointer hover:opacity-80 transition ${user.is_verified
                                    ? 'bg-green-100 text-green-800 border-green-200'
                                    : 'bg-gray-100 text-gray-500 border-gray-200'
                                    }`}
                            >
                                <TagIcon className="h-3 w-3 mr-1" />
                                {user.is_verified ? 'Vendeur Vérifié' : 'Non Vérifié'}
                            </button>

                            <button
                                onClick={async () => {
                                    const newValue = !user.is_seller;
                                    if (window.confirm(`${newValue ? 'Promouvoir' : 'Retirer'} le statut vendeur ?`)) {
                                        try {
                                            await api.patch(`/admin/users/${user.id}/role`, { is_seller: newValue });
                                            setUser({ ...user, is_seller: newValue });
                                            alert(newValue ? 'Statut vendeur accordé !' : 'Statut vendeur retiré');
                                        } catch (err) {
                                            console.error(err);
                                            alert("Erreur lors de la mise à jour");
                                        }
                                    }
                                }}
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border cursor-pointer hover:opacity-80 transition ${user.is_seller
                                    ? 'bg-blue-100 text-blue-800 border-blue-200'
                                    : 'bg-gray-100 text-gray-500 border-gray-200'
                                    }`}
                            >
                                {user.is_seller ? 'Vendeur' : 'Client'}
                            </button>
                        </div>
                    </div>

                    {/* Account Type Selector */}
                    <div className="flex flex-col gap-2 mt-4 md:mt-0 mr-4">
                        <span className="text-xs text-gray-500 font-medium">Type de compte:</span>
                        <div className="flex flex-wrap gap-2">
                            {[
                                { value: 'ordinaire', label: 'Ordinaire', color: 'gray' },
                                { value: 'certifie', label: 'Certifié ✓', color: 'blue' },
                                { value: 'entreprise', label: 'Entreprise 🏢', color: 'yellow' }
                            ].map(type => (
                                <button
                                    key={type.value}
                                    onClick={async () => {
                                        if (window.confirm(`Définir comme compte ${type.label} ?`)) {
                                            try {
                                                await api.patch(`/admin/users/${user.id}/account-type`, { account_type: type.value });
                                                setUser({ ...user, account_type: type.value });
                                                alert(`Compte défini comme ${type.label}`);
                                            } catch (err) {
                                                console.error(err);
                                                alert("Erreur lors de la mise à jour");
                                            }
                                        }
                                    }}
                                    className={`px-3 py-1 rounded-full text-xs font-medium border transition ${user.account_type === type.value
                                        ? `bg-${type.color}-500 text-white border-${type.color}-600`
                                        : `bg-${type.color}-50 text-${type.color}-700 border-${type.color}-200 hover:bg-${type.color}-100`
                                        }`}
                                    style={{
                                        backgroundColor: user.account_type === type.value
                                            ? (type.color === 'gray' ? '#6b7280' : type.color === 'blue' ? '#3b82f6' : type.color === 'yellow' ? '#eab308' : '#9333ea')
                                            : undefined,
                                        color: user.account_type === type.value ? 'white' : undefined
                                    }}
                                >
                                    {type.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Actions Buttons */}
                    <div className="flex gap-3 mt-4 md:mt-0">
                        <button
                            onClick={async () => {
                                const msg = prompt("Message à envoyer à " + user.name + " :");
                                if (msg && msg.trim()) {
                                    try {
                                        await api.post(`/admin/users/${user.id}/message`, { content: msg });
                                        alert("Message envoyé sur la messagerie Oli !");
                                    } catch (err) {
                                        console.error(err);
                                        alert("Erreur lors de l'envoi");
                                    }
                                }
                            }}
                            className="flex items-center px-4 py-2 bg-blue-600 text-white rounded shadow-sm hover:bg-blue-700 transition"
                        >
                            <EnvelopeIcon className="h-4 w-4 mr-2" />
                            Envoyer Message (Oli)
                        </button>
                        <button
                            onClick={async () => {
                                if (window.confirm(user.is_active ? 'Voulez-vous vraiment BLOQUER cet utilisateur ?' : 'Voulez-vous DÉBLOQUER cet utilisateur ?')) {
                                    try {
                                        await api.post(`/admin/users/${user.id}/suspend`, { suspended: user.is_active });
                                        setUser({ ...user, is_active: !user.is_active });
                                        alert(user.is_active ? 'Utilisateur bloqué avec succès' : 'Utilisateur débloqué');
                                    } catch (err) {
                                        console.error(err);
                                        alert("Erreur lors de l'action");
                                    }
                                }
                            }}
                            className={`flex items-center px-4 py-2 text-white rounded shadow-sm transition ${user.is_active
                                ? 'bg-red-600 hover:bg-red-700'
                                : 'bg-green-600 hover:bg-green-700'}`}
                        >
                            <NoSymbolIcon className="h-4 w-4 mr-2" />
                            {user.is_active ? 'BLOQUER COMPTE' : 'DÉBLOQUER'}
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
            {activeTab === 'overview' && (
                <div className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                            <h3 className="text-sm font-medium text-gray-500 uppercase">Solde Wallet</h3>
                            <p className="mt-2 text-2xl font-bold text-gray-900">{user.wallet_balance.toLocaleString()} FC</p>
                        </div>
                        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                            <h3 className="text-sm font-medium text-gray-500 uppercase">Points Fidelity</h3>
                            <p className="mt-2 text-2xl font-bold text-gray-900">{user.reward_points} Pts</p>
                        </div>
                        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                            <h3 className="text-sm font-medium text-gray-500 uppercase">Produits en vente</h3>
                            <p className="mt-2 text-2xl font-bold text-gray-900">{user.stats?.products_count || 0}</p>
                        </div>
                    </div>

                    <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100">
                        <div className="flex justify-between items-center mb-4">
                            <h3 className="font-bold text-gray-900">Aperçu du Marketplace</h3>
                            <button onClick={() => setActiveTab('marketplace')} className="text-blue-600 text-sm font-medium hover:underline">
                                Voir tout
                            </button>
                        </div>
                        <UserProducts userId={id} limit={4} />
                    </div>
                </div>
            )}

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
            {/* Onglet Marketplace (Produits) */}
            {activeTab === 'marketplace' && (
                <div>
                    <UserProducts userId={id} />
                </div>
            )}

            {/* Placeholder pour autres onglets non implémentés */}
            {activeTab !== 'finance' && activeTab !== 'marketplace' && (
                <div className="bg-white p-12 rounded-lg text-center text-gray-500 border border-gray-100 border-dashed">
                    Contenu de l'onglet <strong>{activeTab}</strong> en cours de développement...
                </div>
            )}
        </div>
    );
}
