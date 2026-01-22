import { Plus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function ProductList() {
    const navigate = useNavigate();

    return (
        <div className="p-8">
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Mes Produits</h1>
                <button
                    onClick={() => navigate('/products/new')}
                    className="bg-blue-600 text-white px-4 py-2 rounded flex items-center gap-2 hover:bg-blue-700"
                >
                    <Plus size={20} /> Nouveau Produit
                </button>
            </div>

            <div className="bg-white rounded shadow-sm border border-gray-200 overflow-hidden">
                <table className="w-full text-left">
                    <thead className="bg-gray-50 border-b border-gray-200">
                        <tr>
                            <th className="p-4 font-medium text-gray-500">Produit</th>
                            <th className="p-4 font-medium text-gray-500">Prix (Base)</th>
                            <th className="p-4 font-medium text-gray-500">Stock</th>
                            <th className="p-4 font-medium text-gray-500">Statut</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr className="border-b border-gray-100 hover:bg-gray-50">
                            <td className="p-4">
                                <div className="font-medium">Casque Audio Pro X2</div>
                                <div className="text-xs text-gray-500">SKU: AUD-2024-001</div>
                            </td>
                            <td className="p-4">$150.00</td>
                            <td className="p-4">500</td>
                            <td className="p-4"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">Actif</span></td>
                        </tr>
                        {/* More rows... */}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
