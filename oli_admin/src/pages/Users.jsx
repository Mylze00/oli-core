import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

// Twitter/X-style Scalloped Verification Badge
const VerificationBadge = ({ type = 'blue', size = 20 }) => {
    const colors = {
        blue: '#1DA1F2',    // Certifié
        gold: '#D4A500',    // Magasin certifié / Entreprise
        gray: '#71767B',    // Standard  
        green: '#00BA7C',   // Premium
        purple: '#9333EA'   // Entreprise
    };
    const color = colors[type] || colors.blue;

    return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            {/* Scalloped background */}
            <path
                d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5c-1.51 0-2.816.917-3.437 2.25-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484z"
                fill={color}
            />
            {/* Checkmark */}
            <path
                d="M9.5 16.5L5.5 12.5l1.41-1.41L9.5 13.67l7.09-7.09L18 8l-8.5 8.5z"
                fill="white"
            />
        </svg>
    );
};

// Badge for account type (text badge)
const AccountBadge = ({ type }) => {
    const badges = {
        'certifie': { label: 'Certifié', bg: 'bg-blue-100', text: 'text-blue-600', border: 'border-blue-200' },
        'premium': { label: 'Premium', bg: 'bg-green-100', text: 'text-green-600', border: 'border-green-200' },
        'entreprise': { label: 'Entreprise', bg: 'bg-purple-100', text: 'text-purple-600', border: 'border-purple-200' }
    };
    const badge = badges[type];
    if (!badge) return null;
    return (
        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${badge.bg} ${badge.text} border ${badge.border}`}>
            {badge.label}
        </span>
    );
};

// Gold shop badge
const ShopBadge = () => (
    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700 border border-amber-300">
        🏪 Magasin Certifié
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
                                                {(user.is_verified || user.account_type === 'certifie' || user.account_type === 'premium' || user.account_type === 'entreprise' || user.has_certified_shop) && (
                                                    <div className="absolute -bottom-1 -right-1">
                                                        <VerificationBadge
                                                            type={
                                                                user.has_certified_shop ? 'gold' :
                                                                    user.account_type === 'entreprise' ? 'gold' :
                                                                        user.account_type === 'premium' ? 'green' :
                                                                            user.account_type === 'certifie' ? 'blue' :
                                                                                user.is_verified ? 'blue' : 'gray'
                                                            }
                                                            size={18}
                                                        />
                                                    </div>
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
