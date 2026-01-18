import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { CheckBadgeIcon, XMarkIcon } from '@heroicons/react/24/solid';

export default function Shops() {
    const [shops, setShops] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all'); // all, verified, pending

    useEffect(() => {
        fetchShops();
    }, [filter]);

    const fetchShops = async () => {
        try {
            let url = '/admin/shops';
            if (filter === 'verified') url += '?verified=true';
            if (filter === 'pending') url += '?verified=false';
            const { data } = await api.get(url);
            setShops(data);
        } catch (error) {
            console.error("Erreur shops:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleCertify = async (shopId, currentValue) => {
        const newValue = !currentValue;
        if (!window.confirm(`${newValue ? 'Certifier' : 'Retirer la certification de'} cette boutique ?`)) return;
        try {
            await api.patch(`/admin/shops/${shopId}/certify`, { certified: newValue });
            fetchShops();
        } catch (error) {
            console.error("Erreur certification:", error);
            alert("Erreur lors de la mise à jour");
        }
    };

    const filteredShops = shops.filter(s =>
        s.name?.toLowerCase().includes(search.toLowerCase()) ||
        s.owner_phone?.includes(search)
    );

    if (loading) return <div className="flex justify-center items-center h-64">Chargement...</div>;

    return (
        <div>
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Boutiques & Marchands</h1>
                <div className="flex gap-4">
                    <select
                        className="border rounded px-3 py-2 bg-white"
                        value={filter}
                        onChange={(e) => setFilter(e.target.value)}
                    >
                        <option value="all">Toutes</option>
                        <option value="verified">Certifiées</option>
                        <option value="pending">En attente</option>
                    </select>
                    <input
                        type="text"
                        placeholder="Rechercher..."
                        className="border p-2 rounded"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
            </div>

            {/* Stats rapides */}
            <div className="grid grid-cols-3 gap-4 mb-6">
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <p className="text-gray-500 text-sm">Total Boutiques</p>
                    <p className="text-2xl font-bold">{shops.length}</p>
                </div>
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <p className="text-gray-500 text-sm">Certifiées</p>
                    <p className="text-2xl font-bold text-green-600">
                        {shops.filter(s => s.is_verified).length}
                    </p>
                </div>
                <div className="bg-white p-4 rounded-lg shadow-sm border">
                    <p className="text-gray-500 text-sm">En attente</p>
                    <p className="text-2xl font-bold text-orange-600">
                        {shops.filter(s => !s.is_verified).length}
                    </p>
                </div>
            </div>

            {/* Liste des boutiques */}
            <div className="bg-white shadow overflow-hidden rounded-md">
                <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Boutique</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Propriétaire</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Produits</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Statut</th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {filteredShops.length === 0 ? (
                            <tr>
                                <td colSpan="5" className="px-6 py-8 text-center text-gray-500">
                                    Aucune boutique trouvée
                                </td>
                            </tr>
                        ) : (
                            filteredShops.map((shop) => (
                                <tr key={shop.id} className="hover:bg-gray-50">
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <div className="flex items-center">
                                            <div className="flex-shrink-0 h-10 w-10 bg-blue-100 rounded-full flex items-center justify-center">
                                                <span className="text-blue-600 font-bold">
                                                    {shop.name?.charAt(0)?.toUpperCase() || 'S'}
                                                </span>
                                            </div>
                                            <div className="ml-4">
                                                <div className="text-sm font-medium text-gray-900">{shop.name || 'Sans nom'}</div>
                                                <div className="text-xs text-gray-500">ID: {shop.id}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <Link to={`/users/${shop.owner_id}`} className="text-blue-600 hover:underline">
                                            <div className="text-sm">{shop.owner_name || 'Inconnu'}</div>
                                            <div className="text-xs text-gray-500">{shop.owner_phone}</div>
                                        </Link>
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                        {shop.products_count || 0} produits
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        {shop.is_verified ? (
                                            <span className="px-2 py-1 inline-flex items-center text-xs font-semibold rounded-full bg-green-100 text-green-800">
                                                <CheckBadgeIcon className="h-4 w-4 mr-1" />
                                                Certifié
                                            </span>
                                        ) : (
                                            <span className="px-2 py-1 inline-flex items-center text-xs font-semibold rounded-full bg-gray-100 text-gray-600">
                                                En attente
                                            </span>
                                        )}
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                        <button
                                            onClick={() => handleCertify(shop.id, shop.is_verified)}
                                            className={`px-3 py-1 rounded text-white transition ${shop.is_verified
                                                    ? 'bg-red-500 hover:bg-red-600'
                                                    : 'bg-green-500 hover:bg-green-600'
                                                }`}
                                        >
                                            {shop.is_verified ? 'Retirer' : 'Certifier'}
                                        </button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
