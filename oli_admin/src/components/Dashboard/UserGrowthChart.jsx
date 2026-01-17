import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts';

export default function UserGrowthChart({ data }) {
    if (!data || data.length === 0) return <div className="text-gray-500">Aucune donnée disponible</div>;

    return (
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-100 h-80 min-w-0" style={{ width: '100%', height: 320 }}>
            <h2 className="font-bold text-gray-700 mb-4">Nouveaux Utilisateurs</h2>
            <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis
                        dataKey="date"
                        tickFormatter={(str) => new Date(str).toLocaleDateString(undefined, { day: '2-digit', month: '2-digit' })}
                        tick={{ fontSize: 12 }}
                    />
                    <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
                    <Tooltip
                        labelFormatter={(str) => new Date(str).toLocaleDateString()}
                    />
                    <Bar dataKey="new_users" fill="#10B981" radius={[4, 4, 0, 0]} />
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}
