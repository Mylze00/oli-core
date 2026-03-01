import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import { StarIcon as StarOutline, TrashIcon, XMarkIcon, EyeSlashIcon } from '@heroicons/react/24/outline';
import { StarIcon, CubeIcon, CheckCircleIcon, NoSymbolIcon, FireIcon, MagnifyingGlassIcon, TagIcon, EyeIcon, ChevronRightIcon, CheckBadgeIcon as CheckBadgeSolid } from '@heroicons/react/24/solid';

function StatCard({ label, value, icon: Icon, color }) {
    const c = { blue: 'bg-blue-50 text-blue-600', green: 'bg-green-50 text-green-600', red: 'bg-red-50 text-red-600', amber: 'bg-amber-50 text-amber-600', rose: 'bg-rose-50 text-rose-600' };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-3 mb-2">
                <div className={`p-2 rounded-lg ${c[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
        </div>
    );
}

function FilterPill({ label, count, active, onClick }) {
    return (
        <button onClick={onClick}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2 ${active ? 'bg-blue-600 text-white shadow-sm' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
        >
            {label}
            {count !== undefined && (
                <span className={`text-xs px-1.5 py-0.5 rounded-full ${active ? 'bg-white/20' : 'bg-gray-200 text-gray-500'}`}>{count}</span>
            )}
        </button>
    );
}

/* ═══════════════════════════════════
   PRODUCT DETAIL MODAL
   ═══════════════════════════════════ */
function ProductModal({ product, onClose, getDisplayImage, onToggleFeatured, onToggleGoodDeal, onDelete, onHide, onToggleVerify }) {
    if (!product) return null;

    const allImages = [];
    if (product.image_url) allImages.push(product.image_url);
    if (product.images) {
        const imgs = Array.isArray(product.images) ? product.images : product.images.replace(/[{}"]/g, '').split(',');
        imgs.forEach(img => {
            if (img) {
                const url = getImageUrl(img);
                if (url && !allImages.includes(url)) allImages.push(url);
            }
        });
    }
    if (allImages.length === 0) allImages.push('https://via.placeholder.com/400?text=No+image');

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl" onClick={e => e.stopPropagation()}>
                {/* Header */}
                <div className="flex items-center justify-between p-5 border-b border-gray-100">
                    <h2 className="text-lg font-bold text-gray-900">Détails du produit</h2>
                    <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition">
                        <XMarkIcon className="h-5 w-5 text-gray-400" />
                    </button>
                </div>

                {/* Images */}
                <div className="p-5 border-b border-gray-100">
                    <div className="flex gap-3 overflow-x-auto pb-2">
                        {allImages.map((img, i) => (
                            <img key={i} src={img} alt="" className="h-48 w-48 object-cover rounded-xl flex-shrink-0 border border-gray-100 bg-gray-50"
                                onError={(e) => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/200?text=No+img'; }} />
                        ))}
                    </div>
                </div>

                {/* Info */}
                <div className="p-5 space-y-4">
                    <div>
                        <h3 className="text-xl font-bold text-gray-900">{product.name}</h3>
                        <div className="flex items-center gap-3 mt-2">
                            {product.category && (
                                <span className="text-xs bg-gray-100 text-gray-600 px-3 py-1 rounded-full flex items-center">
                                    <TagIcon className="h-3 w-3 mr-1" />{product.category}
                                </span>
                            )}
                            {product.status === 'active' ? (
                                <span className="text-xs bg-green-100 text-green-700 px-3 py-1 rounded-full font-semibold">Actif</span>
                            ) : product.status === 'hidden' ? (
                                <span className="text-xs bg-purple-100 text-purple-700 px-3 py-1 rounded-full font-semibold">Masqué</span>
                            ) : (
                                <span className="text-xs bg-red-100 text-red-700 px-3 py-1 rounded-full font-semibold">{product.status}</span>
                            )}
                            {product.is_featured && <span className="text-xs bg-amber-100 text-amber-700 px-3 py-1 rounded-full font-semibold flex items-center"><StarIcon className="h-3 w-3 mr-1" />Vedette</span>}
                            {product.is_good_deal && <span className="text-xs bg-rose-100 text-rose-700 px-3 py-1 rounded-full font-semibold flex items-center"><FireIcon className="h-3 w-3 mr-1" />Bon Deal</span>}
                            {product.is_verified && <span className="text-xs bg-blue-100 text-blue-700 px-3 py-1 rounded-full font-semibold flex items-center"><CheckBadgeSolid className="h-3 w-3 mr-1" />Vérifié</span>}
                        </div>
                    </div>

                    {/* Prix */}
                    <div className="bg-gray-50 rounded-xl p-4">
                        <div className="flex items-baseline gap-3">
                            <span className="text-2xl font-bold text-gray-900">{product.price} $</span>
                            {product.is_good_deal && product.promo_price && (
                                <span className="text-lg font-bold text-rose-500">{product.promo_price} $ promo</span>
                            )}
                        </div>
                        {product.view_count !== undefined && (
                            <p className="text-xs text-gray-400 mt-1 flex items-center"><EyeIcon className="h-3 w-3 mr-1" />{product.view_count || 0} vues</p>
                        )}
                    </div>

                    {/* Description */}
                    {product.description && (
                        <div>
                            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Description</p>
                            <p className="text-sm text-gray-600 leading-relaxed">{product.description}</p>
                        </div>
                    )}

                    {/* Vendeur */}
                    <div className="bg-gray-50 rounded-xl p-4">
                        <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Vendeur</p>
                        <Link to={`/users/${product.seller_id}`} onClick={onClose} className="flex items-center gap-3 hover:opacity-80 transition">
                            <img
                                src={getImageUrl(product.seller_avatar) || `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&background=0B1727&color=fff&size=64`}
                                className="w-12 h-12 rounded-full object-cover border-2 border-white shadow-sm"
                                alt=""
                                onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&background=0B1727&color=fff`; }}
                            />
                            <div>
                                <p className="font-semibold text-blue-600">{product.seller_name || 'Vendeur'}</p>
                                <p className="text-sm text-gray-400">{product.seller_phone}</p>
                            </div>
                            <ChevronRightIcon className="h-5 w-5 text-gray-300 ml-auto" />
                        </Link>
                    </div>

                    {/* Date */}
                    <p className="text-xs text-gray-400 text-center">
                        Créé le {product.created_at ? new Date(product.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' }) : '—'}
                        {product.updated_at && ` • Modifié le ${new Date(product.updated_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' })}`}
                    </p>

                    {/* Actions */}
                    <div className="flex gap-2 pt-2 flex-wrap">
                        <button onClick={() => { onToggleFeatured(product); }}
                            className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition flex items-center justify-center gap-2 ${product.is_featured ? 'bg-amber-100 text-amber-700 hover:bg-amber-200' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                        >
                            {product.is_featured ? <StarIcon className="h-4 w-4" /> : <StarOutline className="h-4 w-4" />}
                            {product.is_featured ? 'Retirer vedette' : 'Mettre en avant'}
                        </button>
                        <button onClick={() => { onToggleGoodDeal(product); }}
                            className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition flex items-center justify-center gap-2 ${product.is_good_deal ? 'bg-rose-100 text-rose-700 hover:bg-rose-200' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                        >
                            <FireIcon className="h-4 w-4" />
                            {product.is_good_deal ? 'Retirer deal' : 'Bon Deal'}
                        </button>
                        <button onClick={() => { onHide(product); }}
                            className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition flex items-center justify-center gap-2 ${product.status === 'hidden' ? 'bg-purple-100 text-purple-700 hover:bg-purple-200' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                        >
                            <EyeSlashIcon className="h-4 w-4" />
                            {product.status === 'hidden' ? 'Afficher' : 'Masquer'}
                        </button>
                        <button onClick={() => { onToggleVerify(product); }}
                            className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition flex items-center justify-center gap-2 ${product.is_verified ? 'bg-blue-100 text-blue-700 hover:bg-blue-200' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                        >
                            <CheckBadgeSolid className="h-4 w-4" />
                            {product.is_verified ? '✓ Vérifié' : 'Vérifier'}
                        </button>
                        <button onClick={() => { onDelete(product.id); onClose(); }}
                            className="py-2.5 px-4 rounded-xl text-sm font-medium bg-red-50 text-red-600 hover:bg-red-100 transition flex items-center gap-2"
                        >
                            <TrashIcon className="h-4 w-4" />Bannir
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}

/* ═══════════════════════════════════
   MAIN: PRODUCTS PAGE
   ═══════════════════════════════════ */
export default function Products() {
    const [products, setProducts] = useState([]);
    const [stats, setStats] = useState({ total: 0, active: 0, banned: 0, hidden: 0, featured: 0, good_deals: 0 });
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');
    const [selectedProduct, setSelectedProduct] = useState(null);
    const [page, setPage] = useState(1);
    const PAGE_SIZE = 50;

    useEffect(() => { setPage(1); fetchProducts(); }, [filter]);

    const fetchProducts = async () => {
        try {
            setLoading(true);
            // Pas de limit : on charge tout (le backend peut paginer, on demande 9999)
            let url = '/admin/products?limit=9999';
            if (filter === 'active') url += '&status=active';
            if (filter === 'banned') url += '&status=banned';
            if (filter === 'hidden') url += '&status=hidden';
            if (filter === 'featured') url += '&is_featured=true';
            const { data } = await api.get(url);
            const list = Array.isArray(data) ? data : (data.products || []);
            setProducts(list);
            // Si l'API fournit des stats, on les utilise, sinon on les calcule
            if (!Array.isArray(data) && data.stats) {
                setStats(data.stats);
            } else {
                setStats({
                    total: list.length,
                    active: list.filter(p => p.status === 'active').length,
                    banned: list.filter(p => p.status === 'banned').length,
                    hidden: list.filter(p => p.status === 'hidden').length,
                    featured: list.filter(p => p.is_featured).length,
                    good_deals: list.filter(p => p.is_good_deal).length,
                });
            }
        } catch (error) { console.error("Erreur products:", error); }
        finally { setLoading(false); }
    };

    const toggleFeatured = async (product) => {
        try {
            await api.patch(`/admin/products/${product.id}/feature`, { is_featured: !product.is_featured });
            const updated = products.map(p => p.id === product.id ? { ...p, is_featured: !p.is_featured } : p);
            setProducts(updated);
            if (selectedProduct?.id === product.id) setSelectedProduct({ ...product, is_featured: !product.is_featured });
        } catch (error) { console.error("Erreur:", error); alert("Erreur"); }
    };

    const handleDelete = async (productId) => {
        if (!window.confirm("Bannir ce produit ? Il ne sera plus visible.")) return;
        try {
            await api.delete(`/admin/products/${productId}`);
            setProducts(products.filter(p => p.id !== productId));
        } catch (error) { console.error("Erreur:", error); alert("Erreur"); }
    };

    const toggleGoodDeal = async (product) => {
        const newVal = !product.is_good_deal;
        const newPrice = newVal ? prompt("Prix promo ?", product.promo_price || product.price) : null;
        if (newVal && !newPrice) return;
        try {
            await api.patch(`/admin/products/${product.id}/good-deal`, { is_good_deal: newVal, promo_price: newVal ? newPrice : null });
            const updated = products.map(p => p.id === product.id ? { ...p, is_good_deal: newVal, promo_price: newVal ? newPrice : null } : p);
            setProducts(updated);
            if (selectedProduct?.id === product.id) setSelectedProduct({ ...product, is_good_deal: newVal, promo_price: newVal ? newPrice : null });
        } catch (err) { alert('Erreur'); }
    };

    const toggleVerify = async (product) => {
        try {
            const { data } = await api.patch(`/admin/products/${product.id}/verify`);
            const newVal = data.product.is_verified;
            const updated = products.map(p => p.id === product.id ? { ...p, is_verified: newVal } : p);
            setProducts(updated);
            if (selectedProduct?.id === product.id) setSelectedProduct({ ...product, is_verified: newVal });
        } catch (err) { alert('Erreur vérification'); }
    };

    const handleHide = async (product) => {
        try {
            const { data } = await api.patch(`/admin/products/${product.id}/toggle-visibility`);
            const newStatus = product.status === 'hidden' ? 'active' : 'hidden';
            const updated = products.map(p => p.id === product.id ? { ...p, status: newStatus } : p);
            setProducts(updated);
            if (selectedProduct?.id === product.id) setSelectedProduct({ ...product, status: newStatus });
        } catch (error) { console.error("Erreur:", error); alert("Erreur"); }
    };

    const getDisplayImage = (product) => {
        if (product.image_url) return product.image_url;
        if (product.images) {
            if (Array.isArray(product.images) && product.images.length > 0) return getImageUrl(product.images[0]);
            if (typeof product.images === 'string') {
                const clean = product.images.replace(/[{}"]/g, '').split(',')[0];
                if (clean) return getImageUrl(clean);
            }
        }
        return 'https://via.placeholder.com/80?text=No+img';
    };

    const filteredProducts = useMemo(() => {
        const result = products.filter(p => !search ||
            p.name?.toLowerCase().includes(search.toLowerCase()) ||
            p.seller_name?.toLowerCase().includes(search.toLowerCase()) ||
            p.seller_phone?.includes(search) ||
            p.category?.toLowerCase().includes(search.toLowerCase())
        );
        return result;
    }, [products, search]);

    // Pagination
    const totalPages = Math.max(1, Math.ceil(filteredProducts.length / PAGE_SIZE));
    const safePage = Math.min(page, totalPages);
    const paginatedProducts = filteredProducts.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);

    if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Modal */}
            {selectedProduct && (
                <ProductModal
                    product={selectedProduct}
                    onClose={() => setSelectedProduct(null)}
                    getDisplayImage={getDisplayImage}
                    onToggleFeatured={toggleFeatured}
                    onToggleGoodDeal={toggleGoodDeal}
                    onToggleVerify={toggleVerify}
                    onDelete={handleDelete}
                    onHide={handleHide}
                />
            )}

            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Produits</h1>
                    <p className="text-sm text-gray-400 mt-1">Gestion, modération et mise en avant des produits</p>
                </div>
                <div className="relative">
                    <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input type="text" placeholder="Rechercher produit, vendeur, catégorie..."
                        className="pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm w-80 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                <StatCard label="Total" value={stats.total} icon={CubeIcon} color="blue" />
                <StatCard label="Actifs" value={stats.active} icon={CheckCircleIcon} color="green" />
                <StatCard label="Bannis" value={stats.banned} icon={NoSymbolIcon} color="red" />
                <StatCard label="En avant" value={stats.featured} icon={StarIcon} color="amber" />
                <StatCard label="Bons Deals" value={stats.good_deals} icon={FireIcon} color="rose" />
            </div>

            {/* Filters */}
            <div className="flex gap-2 flex-wrap">
                <FilterPill label="Tous" count={stats.total} active={filter === 'all'} onClick={() => setFilter('all')} />
                <FilterPill label="✓ Actifs" count={stats.active} active={filter === 'active'} onClick={() => setFilter('active')} />
                <FilterPill label="👁 Masqués" count={stats.hidden} active={filter === 'hidden'} onClick={() => setFilter('hidden')} />
                <FilterPill label="⛔ Bannis" count={stats.banned} active={filter === 'banned'} onClick={() => setFilter('banned')} />
                <FilterPill label="⭐ En avant" count={stats.featured} active={filter === 'featured'} onClick={() => setFilter('featured')} />
                <FilterPill label="✅ Vérifiés" active={filter === 'verified'} onClick={() => setFilter('verified')} />
            </div>

            {/* Products Table */}
            {filteredProducts.length === 0 ? (
                <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
                    <CubeIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                    <p className="text-gray-500 font-medium">Aucun produit trouvé</p>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    {/* Table Header */}
                    <div className="grid grid-cols-12 gap-4 px-6 py-4 bg-gray-50 border-b border-gray-100 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                        <div className="col-span-4">Produit</div>
                        <div className="col-span-2">Vendeur</div>
                        <div className="col-span-1 text-center">Prix</div>
                        <div className="col-span-1 text-center">Statut</div>
                        <div className="col-span-1 text-center">Options</div>
                        <div className="col-span-1 text-center">Date</div>
                        <div className="col-span-2 text-center">Actions</div>
                    </div>

                    {/* Product Rows */}
                    <div className="divide-y divide-gray-50">
                        {paginatedProducts.map((product) => (
                            <div key={product.id}
                                className="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-blue-50/50 transition cursor-pointer"
                                onClick={() => setSelectedProduct(product)}
                            >
                                {/* Produit */}
                                <div className="col-span-4 flex items-center gap-3">
                                    <img
                                        src={getDisplayImage(product)}
                                        alt={product.name}
                                        className="w-12 h-12 rounded-xl object-cover flex-shrink-0 border border-gray-100 bg-gray-100"
                                        onError={(e) => { e.target.onerror = null; e.target.src = 'https://via.placeholder.com/80?text=No+img'; }}
                                    />
                                    <div className="min-w-0">
                                        <p className="font-semibold text-gray-900 truncate text-sm hover:text-blue-600 transition">{product.name}</p>
                                        {product.category && (
                                            <span className="text-xs text-gray-400 flex items-center mt-0.5">
                                                <TagIcon className="h-3 w-3 mr-0.5" />{product.category}
                                            </span>
                                        )}
                                    </div>
                                </div>

                                {/* Vendeur */}
                                <div className="col-span-2" onClick={(e) => e.stopPropagation()}>
                                    <Link to={`/users/${product.seller_id}`} className="flex items-center gap-2 hover:opacity-80 transition">
                                        <img
                                            src={getImageUrl(product.seller_avatar) || `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&background=0B1727&color=fff&size=64`}
                                            className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                                            alt=""
                                            onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&background=0B1727&color=fff`; }}
                                        />
                                        <div className="min-w-0">
                                            <p className="text-sm font-medium text-blue-600 truncate">{product.seller_name || 'Vendeur'}</p>
                                            <p className="text-xs text-gray-400 truncate">{product.seller_phone}</p>
                                        </div>
                                    </Link>
                                </div>

                                {/* Prix */}
                                <div className="col-span-1 text-center">
                                    <p className="text-sm font-bold text-gray-900">{product.price} $</p>
                                    {product.is_good_deal && product.promo_price && (
                                        <p className="text-xs text-rose-500 font-medium line-through">{product.promo_price} $</p>
                                    )}
                                </div>

                                {/* Statut */}
                                <div className="col-span-1 text-center">
                                    {product.status === 'active' ? (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-700">Actif</span>
                                    ) : product.status === 'hidden' ? (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-purple-100 text-purple-700">Masqué</span>
                                    ) : product.status === 'banned' ? (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-700">Banni</span>
                                    ) : (
                                        <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-600">{product.status}</span>
                                    )}
                                </div>

                                {/* Options */}
                                <div className="col-span-1 text-center flex flex-col items-center gap-1">
                                    {product.is_featured && (
                                        <span className="text-xs text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full font-medium flex items-center"><StarIcon className="h-3 w-3 mr-0.5" />Vedette</span>
                                    )}
                                    {product.is_good_deal && (
                                        <span className="text-xs text-rose-600 bg-rose-50 px-2 py-0.5 rounded-full font-medium flex items-center"><FireIcon className="h-3 w-3 mr-0.5" />Deal</span>
                                    )}
                                    {product.is_verified && (
                                        <span className="text-xs text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full font-medium flex items-center"><CheckBadgeSolid className="h-3 w-3 mr-0.5" />Vérifié</span>
                                    )}
                                    {!product.is_featured && !product.is_good_deal && !product.is_verified && <span className="text-xs text-gray-300">—</span>}
                                </div>

                                {/* Date */}
                                <div className="col-span-1 text-center">
                                    <p className="text-xs text-gray-400">
                                        {product.created_at ? new Date(product.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' }) : '—'}
                                    </p>
                                </div>

                                {/* Actions */}
                                <div className="col-span-2 flex justify-center gap-1.5" onClick={(e) => e.stopPropagation()}>
                                    <button onClick={() => toggleFeatured(product)}
                                        className={`p-2 rounded-lg transition ${product.is_featured ? 'bg-amber-100 text-amber-600 hover:bg-amber-200' : 'bg-gray-100 text-gray-400 hover:bg-gray-200'}`}
                                        title={product.is_featured ? 'Retirer vedette' : 'Mettre en avant'}
                                    >
                                        {product.is_featured ? <StarIcon className="h-4 w-4" /> : <StarOutline className="h-4 w-4" />}
                                    </button>
                                    <button onClick={() => toggleGoodDeal(product)}
                                        className={`p-2 rounded-lg transition ${product.is_good_deal ? 'bg-rose-100 text-rose-600 hover:bg-rose-200' : 'bg-gray-100 text-gray-400 hover:bg-gray-200'}`}
                                        title={product.is_good_deal ? 'Retirer bon deal' : 'Marquer bon deal'}
                                    >
                                        <FireIcon className="h-4 w-4" />
                                    </button>
                                    <button onClick={() => handleDelete(product.id)}
                                        className="p-2 rounded-lg bg-gray-100 text-red-400 hover:bg-red-100 hover:text-red-600 transition"
                                        title="Bannir"
                                    >
                                        <TrashIcon className="h-4 w-4" />
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Footer avec pagination */}
                    <div className="px-6 py-3 bg-gray-50 border-t border-gray-100 flex items-center justify-between">
                        <span className="text-xs text-gray-400">
                            {filteredProducts.length} produit{filteredProducts.length > 1 ? 's' : ''} — page {safePage}/{totalPages}
                        </span>
                        <div className="flex items-center gap-2">
                            <button
                                onClick={() => setPage(p => Math.max(1, p - 1))}
                                disabled={safePage <= 1}
                                className="px-3 py-1.5 text-xs rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200 disabled:opacity-40 disabled:cursor-not-allowed transition font-medium"
                            >
                                ← Précédent
                            </button>
                            <span className="text-xs text-gray-500 font-semibold">{safePage}</span>
                            <button
                                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                                disabled={safePage >= totalPages}
                                className="px-3 py-1.5 text-xs rounded-lg bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed transition font-medium"
                            >
                                Suivant →
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
