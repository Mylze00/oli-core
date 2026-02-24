import { useEffect, useState, useMemo } from 'react';
import api from '../services/api';
import {
    CreditCardIcon,
    BanknotesIcon,
    ShoppingCartIcon,
    UsersIcon,
    ArrowTrendingUpIcon,
    ArrowTrendingDownIcon,
    ChartBarIcon,
    MagnifyingGlassIcon,
    CheckCircleIcon,
    ClockIcon,
    XCircleIcon,
} from '@heroicons/react/24/solid';

/* ─── Helpers ─────────────────────────────────────────────────────────── */

function fmt(amount) {
    if (amount >= 1000) return `$${(amount / 1000).toFixed(1)}k`;
    return `$${parseFloat(amount || 0).toFixed(2)}`;
}

function fmtFull(amount) {
    return `$${parseFloat(amount || 0).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function formatDate(date) {
    if (!date) return '—';
    return new Date(date).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

/* ─── Sub-components ──────────────────────────────────────────────────── */

function StatCard({ label, value, sub, icon: Icon, color, trend }) {
    const colors = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        amber: 'bg-amber-50 text-amber-600',
        purple: 'bg-purple-50 text-purple-600',
        red: 'bg-red-50 text-red-600',
    };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex items-center justify-between mb-3">
                <div className={`p-2 rounded-xl ${colors[color]}`}>
                    <Icon className="h-5 w-5" />
                </div>
                {trend !== undefined && (
                    <span className={`text-xs font-semibold flex items-center gap-0.5 ${trend >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                        {trend >= 0 ? <ArrowTrendingUpIcon className="h-3.5 w-3.5" /> : <ArrowTrendingDownIcon className="h-3.5 w-3.5" />}
                        {Math.abs(trend)}%
                    </span>
                )}
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{label}</p>
            {sub && <p className="text-xs text-gray-500 mt-1">{sub}</p>}
        </div>
    );
}

function PaymentBadge({ status }) {
    const map = {
        completed: { bg: 'bg-green-100 text-green-700', label: '✓ Payé', icon: CheckCircleIcon },
        pending: { bg: 'bg-amber-100 text-amber-700', label: '⏳ En attente', icon: ClockIcon },
        failed: { bg: 'bg-red-100 text-red-700', label: '✗ Échoué', icon: XCircleIcon },
    };
    const s = map[status] || map.pending;
    return (
        <span className={`inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full ${s.bg}`}>
            {s.label}
        </span>
    );
}

