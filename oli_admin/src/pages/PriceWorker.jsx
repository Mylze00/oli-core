import { useState } from 'react';
import api from '../services/api';
import {
    CpuChipIcon,
    PlayIcon,
    ArrowPathIcon,
    DocumentTextIcon,
    CheckCircleIcon,
    ExclamationTriangleIcon,
} from '@heroicons/react/24/outline';

function StatBox({ label, value, color = 'blue' }) {
    const colors = {
        blue: 'bg-blue-50 text-blue-700 border-blue-200',
        green: 'bg-green-50 text-green-700 border-green-200',
        amber: 'bg-amber-50 text-amber-700 border-amber-200',
        red: 'bg-red-50 text-red-700 border-red-200',
        violet: 'bg-violet-50 text-violet-700 border-violet-200',
        cyan: 'bg-cyan-50 text-cyan-700 border-cyan-200',
    };
    return (
        <div className={`rounded-xl border px-4 py-3 ${colors[color]}`}>
            <div className="text-xs font-medium opacity-70">{label}</div>
            <div className="text-2xl font-bold mt-1">{value}</div>
        </div>
    );
}

export default function PriceWorker() {
    const [workerStats, setWorkerStats] = useState(null);
    const [workerRunning, setWorkerRunning] = useState(false);
    const [workerResult, setWorkerResult] = useState(null);
    const [restorePreview, setRestorePreview] = useState(null);
    const [restoreApplied, setRestoreApplied] = useState(false);
    const [rollbackPreview, setRollbackPreview] = useState(null);
    const [loading, setLoading] = useState({});
    const [tauxChange, setTauxChange] = useState(2800);

    const setLoadingKey = (key, val) => setLoading(prev => ({ ...prev, [key]: val }));

    // Récupérer les stats du worker
    const fetchStats = async () => {
        setLoadingKey('stats', true);
        try {
            const res = await api.get('/api/price-worker/stats');
            setWorkerStats(res.data);
        } catch (err) {
            console.error(err);
            setWorkerStats({ error: err.response?.data?.error || err.message });
        }
        setLoadingKey('stats', false);
    };

    // Lancer le worker (produits OLI admin uniquement)
    const runWorker = async () => {
        if (!confirm('⚠️ Lancer le worker de correction prix sur les produits OLI admin ?')) return;
        setWorkerRunning(true);
        setWorkerResult(null);
        try {
            const res = await api.post('/api/price-worker/run');
            setWorkerResult(res.data);
        } catch (err) {
            setWorkerResult({ error: err.response?.data?.error || err.message });
        }
        setWorkerRunning(false);
    };

    // Preview restauration CSV
    const previewRestoreCSV = async () => {
        setLoadingKey('restore', true);
        try {
            const res = await api.post('/api/price-strategy/restore-csv', {
                apply: false,
                taux_change: tauxChange,
            });
            setRestorePreview(res.data);
            setRestoreApplied(false);
        } catch (err) {
            setRestorePreview({ error: err.response?.data?.error || err.message });
        }
        setLoadingKey('restore', false);
    };

    // Appliquer restauration CSV
    const applyRestoreCSV = async () => {
        if (!confirm('⚠️ Restaurer les prix depuis le CSV ? Cette action modifiera les prix en production.')) return;
        setLoadingKey('restore', true);
        try {
            const res = await api.post('/api/price-strategy/restore-csv', {
                apply: true,
                taux_change: tauxChange,
            });
            setRestorePreview(res.data);
            setRestoreApplied(true);
        } catch (err) {
            setRestorePreview({ error: err.response?.data?.error || err.message });
        }
        setLoadingKey('restore', false);
    };

    // Preview rollback
    const previewRollback = async () => {
        setLoadingKey('rollback', true);
        try {
            const res = await api.post('/api/price-strategy/rollback', {
                apply_rollback: false,
            });
            setRollbackPreview(res.data);
        } catch (err) {
            setRollbackPreview({ error: err.response?.data?.error || err.message });
        }
        setLoadingKey('rollback', false);
    };

    // Appliquer rollback
    const applyRollback = async () => {
        if (!confirm('⚠️ Rollback : remettre les prix modifiés aujourd\'hui à $1 ?')) return;
        setLoadingKey('rollback', true);
        try {
            const res = await api.post('/api/price-strategy/rollback', {
                apply_rollback: true,
                restore_price: 1,
            });
            setRollbackPreview(res.data);
        } catch (err) {
            setRollbackPreview({ error: err.response?.data?.error || err.message });
        }
        setLoadingKey('rollback', false);
    };

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="flex items-center gap-3 mb-8">
                <CpuChipIcon className="h-8 w-8 text-blue-600" />
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Worker de Prix</h1>
                    <p className="text-sm text-gray-500">Gestion et contrôle de la correction automatique des prix</p>
                </div>
            </div>

            {/* Grid principale */}
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">

                {/* ═══ SECTION 1: Worker Stats & Run ═══ */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-5 border-b border-gray-100 flex items-center justify-between">
                        <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                            <PlayIcon className="h-5 w-5 text-green-600" />
                            Worker Prix (OLI Admin)
                        </h2>
                        <button
                            onClick={fetchStats}
                            disabled={loading.stats}
                            className="text-sm text-blue-600 hover:text-blue-800 font-medium"
                        >
                            {loading.stats ? 'Chargement...' : '↻ Charger Stats'}
                        </button>
                    </div>
                    <div className="p-5">
                        <p className="text-sm text-gray-500 mb-4">
                            Ce worker analyse les prix des produits du compte <strong>OLI admin</strong> et corrige
                            les prix aberrants (FC→USD, trop bas, recalcul marge 35%).
                        </p>

                        {/* Stats existantes */}
                        {workerStats && !workerStats.error && (
                            <div className="grid grid-cols-3 gap-3 mb-4">
                                <StatBox label="Total produits" value={workerStats.total || '-'} color="blue" />
                                <StatBox label="Corrigés" value={workerStats.corriges || '-'} color="green" />
                                <StatBox label="Aberrants" value={workerStats.aberrants || '-'} color="amber" />
                                <StatBox label="Trop bas" value={workerStats.trop_bas || '-'} color="red" />
                                <StatBox label="Inchangés" value={workerStats.inchanges || '-'} color="cyan" />
                                <StatBox label="Erreurs" value={workerStats.erreurs || '-'} color="red" />
                            </div>
                        )}
                        {workerStats?.error && (
                            <div className="bg-red-50 text-red-700 p-3 rounded-lg mb-4 text-sm">
                                ❌ {workerStats.error}
                            </div>
                        )}

                        {/* Bouton Run */}
                        <button
                            onClick={runWorker}
                            disabled={workerRunning}
                            className={`w-full py-3 px-4 rounded-xl font-semibold text-white transition-all ${workerRunning
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 shadow-lg hover:shadow-xl'
                                }`}
                        >
                            {workerRunning ? (
                                <span className="flex items-center justify-center gap-2">
                                    <ArrowPathIcon className="h-5 w-5 animate-spin" />
                                    Worker en cours... (peut durer ~2min)
                                </span>
                            ) : (
                                <span className="flex items-center justify-center gap-2">
                                    <PlayIcon className="h-5 w-5" />
                                    Lancer le Worker (OLI Admin)
                                </span>
                            )}
                        </button>

                        {/* Résultat du worker */}
                        {workerResult && (
                            <div className={`mt-4 p-4 rounded-xl border ${workerResult.error ? 'bg-red-50 border-red-200' : 'bg-green-50 border-green-200'}`}>
                                {workerResult.error ? (
                                    <p className="text-red-700 text-sm">❌ {workerResult.error}</p>
                                ) : (
                                    <div>
                                        <div className="flex items-center gap-2 mb-2">
                                            <CheckCircleIcon className="h-5 w-5 text-green-600" />
                                            <span className="font-semibold text-green-800">Worker terminé !</span>
                                        </div>
                                        <div className="grid grid-cols-2 gap-2 text-sm text-green-700">
                                            <span>Traités: <strong>{workerResult.stats?.traites || 0}</strong></span>
                                            <span>Corrigés: <strong>{workerResult.stats?.corriges || 0}</strong></span>
                                            <span>Aberrants: <strong>{workerResult.stats?.aberrants || 0}</strong></span>
                                            <span>Trop bas: <strong>{workerResult.stats?.trop_bas || 0}</strong></span>
                                            <span>Admin ID: <strong>{workerResult.stats?.admin_seller_id || '-'}</strong></span>
                                            <span>Durée: <strong>{workerResult.stats?.duree_secondes || 0}s</strong></span>
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                </div>

                {/* ═══ SECTION 2: Restauration CSV ═══ */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-5 border-b border-gray-100">
                        <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                            <DocumentTextIcon className="h-5 w-5 text-violet-600" />
                            Restauration Prix CSV
                        </h2>
                    </div>
                    <div className="p-5">
                        <p className="text-sm text-gray-500 mb-4">
                            Restaurer les prix depuis le fichier CSV original <code className="bg-gray-100 px-1 rounded">import_boutique_shoppi.csv</code>.
                            Les prix FC sont convertis en USD.
                        </p>

                        {/* Taux de change */}
                        <div className="flex items-center gap-3 mb-4">
                            <label className="text-sm font-medium text-gray-700">Taux de change :</label>
                            <input
                                type="number"
                                value={tauxChange}
                                onChange={(e) => setTauxChange(Number(e.target.value))}
                                className="w-28 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500"
                            />
                            <span className="text-xs text-gray-400">1 USD = {tauxChange} FC</span>
                        </div>

                        <div className="flex gap-3 mb-4">
                            <button
                                onClick={previewRestoreCSV}
                                disabled={loading.restore}
                                className="flex-1 py-2.5 px-4 bg-violet-100 text-violet-700 rounded-xl font-medium hover:bg-violet-200 transition-colors text-sm"
                            >
                                {loading.restore ? '⏳ Analyse...' : '🔍 Aperçu'}
                            </button>
                            <button
                                onClick={applyRestoreCSV}
                                disabled={loading.restore || !restorePreview || restorePreview.error}
                                className="flex-1 py-2.5 px-4 bg-violet-600 text-white rounded-xl font-medium hover:bg-violet-700 transition-colors text-sm disabled:opacity-50"
                            >
                                ✅ Appliquer
                            </button>
                        </div>

                        {/* Résultat restauration */}
                        {restorePreview && !restorePreview.error && (
                            <div className={`p-4 rounded-xl border ${restoreApplied ? 'bg-green-50 border-green-200' : 'bg-violet-50 border-violet-200'}`}>
                                <div className="grid grid-cols-2 gap-2 text-sm mb-3">
                                    <span>CSV total: <strong>{restorePreview.csv_total}</strong></span>
                                    <span>Matchés: <strong>{restorePreview.matched}</strong></span>
                                    <span>À corriger: <strong>{restorePreview.a_mettre_a_jour}</strong></span>
                                    <span>Appliqué: <strong>{restorePreview.applied ? '✅ OUI' : '🔍 Non'}</strong></span>
                                </div>
                                {restorePreview.exemples?.length > 0 && (
                                    <div className="max-h-48 overflow-y-auto">
                                        <table className="w-full text-xs">
                                            <thead className="bg-gray-100">
                                                <tr>
                                                    <th className="text-left p-1.5">Produit</th>
                                                    <th className="text-right p-1.5">FC</th>
                                                    <th className="text-right p-1.5">USD CSV</th>
                                                    <th className="text-right p-1.5">Actuel</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {restorePreview.exemples.slice(0, 20).map((p, i) => (
                                                    <tr key={i} className="border-t border-gray-100">
                                                        <td className="p-1.5 truncate max-w-[180px]">{p.nom}</td>
                                                        <td className="p-1.5 text-right font-mono">{p.prix_fc?.toLocaleString()}</td>
                                                        <td className="p-1.5 text-right font-mono text-green-700">${p.prix_usd_csv}</td>
                                                        <td className="p-1.5 text-right font-mono text-red-600">${p.prix_actuel}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </div>
                        )}
                        {restorePreview?.error && (
                            <div className="bg-red-50 text-red-700 p-3 rounded-lg text-sm">❌ {restorePreview.error}</div>
                        )}
                    </div>
                </div>

                {/* ═══ SECTION 3: Rollback ═══ */}
                <div className="xl:col-span-2 bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-5 border-b border-gray-100">
                        <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                            <ExclamationTriangleIcon className="h-5 w-5 text-amber-600" />
                            Rollback (Produits non-admin modifiés aujourd'hui)
                        </h2>
                    </div>
                    <div className="p-5">
                        <p className="text-sm text-gray-500 mb-4">
                            Détecte tous les produits <strong>non-OLI</strong> qui ont été modifiés aujourd'hui et permet de remettre leur prix à $1.
                        </p>

                        <div className="flex gap-3 mb-4">
                            <button
                                onClick={previewRollback}
                                disabled={loading.rollback}
                                className="py-2.5 px-6 bg-amber-100 text-amber-700 rounded-xl font-medium hover:bg-amber-200 transition-colors text-sm"
                            >
                                {loading.rollback ? '⏳ Analyse...' : '🔍 Voir les produits affectés'}
                            </button>
                            <button
                                onClick={applyRollback}
                                disabled={loading.rollback || !rollbackPreview || rollbackPreview.error}
                                className="py-2.5 px-6 bg-red-600 text-white rounded-xl font-medium hover:bg-red-700 transition-colors text-sm disabled:opacity-50"
                            >
                                ⚠️ Appliquer Rollback ($1)
                            </button>
                        </div>

                        {rollbackPreview && !rollbackPreview.error && (
                            <div className="bg-amber-50 border border-amber-200 p-4 rounded-xl">
                                <div className="grid grid-cols-3 gap-3 mb-3">
                                    <StatBox label="Admin ID" value={rollbackPreview.admin_id || '-'} color="blue" />
                                    <StatBox label="Produits affectés" value={rollbackPreview.total_affectes || 0} color="amber" />
                                    <StatBox label="Appliqué" value={rollbackPreview.applied ? '✅ OUI' : '🔍 Non'} color={rollbackPreview.applied ? 'green' : 'cyan'} />
                                </div>
                                {rollbackPreview.par_vendeur && Object.keys(rollbackPreview.par_vendeur).length > 0 && (
                                    <div className="mb-3">
                                        <h4 className="text-sm font-medium text-gray-700 mb-2">Par vendeur :</h4>
                                        <div className="flex flex-wrap gap-2">
                                            {Object.entries(rollbackPreview.par_vendeur).map(([name, data]) => (
                                                <span key={name} className="bg-white border border-amber-300 px-3 py-1 rounded-full text-xs font-medium">
                                                    {name}: <strong>{data.count}</strong>
                                                </span>
                                            ))}
                                        </div>
                                    </div>
                                )}
                                {rollbackPreview.produits?.length > 0 && (
                                    <div className="max-h-48 overflow-y-auto">
                                        <table className="w-full text-xs">
                                            <thead className="bg-gray-100">
                                                <tr>
                                                    <th className="text-left p-1.5">ID</th>
                                                    <th className="text-left p-1.5">Produit</th>
                                                    <th className="text-right p-1.5">Prix actuel</th>
                                                    <th className="text-left p-1.5">Vendeur</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {rollbackPreview.produits.slice(0, 30).map((p, i) => (
                                                    <tr key={i} className="border-t border-gray-100">
                                                        <td className="p-1.5 font-mono">{p.id}</td>
                                                        <td className="p-1.5 truncate max-w-[200px]">{p.nom}</td>
                                                        <td className="p-1.5 text-right font-mono">{p.prix_actuel}</td>
                                                        <td className="p-1.5">{p.seller}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </div>
                        )}
                        {rollbackPreview?.error && (
                            <div className="bg-red-50 text-red-700 p-3 rounded-lg text-sm">❌ {rollbackPreview.error}</div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
