import { useState, useEffect } from 'react';
import { Plus, Edit2, Eye, EyeOff, Search, Layers, Download, Settings, FileText, Trash2, CheckSquare, PenLine, X } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { sellerAPI, shopAPI, productAPI } from '../services/api';

export default function ProductList() {
    const navigate = useNavigate();
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [activeTab, setActiveTab] = useState('all');
    const [activatingAll, setActivatingAll] = useState(false);
    const [selectedIds, setSelectedIds] = useState(new Set());
    const [deleting, setDeleting] = useState(false);
    const [currentPage, setCurrentPage] = useState(1);
    const [hasMore, setHasMore] = useState(false);
    const [totalCount, setTotalCount] = useState(0);
    // Bulk edit modal
    const [bulkEditOpen, setBulkEditOpen] = useState(false);
    const [bulkField, setBulkField] = useState('price');
    const [bulkValue, setBulkValue] = useState('');
    const [bulkApplying, setBulkApplying] = useState(false);

    const PAGE_SIZE = 200;

    useEffect(() => {
        loadProducts(1);
    }, []);

    const loadProducts = async (page = currentPage) => {
        try {
            setLoading(true);
            const offset = (page - 1) * PAGE_SIZE;
            const filters = { limit: PAGE_SIZE, offset };
            if (searchTerm) filters.search = searchTerm;

            const data = await sellerAPI.getProducts(filters);
            setProducts(data);
            setCurrentPage(page);
            setSelectedIds(new Set());
            setHasMore(data.length === PAGE_SIZE);
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

    const handleBulkDelete = async () => {
        if (selectedIds.size === 0) return;
        const ok = window.confirm(
            `⚠️ Supprimer les ${selectedIds.size} produit(s) sélectionné(s) ? Cette action est irréversible.`
        );
        if (!ok) return;
        setDeleting(true);
        try {
            for (const id of selectedIds) {
                await productAPI.delete(id);
            }
            setSelectedIds(new Set());
            await loadProducts();
        } catch (err) {
            alert('Erreur lors de la suppression: ' + (err.response?.data?.error || err.message));
        } finally {
            setDeleting(false);
        }
    };

    const handleBulkEdit = async () => {
        if (!bulkValue.trim() || selectedIds.size === 0) return;
        setBulkApplying(true);
        try {
            for (const id of selectedIds) {
                const payload = {};
                if (bulkField === 'price') {
                    payload.price = parseFloat(bulkValue);
                } else if (bulkField === 'price_divide') {
                    const divisor = parseFloat(bulkValue);
                    if (!divisor || divisor <= 0) throw new Error('Diviseur invalide');
                    const product = products.find(p => p.id === id);
                    const currentPrice = parseFloat(product?.price || 0);
                    payload.price = Math.round((currentPrice / divisor) * 100) / 100;
                } else if (bulkField === 'quantity') {
                    payload.quantity = parseInt(bulkValue);
                } else if (bulkField === 'category') {
                    payload.category = bulkValue.trim();
                } else if (bulkField === 'status') {
                    payload.status = bulkValue;
                    payload.is_active = bulkValue === 'active';
                }
                await productAPI.update(id, payload);
            }
            setBulkEditOpen(false);
            setBulkValue('');
            setSelectedIds(new Set());
            await loadProducts();
        } catch (err) {
            alert('Erreur: ' + (err.response?.data?.error || err.message));
        } finally {
            setBulkApplying(false);
        }
    };

    const toggleSelect = (id) => {
        setSelectedIds(prev => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id); else next.add(id);
            return next;
        });
    };

    const toggleSelectAll = () => {
        if (selectedIds.size === filteredProducts.length) {
            setSelectedIds(new Set());
        } else {
            setSelectedIds(new Set(filteredProducts.map(p => p.id)));
        }
    };

    const handleSearch = (e) => {
        e.preventDefault();
        loadProducts(1); // reset to page 1 on new search
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
        { id: 'all', label: 'Tous', count: products.length + (hasMore ? '+' : '') },
        { id: 'active', label: 'Actifs', count: activeCount, color: 'green' },
        { id: 'draft', label: 'Brouillons', count: draftCount, color: 'amber' },
    ];

    // Reset to page 1 when tab changes
    const handleTabChange = (tabId) => {
        setActiveTab(tabId);
        setSelectedIds(new Set());
    };

    return (
        <div className="p-8">
            {/* Floating bulk action bar */}
            {selectedIds.size > 0 && (
                <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 bg-gray-900 text-white px-5 py-3 rounded-2xl shadow-2xl border border-gray-700">
                    <CheckSquare size={18} className="text-blue-400 shrink-0" />
                    <span className="font-medium text-sm whitespace-nowrap">{selectedIds.size} sélectionné(s)</span>
                    <button
                        onClick={() => setSelectedIds(new Set())}
                        className="text-xs text-gray-400 hover:text-white transition-colors whitespace-nowrap"
                    >
                        Tout déselect.
                    </button>
                    <div className="w-px h-5 bg-gray-600" />
                    <button
                        onClick={() => { setBulkEditOpen(true); setBulkValue(''); }}
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-lg transition-colors"
                    >
                        <PenLine size={14} /> Modifier en masse
                    </button>
                    <button
                        onClick={handleBulkDelete}
                        disabled={deleting}
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-red-500 hover:bg-red-600 text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-50"
                    >
                        {deleting ? <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" /><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" /></svg> : <Trash2 size={14} />}
                        {deleting ? 'Suppression...' : `Supprimer (${selectedIds.size})`}
                    </button>
                </div>
            )}

            {/* Bulk Edit Modal */}
            {bulkEditOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
                    <div className="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md mx-4">
                        <div className="flex items-center justify-between mb-5">
                            <h2 className="text-lg font-bold text-gray-900">Modifier {selectedIds.size} produit(s)</h2>
                            <button onClick={() => setBulkEditOpen(false)} className="text-gray-400 hover:text-gray-600">
                                <X size={20} />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Champ à modifier</label>
                                <select
                                    value={bulkField}
                                    onChange={e => { setBulkField(e.target.value); setBulkValue(''); }}
                                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
                                >
                                    <option value="price">💰 Prix — définir un prix fixe (USD)</option>
                                    <option value="price_divide">➗ Prix — diviser par un diviseur (CDF→USD)</option>
                                    <option value="quantity">📦 Stock / Quantité</option>
                                    <option value="category">🏷️ Catégorie</option>
                                    <option value="status">🔄 Statut</option>
                                </select>
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Nouvelle valeur</label>
                                {bulkField === 'status' ? (
                                    <select
                                        value={bulkValue}
                                        onChange={e => setBulkValue(e.target.value)}
                                        className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
                                    >
                                        <option value="">-- Choisir --</option>
                                        <option value="active">Actif (visible)</option>
                                        <option value="inactive">Inactif (masqué)</option>
                                        <option value="draft">Brouillon</option>
                                    </select>
                                ) : (
                                    <>
                                        <input
                                            type="number"
                                            value={bulkValue}
                                            onChange={e => setBulkValue(e.target.value)}
                                            placeholder={bulkField === 'price_divide' ? 'ex: 2300' : bulkField === 'price' ? 'ex: 29.99' : bulkField === 'quantity' ? 'ex: 100' : 'ex: Chaussures'}
                                            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
                                            min="0"
                                            step={bulkField === 'price' ? '0.01' : '1'}
                                            defaultValue={bulkField === 'price_divide' ? '2300' : ''}
                                        />
                                        {bulkField === 'price_divide' && (
                                            <p className="text-xs text-blue-600 mt-1">
                                                → Nouveau prix = prix actuel ÷ {bulkValue || '2300'} (conversion CDF → USD)
                                            </p>
                                        )}
                                    </>
                                )}
                            </div>
                            <p className="text-xs text-gray-500 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
                                ⚠️ Cette action va modifier le champ <strong>{bulkField === 'price' ? 'prix' : bulkField === 'quantity' ? 'stock' : bulkField === 'category' ? 'catégorie' : 'statut'}</strong> des <strong>{selectedIds.size} produits sélectionnés</strong>.
                            </p>
                        </div>
                        <div className="flex gap-3 mt-6">
                            <button
                                onClick={() => setBulkEditOpen(false)}
                                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={handleBulkEdit}
                                disabled={bulkApplying || !bulkValue.trim()}
                                className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-semibold transition-colors disabled:opacity-50"
                            >
                                {bulkApplying ? 'Application...' : `Appliquer aux ${selectedIds.size} produits`}
                            </button>
                        </div>
                    </div>
                </div>
            )}
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
                        onClick={() => handleTabChange(tab.id)}
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
                                {/* Checkbox select-all */}
                                <th className="px-4 py-3 w-10">
                                    <input
                                        type="checkbox"
                                        className="w-4 h-4 rounded accent-blue-600 cursor-pointer"
                                        checked={filteredProducts.length > 0 && selectedIds.size === filteredProducts.length}
                                        onChange={toggleSelectAll}
                                        title="Tout sélectionner"
                                    />
                                </th>
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
                                    className={`hover:bg-gray-50 transition-colors ${isDraft(product) ? 'bg-amber-50/40' : ''
                                        } ${selectedIds.has(product.id) ? 'bg-blue-50/60' : ''}`}
                                >
                                    {/* Checkbox — clic sur toute la cellule */}
                                    <td
                                        className="px-4 py-4 cursor-pointer"
                                        onClick={() => toggleSelect(product.id)}
                                    >
                                        <input
                                            type="checkbox"
                                            className="w-4 h-4 rounded accent-blue-600 cursor-pointer"
                                            checked={selectedIds.has(product.id)}
                                            onChange={() => toggleSelect(product.id)}
                                            onClick={e => e.stopPropagation()}
                                        />
                                    </td>
                                    {/* Produit (nom+image) — clic navigue vers l'éditeur */}
                                    <td
                                        className="px-6 py-4 cursor-pointer"
                                        onClick={() => navigate(`/products/${product.id}/edit`)}
                                    >
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

            {/* Pagination — affiché en dehors du bloc conditionnel table */}
            {(currentPage > 1 || hasMore) && (
                <div className="mt-4 flex items-center justify-between px-2">
                    <p className="text-sm text-gray-500">
                        Page <strong>{currentPage}</strong> — {filteredProducts.length} produits affichés
                        {hasMore && <span className="text-blue-600 ml-1">(+200 disponibles)</span>}
                    </p>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => loadProducts(currentPage - 1)}
                            disabled={currentPage === 1 || loading}
                            className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors font-medium"
                        >
                            ← Précédent
                        </button>
                        <span className="px-3 py-2 text-sm bg-blue-600 text-white rounded-lg font-bold min-w-[2.5rem] text-center">
                            {currentPage}
                        </span>
                        <button
                            onClick={() => loadProducts(currentPage + 1)}
                            disabled={!hasMore || loading}
                            className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors font-medium"
                        >
                            Suivant →
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
