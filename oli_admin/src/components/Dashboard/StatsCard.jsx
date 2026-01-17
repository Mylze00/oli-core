export default function StatsCard({ title, value, icon, trend, color = 'bg-white' }) {
    return (
        <div className={`${color} p-6 rounded-lg shadow-sm border border-gray-100`}>
            <div className="flex items-center justify-between">
                <div>
                    <p className="text-sm font-medium text-gray-500 uppercase tracking-wider">{title}</p>
                    <p className="mt-2 text-3xl font-bold text-gray-900">{value}</p>
                </div>
                <div className="p-3 bg-blue-50 rounded-full">
                    {icon}
                </div>
            </div>
            {trend && (
                <div className="mt-4 flex items-center text-sm">
                    <span className={trend > 0 ? 'text-green-600' : 'text-red-600'}>
                        {trend > 0 ? '+' : ''}{trend}%
                    </span>
                    <span className="ml-2 text-gray-400">vs mois dernier</span>
                </div>
            )}
        </div>
    );
}
