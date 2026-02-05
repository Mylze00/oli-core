const textColors = {
    pending: 'text-yellow-600',
    confirmed: 'text-blue-600',
    shipped: 'text-indigo-600',
    delivered: 'text-green-600',
    cancelled: 'text-red-600',
};

const bgColors = {
    pending: 'bg-yellow-50',
    confirmed: 'bg-blue-50',
    shipped: 'bg-indigo-50',
    delivered: 'bg-green-50',
    cancelled: 'bg-red-50',
};

export default function RecentOrdersTable({ orders = [] }) {
    if (!orders || orders.length === 0) {
        return <div className="p-6 text-center text-gray-500">Aucune commande récente</div>;
    }

    return (
        <div className="overflow-x-auto">
            <table className="w-full text-left text-sm text-gray-600">
                <thead className="bg-gray-50 text-xs uppercase font-medium text-gray-500">
                    <tr>
                        <th className="px-6 py-4">Commande</th>
                        <th className="px-6 py-4">Client</th>
                        <th className="px-6 py-4">Date</th>
                        <th className="px-6 py-4">Montant</th>
                        <th className="px-6 py-4">Statut</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                    {orders.map((order) => (
                        <tr key={order.id} className="hover:bg-gray-50 transition">
                            <td className="px-6 py-4 font-medium text-gray-900">
                                #{order.id.toString().slice(0, 8)}
                            </td>
                            <td className="px-6 py-4 flex items-center gap-3">
                                <div className="h-8 w-8 rounded-full bg-gray-200 overflow-hidden">
                                    <img
                                        src={order.avatar_url || `https://ui-avatars.com/api/?name=${order.buyer_name}`}
                                        alt=""
                                        className="h-full w-full object-cover"
                                    />
                                </div>
                                <span className="font-medium text-gray-900">{order.buyer_name}</span>
                            </td>
                            <td className="px-6 py-4">
                                {new Date(order.created_at).toLocaleDateString()}
                            </td>
                            <td className="px-6 py-4 font-medium text-gray-900">
                                {Number(order.total_amount).toLocaleString()} $
                            </td>
                            <td className="px-6 py-4">
                                <span className={`px-2 py-1 rounded-full text-xs font-semibold ${bgColors[order.status] || 'bg-gray-100'} ${textColors[order.status] || 'text-gray-600'}`}>
                                    {order.status}
                                </span>
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
