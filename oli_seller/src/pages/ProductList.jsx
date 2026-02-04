import { useState, useEffect } from 'react';
import { Plus, Edit2, Eye, EyeOff, Search, Layers, Download, Upload } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { sellerAPI } from '../services/api';

export default function ProductList() {
    const navigate = useNavigate();
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        loadProducts();
    }, []);

    const loadProducts = async () => {
        try {
            setLoading(true);
            const filters = {};
            if (searchTerm) filters.search = searchTerm;

            const data = await sellerAPI.getProducts(filters);
            setProducts(data);
        } catch (err) {
            console.error('Error loading products:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleToggleStatus = async (product) => {
        try {
            await sellerAPI.toggleProduct(product.id);
            loadProducts(); // Reload to see change
        } catch (err) {
            console.error('Error toggling product:', err);
            alert('Erreur: Impossible de modifier le statut');
        }
    };

    const handleSearch = (e) => {
        e.preventDefault();
        loadProducts();
    };

    const getImageUrl = (images) => {
        if (!images || images.length === 0) return null;
        const firstImage = Array.isArray(images) ? images[0] : images;

        if (firstImage.startsWith('http')) return firstImage;

        const CLOUD_NAME = 'dbfpnxjmm';
        const cleanPath = firstImage.startsWith('/') ? firstImage.slice(1) : firstImage;

        if (cleanPath.startsWith('uploads/')) {
            const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';
            return `${API_URL}/${cleanPath}`;
        }

        return `https://res.cloudinary.com/${CLOUD_NAME}/image/upload/${cleanPath}`;
    };

    return (
        <div className="p-8">
            {/* Header */}
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Mes Produits</h1>
                    <p className="text-gray-500 mt-1">{products.length} produit(s)</p>
                </div>
                <div className="flex gap-3">
                    <button
                        onClick={() => navigate('/import-export')}
                        className="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-gray-200 transition-colors"
                    >
                        <Download size={18} /> Import/Export
                    </button>
                    <button
                        onClick={() => navigate('/products/new')}
                        className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 transition-colors"
                    >
                        <Plus size={20} /> Nouveau Produit
                    </button>
                </div>
            </div>

            {/* Simple Search */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
                <form onSubmit={handleSearch} className="flex-1">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
                        <input
                            type="text"
                            placeholder="Rechercher un produit..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
                        />
                    </div>
                </form>
            </div>

            {/* Products Table */}
            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
                </div>
            ) : products.length === 0 ? (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-12 text-center">
                    <div className="text-gray-400 mb-4">
                        <Plus size={64} className="mx-auto" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">Aucun produit</h3>
                    <p className="text-gray-500 mb-6">Commencez par ajouter votre premier produit</p>
                    <button
                        onClick={() => navigate('/products/new')}
                        className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
                    >
                        Ajouter un produit
                    </button>
                </div>
            ) : (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Produit
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Prix
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Stock
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Statut
                                </th>
                                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Actions
                                </th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                            {products.map((product) => (
                                <tr key={product.id} className="hover:bg-gray-50 transition-colors">
                                    <td className="px-6 py-4">
                                        <div className="flex items-center gap-3">
                                            {getImageUrl(product.images) ? (
                                                <img
                                                    src={getImageUrl(product.images)}
                                                    alt={product.name}
                                                    className="w-12 h-12 rounded-lg object-cover"
                                                    onError={(e) => e.target.src = 'https://via.placeholder.com/48'}
                                                />
                                            ) : (
                                                <div className="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center">
                                                    <Plus size={20} className="text-gray-400" />
                                                </div>
                                            )}
                                            <div>
                                                <p className="font-medium text-gray-900">{product.name}</p>
                                                <p className="text-sm text-gray-500">{product.category}</p>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4">
                                        <p className="font-semibold text-gray-900">${parseFloat(product.price).toFixed(2)}</p>
                                    </td>
                                    <td className="px-6 py-4">
                                        <p className="text-gray-700">{product.quantity || 0}</p>
                                    </td>
                                    <td className="px-6 py-4">
                                        <span
                                            className={`px-3 py-1 rounded-full text-xs font-semibold ${product.is_active
                                                ? 'bg-green-100 text-green-800'
                                                : 'bg-gray-100 text-gray-800'
                                                }`}
                                        >
                                            {product.is_active ? 'Actif' : 'Inactif'}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="flex items-center justify-end gap-2">
                                            <button
                                                onClick={() => handleToggleStatus(product)}
                                                className={`p-2 rounded-lg transition-colors flex items-center gap-1 ${product.is_active
                                                    ? 'text-gray-500 hover:bg-gray-100 hover:text-gray-700'
                                                    : 'text-orange-600 bg-orange-50 hover:bg-orange-100'}`}
                                                title={product.is_active ? "Cliquez pour masquer" : "Cliquez pour afficher"}
                                            >
                                                {product.is_active ? <Eye size={16} /> : <EyeOff size={16} />}
                                                <span className="text-sm hidden md:inline">{product.is_active ? 'Masquer' : 'Afficher'}</span>
                                            </button>

                                            <button
                                                onClick={() => navigate(`/products/${product.id}/variants`)}
                                                className="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors flex items-center gap-1"
                                                title="Gérer les variantes"
                                            >
                                                <Layers size={16} /> <span className="text-sm hidden md:inline">Variantes</span>
                                            </button>

                                            <button
                                                onClick={() => navigate(`/products/${product.id}/edit`)}
                                                className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors flex items-center gap-1"
                                                title="Modifier"
                                            >
                                                <Edit2 size={16} /> <span className="text-sm hidden md:inline">Modifier</span>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}
