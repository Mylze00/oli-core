import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
    ArrowPathIcon,
    CheckCircleIcon,
    ClockIcon,
    ExclamationTriangleIcon,
    MagnifyingGlassIcon,
    Squares2X2Icon,
    XCircleIcon,
} from '@heroicons/react/24/outline';
import api from '../services/api';

const RANGES = [
    { value: '24h', label: '24h' },
    { value: '7d', label: '7 jours' },
    { value: '30d', label: '30 jours' },
    { value: '90d', label: '90 jours' },
];

const STATUS_FILTERS = [
    { value: '', label: 'Tous les statuts' },
    { value: 'todo', label: 'À traiter' },
    { value: 'done', label: 'Terminées' },
    { value: 'failed', label: 'Échouées' },
];

const STATUS_LABELS = {
    pending: 'En attente', open: 'Ouvert', processing: 'En préparation', reviewed: 'En cours',
    paid: 'Payée', assigned: 'Assignée', accepted: 'Acceptée', picked_up: 'Récupérée',
    in_transit: 'En route', shipped: 'Expédiée', completed: 'Terminée', success: 'Réussie',
    delivered: 'Livrée', resolved: 'Résolu', responded: 'Répondu', closed: 'Fermée',
    used: 'Utilisé', valid: 'Valide', approved: 'Approuvée', failed: 'Échouée',
    cancelled: 'Annulée', canceled: 'Annulée', timeout: 'Expirée', rejected: 'Rejetée',
    refunded: 'Remboursé', reversed: 'Annulée',
};

const GROUP_STYLES = {
    todo: 'bg-amber-100 text-amber-800',
    done: 'bg-green-100 text-green-800',
    failed: 'bg-red-100 text-red-800',
    other: 'bg-gray-100 text-gray-700',
};

const PAGE_SIZE = 25;

function formatAmount(amount, currency) {
    if (amount === null || amount === undefined) return '—';
    const value = amount.toLocaleString('fr-FR', { maximumFractionDigits: currency === 'USD' ? 2 : 0 });
    return currency === 'USD' ? `${value} $` : `${value} ${currency || ''}`;
}

function formatDate(value) {
    return new Date(value).toLocaleString('fr-FR', {
        day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit',
    });
}

function SummaryCard({ label, value, icon: Icon, color }) {
    return (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5 flex items-start justify-between">
            <div>
                <p className="text-xs font-medium uppercase tracking-wide text-gray-500">{label}</p>
                <p className="text-2xl font-bold text-gray-900 mt-2">{value.toLocaleString('fr-FR')}</p>
            </div>
            <div className={`p-2 rounded-lg ${color}`}>
                <Icon className="h-5 w-5" />
            </div>
        </div>
    );
}

