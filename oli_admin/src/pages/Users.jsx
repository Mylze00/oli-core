import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import { CheckBadgeIcon, BuildingStorefrontIcon, StarIcon, BriefcaseIcon } from '@heroicons/react/24/solid';

// Badge components
const AccountBadge = ({ type }) => {
    const badges = {
        'certifie': { icon: CheckBadgeIcon, label: 'Certifié', bg: 'bg-blue-100', text: 'text-blue-600', border: 'border-blue-200' },
        'premium': { icon: StarIcon, label: 'Premium', bg: 'bg-yellow-100', text: 'text-yellow-600', border: 'border-yellow-200' },
        'entreprise': { icon: BriefcaseIcon, label: 'Entreprise', bg: 'bg-purple-100', text: 'text-purple-600', border: 'border-purple-200' }
    };
    const badge = badges[type];
    if (!badge) return null;
    const Icon = badge.icon;
    return (
        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${badge.bg} ${badge.text} border ${badge.border}`}>
            <Icon className="h-3 w-3 mr-1" />
            {badge.label}
        </span>
    );
};

const ShopBadge = () => (
    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700 border border-amber-300">
        <BuildingStorefrontIcon className="h-3 w-3 mr-1" />
        Magasin Certifié
    </span>
);

export default function Users() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [searchParams] = useSearchParams();

    useEffect(() => {
        // Check for search param from header
        const searchFromUrl = searchParams.get('search');
        if (searchFromUrl) setSearch(searchFromUrl);
        fetchUsers();
    }, [searchParams]);

    const fetchUsers = async () => {
        try {
            const { data } = await api.get('/admin/users');
            setUsers(data);
        } catch (error) {
            console.error("Erreur users:", error);
        } finally {
            setLoading(false);
        }
    };

    const handlePromote = async (userId, role, currentValue) => {
        if (!window.confirm(`Voulez-vous changer le rôle ${role} ?`)) return;
        try {
            await api.patch(`/admin/users/${userId}/role`, { [role]: !currentValue });
            fetchUsers();
        } catch (error) {
            console.error("Erreur update role:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const filteredUsers = users.filter(u =>
        u.phone?.includes(search) || u.name?.toLowerCase().includes(search.toLowerCase())
    );

    if (loading) return <div className="flex justify-center items-center h-64">Chargement...</div>;

    return (
        <div>
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Utilisateurs</h1>
                <input
                    type="text"
                    placeholder="Rechercher..."
                    className="border p-2 rounded"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                />
            </div>

            <div className="bg-white shadow overflow-hidden rounded-md">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Utilisateur</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Rôles</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Portefeuille</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actes</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {filteredUsers.map((user) => (
                            <tr key={user.id} className="hover:bg-gray-50">
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex items-center">
                                        <Link to={`/users/${user.id}`} className="flex items-center group cursor-pointer">
                                            <div className="flex-shrink-0 h-10 w-10 relative">
                                                <img
                                                    className="h-10 w-10 rounded-full object-cover border-2 border-gray-200"
                                                    src={getImageUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`}
                                                    alt=""
                                                    onError={(e) => {
                                                        e.target.onerror = null;
                                                        e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`;
                                                    }}
                                                />
                                                {/* Badge overlay for verified accounts */}
                                                {user.is_verified && (
                                                    <CheckBadgeIcon className="absolute -bottom-1 -right-1 h-5 w-5 text-blue-500 bg-white rounded-full" />
                                                )}
                                            </div>
                                            <div className="ml-4">
                                                <div className="text-sm font-medium text-gray-900 group-hover:text-blue-600 transition-colors flex items-center gap-2">
                                                    {user.name || 'Sans nom'}
                                                </div>
                                                <div className="text-sm text-gray-500">{user.phone}</div>
                                            </div>
                                        </Link>
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex flex-wrap gap-1">
                                        {user.is_admin && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">Admin</span>}
                                        {user.is_seller && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">Vendeur</span>}
                                        {user.is_deliverer && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">Livreur</span>}
                                        {/* Account type badges */}
                                        <AccountBadge type={user.account_type} />
                                        {user.has_certified_shop && <ShopBadge />}
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                    {parseFloat(user.wallet || 0).toFixed(2)} $
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                    <button onClick={() => handlePromote(user.id, 'is_admin', user.is_admin)} className="text-indigo-600 hover:text-indigo-900 mr-4">
                                        {user.is_admin ? 'Administrateur du retrait' : 'Mettre Admin'}
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
