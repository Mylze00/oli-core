import { useState, useEffect } from 'react';
import { Plus, Edit2, Eye, EyeOff, Search, Layers, Download, Settings, FileText } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { sellerAPI, shopAPI } from '../services/api';

export default function ProductList() {
    const navigate = useNavigate();
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [activeTab, setActiveTab] = useState('all'); // 'all' | 'active' | 'draft'
    const [activatingAll, setActivatingAll] = useState(false);

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
            loadProducts();
        } catch (err) {
            console.error('Error toggling product:', err);
            alert('Erreur: Impossible de modifier le statut');
        }
    };

    const handleActivateAllDrafts = async () => {
        const drafts = products.filter(p => p.status === 'draft' || (!p.is_active && p.status !== 'active'));
        if (drafts.length === 0) return;

        const ok = window.confirm(`Activer les ${drafts.length} brouillon(s) ? Ils seront visibles sur la marketplace.`);
        if (!ok) return;

        setActivatingAll(true);
        try {
            for (const p of drafts) {
                await sellerAPI.toggleProduct(p.id);
            }
            await loadProducts();
        } catch (err) {
            alert('Erreur lors de l\'activation: ' + err.message);
        } finally {
            setActivatingAll(false);
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

    const isDraft = (product) =>
        product.status === 'draft' || (product.status !== 'active' && !product.is_active);

    const filteredProducts = products.filter(p => {
        if (activeTab === 'active') return p.status === 'active' && p.is_active;
        if (activeTab === 'draft') return isDraft(p);
        return true;
    });

    const draftCount = products.filter(p => isDraft(p)).length;
    const activeCount = products.filter(p => p.status === 'active' && p.is_active).length;

    const tabs = [
        { id: 'all', label: 'Tous', count: products.length },
        { id: 'active', label: 'Actifs', count: activeCount, color: 'green' },
        { id: 'draft', label: 'Brouillons', count: draftCount, color: 'amber' },
    ];

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
                        onClick={async () => {
                            if (products.length === 0) return alert("Aucun produit à mettre à jour");
                            console.log("Premier produit:", products[0]);
                            let shopId = products[0].shopId || products[0].shop_id;
                            if (!shopId) {
                                try {
                                    const myShops = await shopAPI.getMyShops();
                                    if (myShops && myShops.length > 0) shopId = myShops[0].id;
                                } catch (e) {
                                    console.error("Erreur fetch shops:", e);
                                }
                            }
                            if (!shopId) return alert("Impossible de déterminer la boutique. Vérifiez que vous avez une boutique active.");
                            const confirm = window.confirm(
                                "⚠️ ATTENTION : Cette action va diviser le prix de TOUS vos produits.\n\n" +
                                "Utilisez cette option si vous avez importé des prix en Francs Congolais (CDF) et voulez les convertir en USD.\n\n" +
                                "Voulez-vous continuer ?"
                            );
                            if (confirm) {
                                const divisorStr = window.prompt("Entrez le diviseur (ex: 2700 pour CDF → USD):", "2700");
                                const divisor = parseFloat(divisorStr);
                                if (divisor && !isNaN(divisor)) {
                                    try {
                                        setLoading(true);
                                        const res = await sellerAPI.bulkUpdatePrice(shopId, divisor);
                                        alert(`Succès! ${res.message}`);
                                        loadProducts();
                                    } catch (err) {
                                        console.error(err);
                                        alert("Erreur lors de la mise à jour: " + (err.response?.data?.error || err.message));
                                        setLoading(false);
                                    }
                                }
                            }
                        }}
                        className="bg-orange-100 text-orange-700 px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-orange-200 transition-colors"
                        title="Correction prix en masse"
                    >
                        <Settings size={18} /> Correction Prix
                    </button>
                    <button
                        onClick={() => navigate('/products/new')}
                        className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 transition-colors"
                    >
                        <Plus size={20} /> Nouveau Produit
                    </button>
                </div>
            </div>

            {/* Tabs */}
            <div className="flex items-center gap-1 mb-4 border-b border-gray-200">
                {tabs.map(tab => (
                    <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`px-4 py-2.5 text-sm font-medium flex items-center gap-2 border-b-2 transition-colors -mb-px ${activeTab === tab.id
                            ? 'border-blue-600 text-blue-600'
                            : 'border-transparent text-gray-500 hover:text-gray-700'
                            }`}
                    >
                        {tab.label}
                        <span className={`text-xs px-1.5 py-0.5 rounded-full font-semibold ${activeTab === tab.id
                            ? tab.id === 'draft' ? 'bg-amber-100 text-amber-700'
                                : tab.id === 'active' ? 'bg-green-100 text-green-700'
                                    : 'bg-blue-100 text-blue-700'
                            : 'bg-gray-100 text-gray-500'
                            }`}>
                            {tab.count}
                        </span>
                    </button>
                ))}

                {/* Activate All Drafts button — only visible on draft tab */}
                {activeTab === 'draft' && draftCount > 0 && (
                    <button
                        onClick={handleActivateAllDrafts}
                        disabled={activatingAll}
                        className="ml-auto mb-1 px-4 py-1.5 bg-amber-500 text-white text-sm font-medium rounded-lg hover:bg-amber-600 disabled:opacity-50 flex items-center gap-2 transition-colors"
                    >
                        {activatingAll ? (
                            <span className="flex items-center gap-2">
                                <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
                                </svg>
                                Activation...
                            </span>
                        ) : (
                            <>✅ Tout activer ({draftCount})</>
                        )}
                    </button>
                )}
            </div>

            {/* Search */}
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
            ) : filteredProducts.length === 0 ? (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-12 text-center">
                    <div className="text-gray-400 mb-4">
                        {activeTab === 'draft' ? (
                            <FileText size={64} className="mx-auto" />
                        ) : (
                            <Plus size={64} className="mx-auto" />
                        )}
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">
                        {activeTab === 'draft' ? 'Aucun brouillon' : 'Aucun produit'}
                    </h3>
                    <p className="text-gray-500 mb-6">
                        {activeTab === 'draft'
                            ? 'Les produits importés par CSV apparaîtront ici.'
                            : 'Commencez par ajouter votre premier produit'}
                    </p>
                    {activeTab !== 'draft' && (
                        <button
                            onClick={() => navigate('/products/new')}
                            className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
                        >
                            Ajouter un produit
                        </button>
                    )}
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
                            {filteredProducts.map((product) => (
                                <tr
                                    key={product.id}
                                    className={`hover:bg-gray-50 transition-colors cursor-pointer ${isDraft(product) ? 'bg-amber-50/40' : ''}`}
                                    onClick={() => navigate(`/products/${product.id}/edit`)}
                                >
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
                                        {isDraft(product) ? (
                                            <span className="px-3 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-800">
                                                📝 Brouillon
                                            </span>
                                        ) : product.status === 'active' ? (
                                            <span className="px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                                                Actif
                                            </span>
                                        ) : (
                                            <span className="px-3 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-800">
                                                Inactif
                                            </span>
                                        )}
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="flex items-center justify-end gap-2" onClick={(e) => e.stopPropagation()}>
                                            <button
                                                onClick={() => handleToggleStatus(product)}
                                                className={`p-2 rounded-lg transition-colors flex items-center gap-1 ${isDraft(product)
                                                    ? 'text-amber-600 bg-amber-50 hover:bg-amber-100 font-medium'
                                                    : product.status === 'active'
                                                        ? 'text-gray-500 hover:bg-gray-100 hover:text-gray-700'
                                                        : 'text-orange-600 bg-orange-50 hover:bg-orange-100'
                                                    }`}
                                                title={isDraft(product) ? "Activer le produit" : product.status === 'active' ? "Cliquez pour masquer" : "Cliquez pour afficher"}
                                            >
                                                {isDraft(product) ? (
                                                    <>✅ <span className="text-sm hidden md:inline">Activer</span></>
                                                ) : product.status === 'active' ? (
                                                    <><Eye size={16} /><span className="text-sm hidden md:inline">Masquer</span></>
                                                ) : (
                                                    <><EyeOff size={16} /><span className="text-sm hidden md:inline">Afficher</span></>
                                                )}
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
                                                <Edit2 size={16} /> <span className="text-sm hidden md:inline">{isDraft(product) ? 'Compléter' : 'Modifier'}</span>
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
