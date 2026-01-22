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
        moq: 1
    });

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

    const handleSubmit = (e) => {
        e.preventDefault();
        console.log("Saving Product:", { ...product, b2b_pricing: b2bPricing });
        alert("Produit sauvegardé ! (Console log)");
        navigate('/products');
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
                            <select className="w-full border p-2 rounded">
                                <option>Électronique</option>
                                <option>Maison</option>
                                <option>Mode</option>
                            </select>
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
                    </div>
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
