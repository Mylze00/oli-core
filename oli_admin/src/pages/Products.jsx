import { useEffect, useState } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import { StarIcon, TrashIcon } from '@heroicons/react/24/outline'; // Outline = non featured
import { StarIcon as StarIconSolid } from '@heroicons/react/24/solid'; // Solid = featured

export default function Products() {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchProducts();
    }, []);

    const fetchProducts = async () => {
        try {
            const { data } = await api.get('/admin/products?limit=100');
            setProducts(data);
        } catch (error) {
            console.error("Erreur products:", error);
        } finally {
            setLoading(false);
        }
    };

    const toggleFeatured = async (product) => {
        try {
            await api.patch(`/admin/products/${product.id}/feature`, {
                is_featured: !product.is_featured
            });
            // Update local state optimistically
            setProducts(products.map(p =>
                p.id === product.id ? { ...p, is_featured: !p.is_featured } : p
            ));
        } catch (error) {
            console.error("Erreur toggle featured:", error);
            alert("Erreur lors de la modification");
        }
    };

    const handleDelete = async (productId) => {
        if (!window.confirm("Voulez-vous vraiment supprimer ce produit ? (Cette action est irréversible)")) return;
        try {
            await api.delete(`/admin/products/${productId}`);
            setProducts(products.filter(p => p.id !== productId));
        } catch (error) {
            console.error("Erreur delete:", error);
            alert("Erreur lors de la suppression");
        }
    };

    if (loading) return <div>Chargement...</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Produits</h1>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {products.map((product) => {
                    // Logique d'extraction d'image robuste
                    let displayImage = 'https://via.placeholder.com/300';

                    if (product.image_url) {
                        displayImage = getImageUrl(product.image_url);
                    } else if (product.images) {
                        if (Array.isArray(product.images) && product.images.length > 0) {
                            displayImage = getImageUrl(product.images[0]);
                        } else if (typeof product.images === 'string') {
                            // Nettoyage format Postgres "{img1,img2}"
                            const clean = product.images.replace(/[{}""]/g, '').split(',')[0];
                            if (clean) displayImage = getImageUrl(clean);
                        }
                    }

                    return (
                        <div key={product.id} className="bg-white border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition">
                            <div className="h-48 bg-gray-200 relative">
                                <img
                                    src={displayImage}
                                    alt={product.name}
                                    className="w-full h-full object-cover"
                                    onError={(e) => e.target.src = 'https://via.placeholder.com/300?text=No+Image'}
                                />
                                {product.is_suspended && (
                                    <div className="absolute top-0 right-0 bg-red-500 text-white px-2 py-1 text-xs">Banni</div>
                                )}
                            </div>
                            <div className="p-4">
                                <div className="flex justify-between items-start">
                                    <div>
                                        <h3 className="text-lg font-bold text-gray-900">{product.name}</h3>
                                        <p className="text-gray-500 text-sm">{product.category}</p>
                                    </div>
                                    <div className="flex gap-1">
                                        <button
                                            onClick={() => toggleFeatured(product)}
                                            className="p-1 rounded-full hover:bg-gray-100"
                                            title="Mettre en avant"
                                        >
                                            {product.is_featured ? (
                                                <StarIconSolid className="h-6 w-6 text-yellow-400" />
                                            ) : (
                                                <StarIcon className="h-6 w-6 text-gray-400" />
                                            )}
                                        </button>
                                        <button
                                            onClick={() => handleDelete(product.id)}
                                            className="p-1 rounded-full hover:bg-red-50 text-red-500"
                                            title="Supprimer / Bannir"
                                        >
                                            <TrashIcon className="h-6 w-6" />
                                        </button>
                                    </div>
                                </div>
                                <div className="mt-2 flex justify-between items-center">
                                    <span className="text-xl font-bold text-primary">{product.price} $</span>
                                    <span className={`text-xs px-2 py-1 rounded-full ${product.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                                        }`}>
                                        {product.status}
                                    </span>
                                </div>
                                <div className="mt-2 text-sm text-gray-600">
                                    <label className="flex items-center gap-2 cursor-pointer">
                                        <input
                                            type="checkbox"
                                            checked={product.is_good_deal || false}
                                            onChange={async (e) => {
                                                const newVal = e.target.checked;
                                                const newPrice = newVal ? prompt("Prix promo ?", product.promo_price || product.price) : null;
                                                if (newVal && !newPrice) return; // Cancel if no price entered

                                                try {
                                                    await api.patch(`/admin/products/${product.id}/good-deal`, {
                                                        is_good_deal: newVal,
                                                        promo_price: newVal ? newPrice : null
                                                    });
                                                    // Optimistic update
                                                    setProducts(products.map(p =>
                                                        p.id === product.id ? { ...p, is_good_deal: newVal, promo_price: newVal ? newPrice : null } : p
                                                    ));
                                                } catch (err) { alert('Erreur'); }
                                            }}
                                            className="form-checkbox h-4 w-4 text-blue-600"
                                        />
                                        <span className="font-medium text-xs">🔥 Bon Deal {product.is_good_deal && `(${product.promo_price}$)`}</span>
                                    </label>
                                </div>
                                <div className="mt-4 pt-4 border-t flex items-center gap-2">
                                    <img
                                        src={getImageUrl(product.seller_avatar) || `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&size=32`}
                                        alt=""
                                        className="h-8 w-8 rounded-full object-cover border border-gray-200"
                                        onError={(e) => e.target.src = `https://ui-avatars.com/api/?name=${product.seller_name || 'V'}&size=32`}
                                    />
                                    <div className="flex-1 min-w-0">
                                        <div className="text-sm font-medium text-gray-900 truncate">{product.seller_name || 'Vendeur'}</div>
                                        <div className="text-xs text-gray-500">{product.seller_phone}</div>
                                    </div>
                                    <span className="text-xs text-gray-400">{new Date(product.created_at).toLocaleDateString()}</span>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
