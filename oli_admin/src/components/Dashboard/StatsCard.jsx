export default function StatsCard({ title, value, icon, trend, color = 'bg-white', subtitle }) {
    const trendNum = typeof trend === 'string' ? parseFloat(trend) : trend;
    const hasTrend = trendNum !== undefined && trendNum !== null && !isNaN(trendNum);
    const isPositive = trendNum > 0;
    const isNeutral = trendNum === 0;

    return (
        <div className={`${color} p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300`}>
            <div className="flex items-start justify-between">
                <div className="flex-1">
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{title}</p>
                    <p className="mt-2 text-2xl font-bold text-gray-900">{value}</p>
                    {subtitle && <p className="mt-1 text-xs text-gray-400">{subtitle}</p>}
                </div>
                <div className="p-2.5 bg-blue-50 rounded-xl flex-shrink-0">
                    {icon}
                </div>
            </div>
            {hasTrend && (
                <div className="mt-3 flex items-center gap-1.5">
                    <span className={`inline-flex items-center gap-0.5 text-xs font-semibold px-2 py-0.5 rounded-full ${isNeutral ? 'bg-gray-100 text-gray-500' :
                            isPositive ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'
                        }`}>
                        {isPositive ? '↑' : isNeutral ? '→' : '↓'} {isPositive ? '+' : ''}{trendNum}%
                    </span>
                    <span className="text-xs text-gray-400">vs période préc.</span>
                </div>
            )}
        </div>
    );
}
