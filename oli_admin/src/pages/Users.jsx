import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';

export default function Users() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');

    useEffect(() => {
        fetchUsers();
    }, []);

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
            fetchUsers(); // Refresh
        } catch (error) {
            console.error("Erreur update role:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const filteredUsers = users.filter(u =>
        u.phone?.includes(search) || u.name?.toLowerCase().includes(search.toLowerCase())
    );

    if (loading) return <div>Chargement...</div>;

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
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Wallet</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {filteredUsers.map((user) => (
                            <tr key={user.id}>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex items-center">
                                        <Link to={`/users/${user.id}`} className="flex items-center group cursor-pointer">
                                            <div className="flex-shrink-0 h-10 w-10 relative">
                                                {user.avatar_url ? (
                                                    <img
                                                        className="h-10 w-10 rounded-full object-cover"
                                                        src={user.avatar_url}
                                                        alt=""
                                                        onError={(e) => {
                                                            e.target.style.display = 'none';
                                                            e.target.nextSibling.style.display = 'flex';
                                                        }}
                                                    />
                                                ) : null}
                                                <div
                                                    className="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold"
                                                    style={{ display: user.avatar_url ? 'none' : 'flex', position: user.avatar_url ? 'absolute' : 'static', top: 0, left: 0 }}
                                                >
                                                    {user.name ? user.name.charAt(0).toUpperCase() : 'U'}
                                                </div>
                                            </div>
                                            <div className="ml-4">
                                                <div className="text-sm font-medium text-gray-900 group-hover:text-blue-600 transition-colors">
                                                    {user.name || 'Sans nom'}
                                                </div>
                                                <div className="text-sm text-gray-500">{user.phone}</div>
                                            </div>
                                        </Link>
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex space-x-2">
                                        {user.is_admin && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">Admin</span>}
                                        {user.is_seller && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">Vendeur</span>}
                                        {user.is_deliverer && <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">Livreur</span>}
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                    {user.wallet || '0.00'} $
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                    <button onClick={() => handlePromote(user.id, 'is_admin', user.is_admin)} className="text-indigo-600 hover:text-indigo-900 mr-4">
                                        {user.is_admin ? 'Retirer Admin' : 'Mettre Admin'}
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
