import { useState } from 'react';
import { Plus, Trash, ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function ProductEditor() {
    const navigate = useNavigate();
    const [b2bPricing, setB2bPricing] = useState([
        { min: 1, max: 50, price: '' }
    ]);
    const [product, setProduct] = useState({
        name: '',
        category: '',
        basePrice: '',
        moq: 1,
        brand: '',
        unit: 'Pièce',
        unit: 'Pièce',
        weight: ''
    });
    const [images, setImages] = useState([]); // State pour les images

    const units = [
        "Pièce", "Kg", "Litre", "Carton (6)", "Carton (12)", "Carton (24)",
        "Douzaine", "Paquet", "Sac (25kg)", "Sac (50kg)", "Palette"
    ];

    const categories = [
        "Alimentation > Épicerie", "Alimentation > Boissons", "Alimentation > Frais",
        "Maison & Entretien", "Beauté & Hygiène", "Électronique", "Textile"
    ];

    const addTier = () => {
        const lastMax = b2bPricing[b2bPricing.length - 1]?.max || 0;
        setB2bPricing([...b2bPricing, { min: lastMax + 1, max: '', price: '' }]);
    };

    const updateTier = (index, field, value) => {
        const newPricing = [...b2bPricing];
        newPricing[index][field] = value;
        setB2bPricing(newPricing);
    };

    const removeTier = (index) => {
        setB2bPricing(b2bPricing.filter((_, i) => i !== index));
    };

    const handleImageChange = (e) => {
        if (e.target.files) {
            setImages([...images, ...Array.from(e.target.files)]);
        }
    };

    const removeImage = (index) => {
        setImages(images.filter((_, i) => i !== index));
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        try {
            const formData = new FormData();

            // Append basic fields
            Object.keys(product).forEach(key => {
                formData.append(key, product[key]);
            });

            // Append images
            images.forEach(image => {
                formData.append('images', image);
            });

            // Append B2B pricing as JSON string
            formData.append('b2b_pricing', JSON.stringify(b2bPricing));

            console.log("Saving Product via FormData...");
            await api.post('/products/upload', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });

            alert("Produit publié avec succès !");
            navigate('/products');
        } catch (err) {
            console.error("Erreur upload:", err);
            alert("Erreur lors de la publication");
        }
    };

    return (
        <div className="p-8 max-w-5xl mx-auto">
            <button onClick={() => navigate('/products')} className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900">
                <ArrowLeft size={16} /> Retour
            </button>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Ajouter un nouveau produit</h1>

            <form onSubmit={handleSubmit} className="space-y-8">
                {/* Basic Info */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h2 className="text-lg font-bold mb-4">Informations de base</h2>
                    <div className="grid grid-cols-2 gap-6">
                        <div className="col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">Nom du produit</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                                value={product.name}
                                onChange={e => setProduct({ ...product, name: e.target.value })}
                                required
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Catégorie</label>
                            <select
                                className="w-full border p-2 rounded"
                                value={product.category}
                                onChange={e => setProduct({ ...product, category: e.target.value })}
                            >
                                <option value="">Choisir...</option>
                                {categories.map(c => <option key={c} value={c}>{c}</option>)}
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Marque</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded"
                                placeholder="ex: Coca-Cola, Samsung"
                                value={product.brand}
                                onChange={e => setProduct({ ...product, brand: e.target.value })}
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Prix Standard (1 unité)</label>
                            <input
                                type="number"
                                className="w-full border p-2 rounded"
                                value={product.basePrice}
                                onChange={e => setProduct({ ...product, basePrice: e.target.value })}
                                required
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Unité de vente</label>
                            <select
                                className="w-full border p-2 rounded"
                                value={product.unit}
                                onChange={e => setProduct({ ...product, unit: e.target.value })}
                            >
                                {units.map(u => <option key={u} value={u}>{u}</option>)}
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Poids / Volume</label>
                            <input
                                type="text"
                                className="w-full border p-2 rounded"
                                placeholder="ex: 500g, 1.5L"
                                value={product.weight}
                                onChange={e => setProduct({ ...product, weight: e.target.value })}
                            />
                        </div>
                    </div>
                </div>

                {/* Image Upload Section */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h2 className="text-lg font-bold mb-4">Photos du produit</h2>
                    <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center bg-gray-50 hover:bg-gray-100 transition-colors cursor-pointer relative">
                        <input
                            type="file"
                            multiple
                            accept="image/*"
                            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                            onChange={handleImageChange}
                        />
                        <div className="flex flex-col items-center justify-center text-gray-500">
                            <Plus size={32} className="mb-2 text-blue-500" />
                            <p className="font-medium">Cliquez ou glissez vos images ici</p>
                            <p className="text-sm text-gray-400">Jusqu'à 8 photos (JPG, PNG)</p>
                        </div>
                    </div>

                    {/* Image Previews */}
                    {images.length > 0 && (
                        <div className="grid grid-cols-4 gap-4 mt-6">
                            {images.map((img, idx) => (
                                <div key={idx} className="relative group aspect-square rounded overflow-hidden border">
                                    <img
                                        src={URL.createObjectURL(img)}
                                        alt="Preview"
                                        className="w-full h-full object-cover"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => removeImage(idx)}
                                        className="absolute top-1 right-1 bg-white rounded-full p-1 shadow hover:text-red-600"
                                    >
                                        <Trash size={14} />
                                    </button>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* B2B Pricing Section */}
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <div className="flex justify-between items-center mb-4">
                        <h2 className="text-lg font-bold text-blue-900">Prix Dégressifs (B2B)</h2>
                        <button type="button" onClick={addTier} className="text-blue-600 text-sm font-medium hover:underline flex items-center gap-1">
                            <Plus size={16} /> Ajouter un palier
                        </button>
                    </div>

                    <div className="overflow-x-auto">
                        <table className="w-full text-left bg-blue-50/50 rounded-lg overflow-hidden">
                            <thead className="bg-blue-100 text-blue-800">
                                <tr>
                                    <th className="p-3 text-sm">Qté Min</th>
                                    <th className="p-3 text-sm">Qté Max</th>
                                    <th className="p-3 text-sm">Prix Unitaire ($)</th>
                                    <th className="p-3 text-sm w-10"></th>
                                </tr>
                            </thead>
                            <tbody>
                                {b2bPricing.map((tier, index) => (
                                    <tr key={index} className="border-b border-blue-100 last:border-0">
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-20 border p-1 rounded"
                                                value={tier.min}
                                                onChange={e => updateTier(index, 'min', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-20 border p-1 rounded"
                                                value={tier.max}
                                                placeholder="∞"
                                                onChange={e => updateTier(index, 'max', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3">
                                            <input
                                                type="number"
                                                className="w-24 border p-1 rounded font-bold text-gray-900"
                                                value={tier.price}
                                                placeholder="0.00"
                                                onChange={e => updateTier(index, 'price', e.target.value)}
                                            />
                                        </td>
                                        <td className="p-3 text-center">
                                            {index > 0 && (
                                                <button
                                                    type="button"
                                                    onClick={() => removeTier(index)}
                                                    className="text-red-400 hover:text-red-600"
                                                >
                                                    <Trash size={16} />
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        <p className="text-xs text-gray-500 mt-2 italic">
                            * Le prix affiché aux clients dépendra de la quantité ajoutée au panier.
                        </p>
                    </div>
                </div>

                {/* Action Buttons */}
                <div className="flex justify-end gap-3">
                    <button type="button" className="px-6 py-2 border rounded text-gray-600 hover:bg-gray-50">Annuler</button>
                    <button type="submit" className="px-6 py-2 bg-blue-600 text-white rounded font-bold hover:bg-blue-700 shadow-md">
                        Publier le produit
                    </button>
                </div>
            </form>
        </div>
    );
}
