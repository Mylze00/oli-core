import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';

const VerificationBadge = ({ type }) => {
    const colors = {
        blue: '#1DA1F2',
        gold: '#D4A500',
        green: '#00BA7C',
        gray: '#71767B'
    };
    // Map account type string to color
    const getColor = () => {
        if (type === 'certified' || type === 'certifie') return colors.blue;
        if (type === 'enterprise' || type === 'entreprise') return colors.gold;
        if (type === 'premium') return colors.green;
        return colors.gray;
    };

    return (
        <span style={{ color: getColor() }} className="border px-2 py-1 rounded-full text-xs font-bold bg-white uppercase">
            {type}
        </span>
    );
};

export default function Verifications() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchVerifications();
    }, []);

    const fetchVerifications = async () => {
        try {
            const { data } = await api.get('/admin/verifications');
            setUsers(data);
        } catch (error) {
            console.error("Erreur verifications:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleRevoke = async (userId) => {
        if (!window.confirm("Voulez-vous vraiment révoquer cette certification ?")) return;
        try {
            await api.post(`/admin/verifications/${userId}/revoke`);
            fetchVerifications();
        } catch (error) {
            console.error("Erreur revocation:", error);
            alert("Erreur lors de la révocation");
        }
    };

    if (loading) return <div className="flex justify-center items-center h-64">Chargement...</div>;

    return (
        <div>
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Demandes de Certification</h1>
            </div>

            <div className="bg-white shadow overflow-hidden rounded-md">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Utilisateur</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Plan demandé</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Expiration</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {users.length === 0 && (
                            <tr>
                                <td colSpan="5" className="px-6 py-4 text-center text-gray-500">Aucune demande en cours</td>
                            </tr>
                        )}
                        {users.map((user) => (
                            <tr key={user.id} className="hover:bg-gray-50">
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex items-center">
                                        <div className="flex-shrink-0 h-10 w-10 relative">
                                            <img
                                                className="h-10 w-10 rounded-full object-cover"
                                                src={getImageUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'U'}&background=0B1727&color=fff`}
                                                alt=""
                                            />
                                        </div>
                                        <div className="ml-4">
                                            <div className="text-sm font-medium text-gray-900">{user.name}</div>
                                            <div className="text-sm text-gray-500">{user.phone}</div>
                                        </div>
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <VerificationBadge type={user.subscription_plan} />
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${user.subscription_status === 'active' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                                        }`}>
                                        {user.subscription_status}
                                    </span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                    {user.subscription_end_date ? new Date(user.subscription_end_date).toLocaleDateString() : '-'}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                    <button
                                        onClick={() => handleRevoke(user.id)}
                                        className="text-red-600 hover:text-red-900 text-xs font-bold border border-red-200 px-3 py-1 rounded bg-red-50"
                                    >
                                        RÉVOQUER
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