/* ─── Mini bar chart ──────────────────────────────────────────────────── */
function MiniBarChart({ data }) {
    if (!data || data.length === 0) {
        return <div className="flex items-center justify-center h-32 text-gray-300 text-sm">Aucune donnée</div>;
    }
    const max = Math.max(...data.map(d => parseFloat(d.revenue || 0)), 1);
    return (
        <div className="flex items-end gap-1 h-32 w-full">
            {data.map((d, i) => {
                const height = Math.max(4, (parseFloat(d.revenue) / max) * 100);
                return (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
                        <div
                            className="w-full bg-blue-500 rounded-t hover:bg-blue-600 transition-all cursor-default"
                            style={{ height: `${height}%` }}
                        />
                        <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition whitespace-nowrap pointer-events-none z-10">
                            {new Date(d.date).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' })} — {fmt(d.revenue)}
                        </div>
                    </div>
                );
            })}
        </div>
    );
}

/* ─── Main Component ──────────────────────────────────────────────────── */

export default function Finances() {
    const [range, setRange] = useState('30');
    const [overview, setOverview] = useState(null);
    const [chart, setChart] = useState([]);
    const [topSellers, setTopSellers] = useState([]);
    const [transactions, setTransactions] = useState([]);
    const [txFilter, setTxFilter] = useState('all');
    const [txSearch, setTxSearch] = useState('');
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchAll();
    }, [range]);

    const fetchAll = async () => {
        setLoading(true);
        try {
            const [ovRes, chartRes, sellersRes, txRes] = await Promise.all([
                api.get(`/admin/finances/overview?range=${range}d`),
                api.get(`/admin/finances/revenue-chart?days=${range}`),
                api.get('/admin/finances/top-sellers?limit=8'),
                api.get('/admin/finances/transactions?limit=100'),
            ]);
            setOverview(ovRes.data);
            setChart(chartRes.data);
            setTopSellers(sellersRes.data);
            setTransactions(txRes.data);
        } catch (err) {
            console.error('Erreur finances:', err);
        } finally {
            setLoading(false);
        }
    };

    const filteredTx = useMemo(() => {
        let list = transactions;
        if (txFilter !== 'all') list = list.filter(t => t.payment_status === txFilter);
        if (txSearch) {
            const s = txSearch.toLowerCase();
            list = list.filter(t =>
                t.buyer_name?.toLowerCase().includes(s) ||
                t.buyer_phone?.includes(s) ||
                t.seller_name?.toLowerCase().includes(s)
            );
        }
        return list;
    }, [transactions, txFilter, txSearch]);

    if (loading) return (
        <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
    );

    const rev = overview?.revenue || {};
    const wal = overview?.wallets || {};

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">

            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Finances</h1>
                    <p className="text-sm text-gray-400 mt-1">Revenus, transactions et wallets de l'écosystème Oli</p>
                </div>
                <div className="flex gap-2">
                    {[
                        { label: '7 jours', value: '7' },
                        { label: '30 jours', value: '30' },
                        { label: '90 jours', value: '90' },
                    ].map(r => (
                        <button
                            key={r.value}
                            onClick={() => setRange(r.value)}
                            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${range === r.value ? 'bg-blue-600 text-white shadow-sm' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'}`}
                        >
                            {r.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <StatCard
                    label="Revenus totaux (commandes)"
                    value={fmt(rev.total)}
                    sub={`${fmtFull(rev.period)} sur ${range}j`}
                    icon={BanknotesIcon}
                    color="green"
                />
                <StatCard
                    label="Commandes payées"
                    value={rev.paid || 0}
                    sub={`${rev.pending || 0} en attente`}
                    icon={CreditCardIcon}
                    color="blue"
                />
                <StatCard
                    label="Panier moyen"
                    value={fmtFull(rev.avg)}
                    icon={ShoppingCartIcon}
                    color="purple"
                />
                <StatCard
                    label="Total wallets utilisateurs"
                    value={fmt(wal.total_balance)}
                    sub={`${wal.users_with_balance || 0} utilisateurs avec solde`}
                    icon={UsersIcon}
                    color="amber"
                />
            </div>

            {/* Revenue Chart + Top Sellers */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">

                {/* Chart */}
                <div className="md:col-span-2 bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-2">
                            <ChartBarIcon className="h-5 w-5 text-blue-500" />
                            <h2 className="text-sm font-semibold text-gray-700">Revenus par jour</h2>
                        </div>
                        <span className="text-xs text-gray-400">{range} derniers jours</span>
                    </div>
                    <MiniBarChart data={chart} />
                    <div className="mt-2 text-right text-xs text-gray-400">
                        Total période : <span className="font-semibold text-gray-700">{fmtFull(rev.period)}</span>
                    </div>
                </div>

                {/* Top Sellers */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                    <h2 className="text-sm font-semibold text-gray-700 mb-4">🏆 Top Vendeurs</h2>
                    {topSellers.length === 0 ? (
                        <p className="text-gray-400 text-sm text-center py-8">Aucun vendeur</p>
                    ) : (
                        <div className="space-y-3">
                            {topSellers.map((s, i) => (
                                <div key={s.id} className="flex items-center gap-3">
                                    <span className="text-xs font-bold text-gray-400 w-4">#{i + 1}</span>
                                    <img
                                        src={s.avatar_url || `https://ui-avatars.com/api/?name=${s.name || 'V'}&background=0B1727&color=fff&size=40`}
                                        className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                                        alt=""
                                        onError={(e) => { e.target.src = `https://ui-avatars.com/api/?name=${s.name || 'V'}&background=0B1727&color=fff`; }}
                                    />
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm font-medium text-gray-900 truncate">{s.name || 'Sans nom'}</p>
                                        <p className="text-xs text-gray-400">{s.orders_count} commandes</p>
                                    </div>
                                    <span className="text-sm font-bold text-green-600">{fmt(s.total_revenue)}</span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Transactions */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100">
                <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3 px-6 py-4 border-b border-gray-100">
                    <h2 className="text-sm font-semibold text-gray-700">Dernières Transactions</h2>
                    <div className="flex items-center gap-3">
                        <div className="flex gap-1">
                            {[
                                { label: 'Toutes', value: 'all' },
                                { label: '✓ Payées', value: 'completed' },
                                { label: '⏳ Attente', value: 'pending' },
                            ].map(f => (
                                <button
                                    key={f.value}
                                    onClick={() => setTxFilter(f.value)}
                                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${txFilter === f.value ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                                >
                                    {f.label}
                                </button>
                            ))}
                        </div>
                        <div className="relative">
                            <MagnifyingGlassIcon className="h-4 w-4 absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" />
                            <input
                                type="text"
                                placeholder="Rechercher..."
                                value={txSearch}
                                onChange={e => setTxSearch(e.target.value)}
                                className="pl-8 pr-3 py-1.5 border border-gray-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 w-48"
                            />
                        </div>
                    </div>
                </div>

                {filteredTx.length === 0 ? (
                    <div className="p-12 text-center">
                        <CreditCardIcon className="h-10 w-10 text-gray-200 mx-auto mb-2" />
                        <p className="text-gray-400 text-sm">Aucune transaction trouvée</p>
                    </div>
                ) : (
                    <>
                        <div className="grid grid-cols-12 gap-3 px-6 py-3 bg-gray-50 border-b border-gray-100 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                            <div className="col-span-1">#</div>
                            <div className="col-span-3">Acheteur</div>
                            <div className="col-span-2">Vendeur</div>
                            <div className="col-span-2 text-right">Montant</div>
                            <div className="col-span-2 text-center">Paiement</div>
                            <div className="col-span-2 text-right">Date</div>
                        </div>
                        <div className="divide-y divide-gray-50 max-h-96 overflow-y-auto">
                            {filteredTx.map(tx => (
                                <div key={tx.id} className="grid grid-cols-12 gap-3 px-6 py-3 items-center hover:bg-gray-50 transition">
                                    <div className="col-span-1 text-xs text-gray-300">#{tx.id}</div>
                                    <div className="col-span-3">
                                        <p className="text-sm font-medium text-gray-900 truncate">{tx.buyer_name || '—'}</p>
                                        <p className="text-xs text-gray-400">{tx.buyer_phone}</p>
                                    </div>
                                    <div className="col-span-2">
                                        <p className="text-sm text-gray-600 truncate">{tx.seller_name || '—'}</p>
                                    </div>
                                    <div className="col-span-2 text-right">
                                        <p className="text-sm font-bold text-gray-900">{fmtFull(tx.total_amount)}</p>
                                    </div>
                                    <div className="col-span-2 flex justify-center">
                                        <PaymentBadge status={tx.payment_status} />
                                    </div>
                                    <div className="col-span-2 text-right">
                                        <p className="text-xs text-gray-400">{formatDate(tx.created_at)}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <div className="px-6 py-3 border-t border-gray-100 text-xs text-gray-400 text-right">
                            {filteredTx.length} transaction{filteredTx.length > 1 ? 's' : ''} affichée{filteredTx.length > 1 ? 's' : ''}
                        </div>
                    </>
                )}
            </div>
        </div>
    );
}