export default function Operations() {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [range, setRange] = useState('7d');
    const [status, setStatus] = useState('');
    const [app, setApp] = useState('');
    const [searchInput, setSearchInput] = useState('');
    const [search, setSearch] = useState('');
    const [page, setPage] = useState(1);

    // La recherche part quand l'administrateur a fini de taper.
    useEffect(() => {
        const timer = setTimeout(() => {
            setSearch(searchInput.trim());
            setPage(1);
        }, 350);
        return () => clearTimeout(timer);
    }, [searchInput]);

    const load = useCallback(async () => {
        setLoading(true);
        try {
            const { data: result } = await api.get('/admin/operations', {
                params: {
                    range,
                    page,
                    pageSize: PAGE_SIZE,
                    ...(status && { status }),
                    ...(app && { app }),
                    ...(search && { q: search }),
                },
            });
            setData(result);
            setError('');
        } catch (err) {
            console.error('Erreur opérations:', err);
            setError('Impossible de charger les opérations. Réessayez.');
        } finally {
            setLoading(false);
        }
    }, [range, status, app, search, page]);

    useEffect(() => {
        load();
    }, [load]);

    const changeFilter = (setter) => (value) => {
        setter(value);
        setPage(1);
    };

    const summary = data?.summary ?? { total: 0, todo: 0, done: 0, failed: 0 };
    const totalPages = data ? Math.max(Math.ceil(data.total / PAGE_SIZE), 1) : 1;

    return (
        <div>
            <div className="flex flex-wrap items-start justify-between gap-4 mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                        <Squares2X2Icon className="h-7 w-7 text-indigo-600" />
                        Opérations
                    </h1>
                    <p className="text-gray-500 text-sm mt-1">
                        Toutes les opérations des applications de l'écosystème Oli
                    </p>
                </div>
                <div className="flex items-center gap-2">
                    <div className="flex bg-white border border-gray-200 rounded-lg p-1">
                        {RANGES.map((r) => (
                            <button
                                key={r.value}
                                onClick={() => changeFilter(setRange)(r.value)}
                                className={`px-3 py-1.5 text-sm rounded-md ${range === r.value ? 'bg-indigo-600 text-white' : 'text-gray-600 hover:bg-gray-100'}`}
                            >
                                {r.label}
                            </button>
                        ))}
                    </div>
                    <button
                        onClick={load}
                        title="Actualiser"
                        aria-label="Actualiser"
                        className="p-2 bg-white border border-gray-200 rounded-lg text-gray-600 hover:bg-gray-100"
                    >
                        <ArrowPathIcon className={`h-5 w-5 ${loading ? 'animate-spin' : ''}`} />
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                <SummaryCard label="Opérations" value={summary.total} icon={Squares2X2Icon} color="bg-indigo-50 text-indigo-600" />
                <SummaryCard label="À traiter" value={summary.todo} icon={ClockIcon} color="bg-amber-50 text-amber-600" />
                <SummaryCard label="Terminées" value={summary.done} icon={CheckCircleIcon} color="bg-green-50 text-green-600" />
                <SummaryCard label="Échouées" value={summary.failed} icon={XCircleIcon} color="bg-red-50 text-red-600" />
            </div>

            {data?.unavailable?.length > 0 && (
                <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-800 flex items-center gap-2">
                    <ExclamationTriangleIcon className="h-5 w-5 flex-shrink-0" />
                    Données momentanément indisponibles : {data.unavailable.join(', ')}.
                </div>
            )}

            <div className="flex flex-wrap gap-2 mb-4">
                <button
                    onClick={() => changeFilter(setApp)('')}
                    className={`px-3 py-1.5 rounded-full text-sm font-medium ${app === '' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                >
                    Toutes les applications
                </button>
                {data?.apps?.map((a) => (
                    <button
                        key={a.name}
                        onClick={() => changeFilter(setApp)(a.name)}
                        className={`px-3 py-1.5 rounded-full text-sm font-medium ${app === a.name ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                    >
                        {a.name} <span className="opacity-70">({a.total})</span>
                    </button>
                ))}
            </div>

            <div className="bg-white rounded-xl border border-gray-100 shadow-sm">
                <div className="flex flex-wrap items-center gap-3 p-4 border-b border-gray-100">
                    <div className="relative flex-1 min-w-[220px]">
                        <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                        <input
                            value={searchInput}
                            onChange={(e) => setSearchInput(e.target.value)}
                            placeholder="Rechercher par nom, téléphone, référence…"
                            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                    </div>
                    <select
                        value={status}
                        onChange={(e) => changeFilter(setStatus)(e.target.value)}
                        aria-label="Filtrer par statut"
                        className="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white"
                    >
                        {STATUS_FILTERS.map((s) => <option key={s.value} value={s.value}>{s.label}</option>)}
                    </select>
                </div>

                {error ? (
                    <div className="p-10 text-center text-red-600 text-sm">{error}</div>
                ) : !data ? (
                    <div className="p-10 text-center text-gray-500 text-sm">Chargement…</div>
                ) : data.items.length === 0 ? (
                    <div className="p-10 text-center text-gray-500 text-sm">Aucune opération pour ces filtres</div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead>
                                <tr className="text-left text-xs uppercase tracking-wide text-gray-500 bg-gray-50">
                                    <th className="px-4 py-3 font-medium">Date</th>
                                    <th className="px-4 py-3 font-medium">Application</th>
                                    <th className="px-4 py-3 font-medium">Opération</th>
                                    <th className="px-4 py-3 font-medium">Utilisateur</th>
                                    <th className="px-4 py-3 font-medium text-right">Montant</th>
                                    <th className="px-4 py-3 font-medium">Statut</th>
                                    <th className="px-4 py-3" />
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {data.items.map((op) => (
                                    <tr key={op.id} className="hover:bg-gray-50">
                                        <td className="px-4 py-3 text-gray-500 whitespace-nowrap">{formatDate(op.createdAt)}</td>
                                        <td className="px-4 py-3 text-gray-700 whitespace-nowrap">{op.app}</td>
                                        <td className="px-4 py-3 max-w-xs">
                                            <p className="font-medium text-gray-900 truncate">{op.title}</p>
                                            <p className="text-xs text-gray-500 truncate">{op.label} · {op.ref}</p>
                                        </td>
                                        <td className="px-4 py-3">
                                            <p className="text-gray-900">{op.actorName || '—'}</p>
                                            <p className="text-xs text-gray-500">{op.actorPhone || ''}</p>
                                        </td>
                                        <td className="px-4 py-3 text-right font-medium text-gray-900 whitespace-nowrap">
                                            {formatAmount(op.amount, op.currency)}
                                        </td>
                                        <td className="px-4 py-3">
                                            <span className={`px-2 py-1 rounded-full text-xs font-medium whitespace-nowrap ${GROUP_STYLES[op.statusGroup]}`}>
                                                {STATUS_LABELS[op.status] || op.status}
                                            </span>
                                        </td>
                                        <td className="px-4 py-3 text-right">
                                            <Link to={op.href} className="text-indigo-600 hover:underline font-medium whitespace-nowrap">
                                                Gérer
                                            </Link>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {data && data.total > PAGE_SIZE && (
                    <div className="flex items-center justify-between p-4 border-t border-gray-100 text-sm text-gray-600">
                        <span>Page {page} sur {totalPages} · {data.total} opérations</span>
                        <div className="flex gap-2">
                            <button
                                disabled={page <= 1}
                                onClick={() => setPage(page - 1)}
                                className="px-3 py-1.5 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
                            >
                                Précédent
                            </button>
                            <button
                                disabled={page >= totalPages}
                                onClick={() => setPage(page + 1)}
                                className="px-3 py-1.5 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
                            >
                                Suivant
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
