import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import {
    TruckIcon,
    CheckBadgeIcon,
    NoSymbolIcon,
    UserGroupIcon,
    MagnifyingGlassIcon,
    CheckCircleIcon,
    XCircleIcon,
    ShieldCheckIcon,
    ClipboardDocumentListIcon,
    ClockIcon,
} from '@heroicons/react/24/solid';

/* ─── Reusable Components ─────────────────────────────────────── */

function StatCard({ label, value, icon: Icon, color }) {
    const c = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        red: 'bg-red-50 text-red-600',
        amber: 'bg-amber-50 text-amber-600',
        purple: 'bg-purple-50 text-purple-600',
    };
    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-3 mb-2">
                <div className={`p-2 rounded-lg ${c[color]}`}><Icon className="h-5 w-5" /></div>
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
        </div>
    );
}

function FilterPill({ label, count, active, onClick }) {
    return (
        <button onClick={onClick}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2 ${active ? 'bg-blue-600 text-white shadow-sm' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
        >
            {label}
            {count !== undefined && (
                <span className={`text-xs px-1.5 py-0.5 rounded-full ${active ? 'bg-white/20' : 'bg-gray-200 text-gray-500'}`}>{count}</span>
            )}
        </button>
    );
}

/* ─── Main Component ──────────────────────────────────────────── */

export default function Delivery() {
    const [tab, setTab] = useState('drivers'); // 'drivers' | 'applications'

    // Drivers state
    const [drivers, setDrivers] = useState([]);
    const [driverStats, setDriverStats] = useState({ total: 0, active: 0, verified: 0, suspended: 0 });
    const [driverLoading, setDriverLoading] = useState(true);
    const [driverSearch, setDriverSearch] = useState('');
    const [driverFilter, setDriverFilter] = useState('all');

    // Applications state
    const [applications, setApplications] = useState([]);
    const [appStats, setAppStats] = useState({ total: 0, pending: 0, approved: 0, rejected: 0 });
    const [appLoading, setAppLoading] = useState(true);
    const [appFilter, setAppFilter] = useState('all');
    const [appSearch, setAppSearch] = useState('');
    const [actionLoading, setActionLoading] = useState(null); // id of application being actioned

    useEffect(() => {
        fetchDrivers();
        fetchApplications();
    }, []);

    /* ─── Fetch Functions ─── */

    const fetchDrivers = async () => {
        try {
            const { data } = await api.get('/admin/delivery/drivers?limit=200');
            setDrivers(data.drivers || []);
            if (data.stats) setDriverStats(data.stats);
        } catch (error) {
            console.error("Erreur livreurs:", error);
        } finally {
            setDriverLoading(false);
        }
    };

    const fetchApplications = async () => {
        try {
            const { data } = await api.get('/admin/delivery/applications?limit=200');
            setApplications(data.applications || []);
            if (data.stats) setAppStats(data.stats);
        } catch (error) {
            console.error("Erreur candidatures:", error);
        } finally {
            setAppLoading(false);
        }
    };

    /* ─── Driver Actions ─── */

    const toggleSuspend = async (driver) => {
        const action = driver.is_suspended ? 'réactiver' : 'suspendre';
        if (!window.confirm(`Voulez-vous ${action} ce livreur ?`)) return;
        try {
            const { data } = await api.patch(`/admin/delivery/drivers/${driver.id}/toggle`);
            setDrivers(drivers.map(d => d.id === driver.id ? { ...d, is_suspended: data.is_suspended } : d));
        } catch (err) { console.error(err); alert("Erreur"); }
    };

    const toggleVerify = async (driver) => {
        try {
            const { data } = await api.patch(`/admin/delivery/drivers/${driver.id}/verify`);
            setDrivers(drivers.map(d => d.id === driver.id ? { ...d, is_verified: data.is_verified } : d));
        } catch (err) { console.error(err); alert("Erreur"); }
    };

    /* ─── Application Actions ─── */

    const approveApplication = async (app) => {
        if (!window.confirm(`Approuver la candidature de ${app.name || 'ce candidat'} ? Il deviendra livreur.`)) return;
        setActionLoading(app.id);
        try {
            await api.patch(`/admin/delivery/applications/${app.id}/approve`);
            await fetchApplications();
            await fetchDrivers(); // Refresh drivers since a new one was added
        } catch (err) {
            console.error(err);
            alert("Erreur lors de l'approbation");
        } finally {
            setActionLoading(null);
        }
    };

    const rejectApplication = async (app) => {
        const note = window.prompt(`Raison du rejet pour ${app.name || 'ce candidat'} (optionnel) :`);
        if (note === null) return; // User cancelled
        setActionLoading(app.id);
        try {
            await api.patch(`/admin/delivery/applications/${app.id}/reject`, { admin_note: note || undefined });
            await fetchApplications();
        } catch (err) {
            console.error(err);
            alert("Erreur lors du rejet");
        } finally {
            setActionLoading(null);
        }
    };

    /* ─── Filtered Lists ─── */

    const filteredDrivers = useMemo(() => {
        let list = drivers;
        if (driverFilter === 'active') list = list.filter(d => !d.is_suspended);
        if (driverFilter === 'verified') list = list.filter(d => d.is_verified);
        if (driverFilter === 'suspended') list = list.filter(d => d.is_suspended);
        if (driverSearch) {
            const s = driverSearch.toLowerCase();
            list = list.filter(d =>
                d.name?.toLowerCase().includes(s) ||
                d.phone?.includes(s) ||
                d.email?.toLowerCase().includes(s)
            );
        }
        return list;
    }, [drivers, driverFilter, driverSearch]);

    const filteredApplications = useMemo(() => {
        let list = applications;
        if (appFilter !== 'all') list = list.filter(a => a.status === appFilter);
        if (appSearch) {
            const s = appSearch.toLowerCase();
            list = list.filter(a =>
                a.name?.toLowerCase().includes(s) ||
                a.phone?.includes(s) ||
                a.email?.toLowerCase().includes(s)
            );
        }
        return list;
    }, [applications, appFilter, appSearch]);

    /* ─── Helpers ─── */

    const timeAgo = (date) => {
        if (!date) return 'Jamais';
        const diff = Date.now() - new Date(date).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 60) return `${mins} min`;
        const hours = Math.floor(mins / 60);
        if (hours < 24) return `${hours}h`;
        const days = Math.floor(hours / 24);
        return `${days}j`;
    };

    const formatDate = (date) => {
        if (!date) return '—';
        return new Date(date).toLocaleDateString('fr-FR', {
            day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
        });
    };

    const statusBadge = (status) => {
        const map = {
            pending: { bg: 'bg-yellow-100 text-yellow-700', label: '⏳ En attente' },
            approved: { bg: 'bg-green-100 text-green-700', label: '✅ Approuvée' },
            rejected: { bg: 'bg-red-100 text-red-700', label: '❌ Rejetée' },
        };
        const s = map[status] || map.pending;
        return <span className={`inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full ${s.bg}`}>{s.label}</span>;
    };

    /* ─── Loading ─── */

    const isLoading = (tab === 'drivers' && driverLoading) || (tab === 'applications' && appLoading);
    if (isLoading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Livreurs</h1>
                    <p className="text-sm text-gray-400 mt-1">Gestion et suivi des livreurs partenaires</p>
                </div>
                <div className="relative">
                    <MagnifyingGlassIcon className="h-5 w-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input type="text" placeholder="Rechercher nom, téléphone..."
                        className="pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm w-72 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        value={tab === 'drivers' ? driverSearch : appSearch}
                        onChange={(e) => tab === 'drivers' ? setDriverSearch(e.target.value) : setAppSearch(e.target.value)} />
                </div>
            </div>

            {/* Tabs */}
            <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
                <button
                    onClick={() => setTab('drivers')}
                    className={`px-5 py-2.5 rounded-lg text-sm font-semibold transition-all flex items-center gap-2 ${tab === 'drivers' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                        }`}
                >
                    <TruckIcon className="h-4 w-4" />
                    Livreurs
                    <span className={`text-xs px-1.5 py-0.5 rounded-full ${tab === 'drivers' ? 'bg-blue-100 text-blue-700' : 'bg-gray-200 text-gray-500'}`}>
                        {driverStats.total}
                    </span>
                </button>
                <button
                    onClick={() => setTab('applications')}
                    className={`px-5 py-2.5 rounded-lg text-sm font-semibold transition-all flex items-center gap-2 ${tab === 'applications' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                        }`}
                >
                    <ClipboardDocumentListIcon className="h-4 w-4" />
                    Candidatures
                    {appStats.pending > 0 && (
                        <span className="text-xs px-1.5 py-0.5 rounded-full bg-red-500 text-white animate-pulse">
                            {appStats.pending}
                        </span>
                    )}
                </button>
            </div>

            {/* ════════════════════════════════════════ DRIVERS TAB ════════════════════════════════════════ */}
            {tab === 'drivers' && (
                <>
                    {/* Stats */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <StatCard label="Total" value={driverStats.total} icon={UserGroupIcon} color="blue" />
                        <StatCard label="Actifs" value={driverStats.active} icon={TruckIcon} color="green" />
                        <StatCard label="Vérifiés" value={driverStats.verified} icon={CheckBadgeIcon} color="amber" />
                        <StatCard label="Suspendus" value={driverStats.suspended} icon={NoSymbolIcon} color="red" />
                    </div>

                    {/* Filters */}
                    <div className="flex gap-2 flex-wrap">
                        <FilterPill label="Tous" count={driverStats.total} active={driverFilter === 'all'} onClick={() => setDriverFilter('all')} />
                        <FilterPill label="✓ Actifs" count={driverStats.active} active={driverFilter === 'active'} onClick={() => setDriverFilter('active')} />
                        <FilterPill label="✅ Vérifiés" count={driverStats.verified} active={driverFilter === 'verified'} onClick={() => setDriverFilter('verified')} />
                        <FilterPill label="⛔ Suspendus" count={driverStats.suspended} active={driverFilter === 'suspended'} onClick={() => setDriverFilter('suspended')} />
                    </div>

                    {/* Drivers Table */}
                    {filteredDrivers.length === 0 ? (
                        <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
                            <TruckIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                            <p className="text-gray-500 font-medium">Aucun livreur trouvé</p>
                            <p className="text-gray-400 text-sm mt-1">Les utilisateurs approuvés comme livreurs apparaîtront ici</p>
                        </div>
                    ) : (
                        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                            <div className="grid grid-cols-12 gap-4 px-6 py-4 bg-gray-50 border-b border-gray-100 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                                <div className="col-span-3">Livreur</div>
                                <div className="col-span-2 text-center">Livraisons</div>
                                <div className="col-span-1 text-center">En cours</div>
                                <div className="col-span-1 text-center">Vérifié</div>
                                <div className="col-span-1 text-center">Statut</div>
                                <div className="col-span-2 text-center">Dernière activité</div>
                                <div className="col-span-2 text-center">Actions</div>
                            </div>
                            <div className="divide-y divide-gray-50">
                                {filteredDrivers.map((driver) => (
                                    <div key={driver.id} className="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-gray-50 transition">
                                        <div className="col-span-3">
                                            <Link to={`/users/${driver.id}`} className="flex items-center gap-3 hover:opacity-80 transition">
                                                <img
                                                    src={driver.avatar_url || `https://ui-avatars.com/api/?name=${driver.name || 'L'}&background=0B1727&color=fff&size=64`}
                                                    className="w-10 h-10 rounded-full object-cover flex-shrink-0 border border-gray-100"
                                                    alt=""
                                                    onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${driver.name || 'L'}&background=0B1727&color=fff`; }}
                                                />
                                                <div className="min-w-0">
                                                    <p className="text-sm font-semibold text-blue-600 truncate">{driver.name || 'Sans nom'}</p>
                                                    <p className="text-xs text-gray-400 truncate">{driver.phone}</p>
                                                </div>
                                            </Link>
                                        </div>
                                        <div className="col-span-2 text-center">
                                            <p className="text-sm font-bold text-gray-900">{driver.completed_deliveries || 0}</p>
                                            <p className="text-xs text-gray-400">terminées</p>
                                        </div>
                                        <div className="col-span-1 text-center">
                                            {parseInt(driver.active_deliveries) > 0 ? (
                                                <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-700">{driver.active_deliveries}</span>
                                            ) : (
                                                <span className="text-xs text-gray-300">0</span>
                                            )}
                                        </div>
                                        <div className="col-span-1 text-center">
                                            {driver.is_verified ? (
                                                <CheckBadgeIcon className="h-5 w-5 text-green-500 mx-auto" />
                                            ) : (
                                                <span className="text-xs text-gray-300">—</span>
                                            )}
                                        </div>
                                        <div className="col-span-1 text-center">
                                            {driver.is_suspended ? (
                                                <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-700">Suspendu</span>
                                            ) : (
                                                <span className="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-700">Actif</span>
                                            )}
                                        </div>
                                        <div className="col-span-2 text-center">
                                            <p className="text-xs text-gray-400">
                                                {driver.last_active ? `Il y a ${timeAgo(driver.last_active)}` : 'Jamais connecté'}
                                            </p>
                                        </div>
                                        <div className="col-span-2 flex justify-center gap-1.5">
                                            <button onClick={() => toggleVerify(driver)}
                                                className={`p-2 rounded-lg transition ${driver.is_verified ? 'bg-green-100 text-green-600 hover:bg-green-200' : 'bg-gray-100 text-gray-400 hover:bg-gray-200'}`}
                                                title={driver.is_verified ? 'Retirer vérification' : 'Vérifier'}
                                            >
                                                <ShieldCheckIcon className="h-4 w-4" />
                                            </button>
                                            <button onClick={() => toggleSuspend(driver)}
                                                className={`p-2 rounded-lg transition ${driver.is_suspended ? 'bg-amber-100 text-amber-600 hover:bg-amber-200' : 'bg-gray-100 text-red-400 hover:bg-red-100 hover:text-red-600'}`}
                                                title={driver.is_suspended ? 'Réactiver' : 'Suspendre'}
                                            >
                                                {driver.is_suspended ? (
                                                    <CheckCircleIcon className="h-4 w-4" />
                                                ) : (
                                                    <XCircleIcon className="h-4 w-4" />
                                                )}
                                            </button>
                                            <Link to={`/users/${driver.id}`}
                                                className="p-2 rounded-lg bg-gray-100 text-blue-500 hover:bg-blue-100 transition"
                                                title="Voir profil"
                                            >
                                                <UserGroupIcon className="h-4 w-4" />
                                            </Link>
                                        </div>
                                    </div>
                                ))}
                            </div>
                            <div className="px-6 py-3 bg-gray-50 border-t border-gray-100 text-xs text-gray-400 text-right">
                                {filteredDrivers.length} livreur{filteredDrivers.length > 1 ? 's' : ''} affiché{filteredDrivers.length > 1 ? 's' : ''}
                            </div>
                        </div>
                    )}
                </>
            )}

            {/* ════════════════════════════════════ APPLICATIONS TAB ═══════════════════════════════════ */}
            {tab === 'applications' && (
                <>
                    {/* Stats */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <StatCard label="Total" value={appStats.total} icon={ClipboardDocumentListIcon} color="blue" />
                        <StatCard label="En attente" value={appStats.pending} icon={ClockIcon} color="amber" />
                        <StatCard label="Approuvées" value={appStats.approved} icon={CheckCircleIcon} color="green" />
                        <StatCard label="Rejetées" value={appStats.rejected} icon={XCircleIcon} color="red" />
                    </div>

                    {/* Filters */}
                    <div className="flex gap-2 flex-wrap">
                        <FilterPill label="Toutes" count={appStats.total} active={appFilter === 'all'} onClick={() => setAppFilter('all')} />
                        <FilterPill label="⏳ En attente" count={appStats.pending} active={appFilter === 'pending'} onClick={() => setAppFilter('pending')} />
                        <FilterPill label="✅ Approuvées" count={appStats.approved} active={appFilter === 'approved'} onClick={() => setAppFilter('approved')} />
                        <FilterPill label="❌ Rejetées" count={appStats.rejected} active={appFilter === 'rejected'} onClick={() => setAppFilter('rejected')} />
                    </div>

                    {/* Applications List */}
                    {filteredApplications.length === 0 ? (
                        <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
                            <ClipboardDocumentListIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                            <p className="text-gray-500 font-medium">Aucune candidature trouvée</p>
                            <p className="text-gray-400 text-sm mt-1">Les candidatures soumises depuis l'app de livraison apparaîtront ici</p>
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {filteredApplications.map((app) => (
                                <div key={app.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition">
                                    <div className="flex flex-col md:flex-row md:items-center gap-4">
                                        {/* Candidate Info */}
                                        <div className="flex items-center gap-3 flex-1 min-w-0">
                                            <img
                                                src={app.avatar_url || `https://ui-avatars.com/api/?name=${app.name || 'C'}&background=0B1727&color=fff&size=64`}
                                                className="w-12 h-12 rounded-full object-cover flex-shrink-0 border-2 border-gray-100"
                                                alt=""
                                                onError={(e) => { e.target.onerror = null; e.target.src = `https://ui-avatars.com/api/?name=${app.name || 'C'}&background=0B1727&color=fff`; }}
                                            />
                                            <div className="min-w-0">
                                                <Link to={`/users/${app.user_id}`} className="text-sm font-semibold text-blue-600 hover:underline truncate block">
                                                    {app.name || 'Sans nom'}
                                                </Link>
                                                <p className="text-xs text-gray-400 truncate">{app.phone || app.app_phone}</p>
                                                {app.email && <p className="text-xs text-gray-400 truncate">{app.email}</p>}
                                            </div>
                                        </div>

                                        {/* Pledge Amount */}
                                        <div className="text-center px-4">
                                            <p className="text-lg font-bold text-gray-900">${parseFloat(app.pledge_amount || 0).toFixed(2)}</p>
                                            <p className="text-xs text-gray-400">Gage</p>
                                        </div>

                                        {/* Status */}
                                        <div className="text-center px-4">
                                            {statusBadge(app.status)}
                                        </div>

                                        {/* Date */}
                                        <div className="text-center px-4">
                                            <p className="text-xs text-gray-400">{formatDate(app.created_at)}</p>
                                            {app.reviewed_at && (
                                                <p className="text-xs text-gray-300 mt-0.5">Traité: {formatDate(app.reviewed_at)}</p>
                                            )}
                                        </div>

                                        {/* Actions */}
                                        <div className="flex gap-2 flex-shrink-0">
                                            {app.status === 'pending' && (
                                                <>
                                                    <button
                                                        onClick={() => approveApplication(app)}
                                                        disabled={actionLoading === app.id}
                                                        className="px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-lg hover:bg-green-700 transition disabled:opacity-50 flex items-center gap-1.5"
                                                    >
                                                        {actionLoading === app.id ? (
                                                            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                                        ) : (
                                                            <CheckCircleIcon className="h-4 w-4" />
                                                        )}
                                                        Approuver
                                                    </button>
                                                    <button
                                                        onClick={() => rejectApplication(app)}
                                                        disabled={actionLoading === app.id}
                                                        className="px-4 py-2 bg-red-50 text-red-600 text-sm font-medium rounded-lg hover:bg-red-100 transition disabled:opacity-50 flex items-center gap-1.5"
                                                    >
                                                        <XCircleIcon className="h-4 w-4" />
                                                        Rejeter
                                                    </button>
                                                </>
                                            )}
                                            {app.status !== 'pending' && (
                                                <Link to={`/users/${app.user_id}`}
                                                    className="px-4 py-2 bg-gray-100 text-gray-600 text-sm font-medium rounded-lg hover:bg-gray-200 transition flex items-center gap-1.5"
                                                >
                                                    <UserGroupIcon className="h-4 w-4" />
                                                    Voir profil
                                                </Link>
                                            )}
                                        </div>
                                    </div>

                                    {/* Motivation */}
                                    {app.motivation && (
                                        <div className="mt-3 pt-3 border-t border-gray-100">
                                            <p className="text-xs text-gray-400 mb-1">Motivation :</p>
                                            <p className="text-sm text-gray-600 italic">"{app.motivation}"</p>
                                        </div>
                                    )}

                                    {/* Admin Note */}
                                    {app.admin_note && app.status !== 'pending' && (
                                        <div className="mt-2 px-3 py-2 bg-gray-50 rounded-lg">
                                            <p className="text-xs text-gray-400">Note admin : <span className="text-gray-600">{app.admin_note}</span></p>
                                        </div>
                                    )}
                                </div>
                            ))}

                            <div className="text-xs text-gray-400 text-right py-2">
                                {filteredApplications.length} candidature{filteredApplications.length > 1 ? 's' : ''} affichée{filteredApplications.length > 1 ? 's' : ''}
                            </div>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}
