import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';

export default function RevenueChart({ data }) {
    if (!data || data.length === 0) return <div className="text-gray-500">Aucune donnée disponible</div>;

    return (
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100 h-80 min-w-0" style={{ width: '100%', height: 320 }}>
            <h2 className="font-bold text-gray-700 mb-4">Revenus (30 derniers jours)</h2>
            <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                    data={data}
                    margin={{
                        top: 10,
                        right: 30,
                        left: 0,
                        bottom: 0,
                    }}
                >
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis
                        dataKey="date"
                        tickFormatter={(str) => new Date(str).toLocaleDateString(undefined, { day: '2-digit', month: '2-digit' })}
                        tick={{ fontSize: 12 }}
                    />
                    <YAxis tick={{ fontSize: 12 }} />
                    <Tooltip
                        formatter={(value) => [`${value} $`, 'Revenu']}
                        labelFormatter={(str) => new Date(str).toLocaleDateString()}
                    />
                    <Area type="monotone" dataKey="revenue" stroke="#2563EB" fill="#3B82F6" fillOpacity={0.2} />
                </AreaChart>
            </ResponsiveContainer>
        </div>
    );
}
