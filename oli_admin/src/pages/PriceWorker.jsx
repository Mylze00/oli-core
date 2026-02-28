import { useState, useEffect } from 'react';
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
        orange: 'bg-orange-50 text-orange-700 border-orange-200',
    };
    return (
        <div className={`rounded-xl border px-4 py-3 ${colors[color] || colors.blue}`}>
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

    const [analysisData, setAnalysisData] = useState([]);
    const [analysisStats, setAnalysisStats] = useState({});
    const [analysisFilter, setAnalysisFilter] = useState('');

    const fetchAnalysis = async () => {
        setLoadingKey('analysis', true);
        try {
            const url = analysisFilter ? `/api/price-strategy/analysis?statut=${analysisFilter}` : '/api/price-strategy/analysis';
            const res = await api.get(url);
            setAnalysisData(res.data.data || []);
            if (res.data.stats) setAnalysisStats(res.data.stats);
        } catch (err) {
            console.error(err);
        }
        setLoadingKey('analysis', false);
    };

    useEffect(() => {
        fetchAnalysis();
    }, [analysisFilter]);


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
        if (!window.confirm('⚠️ Lancer l\'analyse des prix OLI admin ? ')) return;
        setWorkerRunning(true);
        setWorkerResult(null);
        try {
            const res = await api.post('/api/price-worker/run');
            // Le backend attend la fin et retourne les stats directement
            setWorkerResult(res.data.stats || res.data);
            setTimeout(fetchAnalysis, 2000);
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
        if (!window.confirm('⚠️ Restaurer les prix depuis le CSV ? Cette action modifiera les prix en production.')) return;
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
        if (!window.confirm('⚠️ Rollback : remettre les prix modifiés aujourd\\'hui à $1 ? ')) return;
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
                    <h1 className="text-2xl font-bold text-gray-900">Worker Intelligence Prix</h1>
                    <p className="text-sm text-gray-500">Analyse automatisée avec matching scraper Alibaba / Aliexpress</p>
                </div>
            </div>

            {/* Grid principale */}
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">

                {/* ═══ SECTION 1: Worker Stats & Run ═══ */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-5 border-b border-gray-100 flex items-center justify-between">
                        <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                            <PlayIcon className="h-5 w-5 text-green-600" />
                            Lancer l'Analyse (OLI Admin)
                        </h2>
                        <button
                            onClick={fetchStats}
                            disabled={loading.stats}
                            className="text-sm text-blue-600 hover:text-blue-800 font-medium"
                        >
                            {loading.stats ? 'Chargement...' : '↻ Stats Worker'}
                        </button>
                    </div>
                    <div className="p-5">
                        <p className="text-sm text-gray-500 mb-4">
                            Ce worker analyse les prix des produits OLI Admin (marge, frais livraison) et croise les données avec les scrapings. <strong>Ce worker ne modifie AUCUN PRiX en base de données. Il pond des analyses de rentabilité.</strong>
                        </p>

                        {/* Stats existantes */}
                        {workerStats && !workerStats.error && (
                            <div className="grid grid-cols-3 gap-3 mb-4">
                                <StatBox label="Total admin" value={workerStats.total || '-'} color="blue" />
                                <StatBox label="Dernier run" value={workerStats.lastRun ? workerStats.lastRun.traites : '-'} color="green" />
                                <StatBox label="Running" value={workerStats.isRunning ? 'Oui' : 'Non'} color={workerStats.isRunning ? 'amber' : 'gray'} />
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
                                    Analyse en cours... (peut durer ~1min)
                                </span>
                            ) : (
                                <span className="flex items-center justify-center gap-2">
                                    <PlayIcon className="h-5 w-5" />
                                    Scanner et Analyser
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
                                        <div className="flex items-center gap-2 mb-3">
                                            <CheckCircleIcon className="h-5 w-5 text-green-600" />
                                            <span className="font-semibold text-green-800">Worker terminé ! ({workerResult.duree_secondes || 0}s)</span>
                                        </div>
                                        <div className="grid grid-cols-3 gap-2 text-sm">
                                            <div className="bg-white rounded-lg p-2 text-center border border-green-200">
                                                <div className="text-xs text-gray-500">Traités</div>
                                                <div className="font-bold text-gray-900">{workerResult.traites ?? '-'}<span className="text-xs font-normal text-gray-400">/{workerResult.total ?? '?'}</span></div>
                                            </div>
                                            <div className="bg-white rounded-lg p-2 text-center border border-red-200">
                                                <div className="text-xs text-gray-500">Aberrants</div>
                                                <div className="font-bold text-red-600">{workerResult.aberrants ?? '-'}</div>
                                            </div>
                                            <div className="bg-white rounded-lg p-2 text-center border border-emerald-200">
                                                <div className="text-xs text-gray-500">Corrigés</div>
                                                <div className="font-bold text-emerald-600">{workerResult.corriges ?? '-'}</div>
                                            </div>
                                            <div className="bg-white rounded-lg p-2 text-center border border-orange-200">
                                                <div className="text-xs text-gray-500">Trop bas</div>
                                                <div className="font-bold text-orange-600">{workerResult.trop_bas ?? '-'}</div>
                                            </div>
                                            <div className="bg-white rounded-lg p-2 text-center border border-gray-200">
                                                <div className="text-xs text-gray-500">Inchangés</div>
                                                <div className="font-bold text-gray-600">{workerResult.inchanges ?? '-'}</div>
                                            </div>
                                            <div className="bg-white rounded-lg p-2 text-center border border-gray-200">
                                                <div className="text-xs text-gray-500">Admin ID</div>
                                                <div className="font-bold text-gray-600">#{workerResult.admin_seller_id ?? '-'}</div>
                                            </div>
                                        </div>
                                        {workerResult.crash && (
                                            <p className="text-red-600 text-xs mt-2">⚠️ {workerResult.crash}</p>
                                        )}
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                </div>

                {/* ═══ SECTION 2: Restauration CSV (Legacy) ═══ */}
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
                    </div>
                </div>
            </div>

            {/* ═══ SECTION 3: ANALYSE INTELLIGENTE ═══ */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-6">
                <div className="p-5 border-b border-gray-100 flex items-center justify-between">
                    <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                        <CpuChipIcon className="h-5 w-5 text-indigo-600" />
                        Résultats d'Analyse des Prix concurrentiels (Tableau de bord IA)
                    </h2>
                    <button onClick={fetchAnalysis} className="text-sm text-blue-600 hover:text-blue-800 bg-blue-50 px-3 py-1 rounded-full">↻ Actualiser Vue</button>
                </div>
                <div className="p-5">
                    <div className="flex gap-4 mb-4">
                        <div className="flex-1 grid grid-flow-col auto-cols-auto gap-2">
                            <StatBox label="Tous les produits analysés" value={(analysisStats.COHERENT || 0) + (analysisStats.TROP_CHER || 0) + (analysisStats.TROP_BAS || 0) + (analysisStats.SANS_MATCH || 0)} color="blue" />
                            <StatBox label="Prix Cohérent" value={analysisStats.COHERENT || 0} color="green" />
                            <StatBox label="Trop Cher / Hors marché" value={analysisStats.TROP_CHER || 0} color="red" />
                            <StatBox label="Prix Trop Bas / Marge négative" value={analysisStats.TROP_BAS || 0} color="orange" />
                            <StatBox label="Sans Match Scraper" value={analysisStats.SANS_MATCH || 0} color="amber" />
                        </div>
                    </div>

                    <div className="flex gap-2 mb-4">
                        <button onClick={() => setAnalysisFilter('')} className={`px-4 py-2 rounded-lg text-sm font-medium ${!analysisFilter ? 'bg-gray-800 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>Tous</button>
                        <button onClick={() => setAnalysisFilter('COHERENT')} className={`px-4 py-2 rounded-lg text-sm font-medium ${analysisFilter === 'COHERENT' ? 'bg-green-600 text-white' : 'bg-green-50 text-green-700 hover:bg-green-100'}`}>Cohérents</button>
                        <button onClick={() => setAnalysisFilter('TROP_CHER')} className={`px-4 py-2 rounded-lg text-sm font-medium ${analysisFilter === 'TROP_CHER' ? 'bg-red-600 text-white' : 'bg-red-50 text-red-700 hover:bg-red-100'}`}>Trop cher</button>
                        <button onClick={() => setAnalysisFilter('TROP_BAS')} className={`px-4 py-2 rounded-lg text-sm font-medium ${analysisFilter === 'TROP_BAS' ? 'bg-orange-600 text-white' : 'bg-orange-50 text-orange-700 hover:bg-orange-100'}`}>Trop bas</button>
                        <button onClick={() => setAnalysisFilter('SANS_MATCH')} className={`px-4 py-2 rounded-lg text-sm font-medium ${analysisFilter === 'SANS_MATCH' ? 'bg-amber-600 text-white' : 'bg-amber-50 text-amber-700 hover:bg-amber-100'}`}>Sans match</button>
                    </div>

                    <div className="max-h-[500px] overflow-y-auto border border-gray-200 rounded-lg">
                        <table className="w-full text-sm text-left">
                            <thead className="bg-gray-50 sticky top-0 shadow-sm z-10">
                                <tr>
                                    <th className="px-4 py-3 font-medium text-gray-500">ID</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 w-[20%]">Produit OLI</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 w-[25%]">Match Scraper</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Prix OLI</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Coût estimé</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Marge %</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Reco Prix</th>
                                    <th className="px-4 py-3 font-medium text-gray-500 text-center">Diagnostics</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {loading.analysis ? (
                                    <tr><td colSpan="8" className="text-center py-8 text-gray-500">Chargement de l'analyse...</td></tr>
                                ) : analysisData.length === 0 ? (
                                    <tr><td colSpan="8" className="text-center py-8 text-gray-500">Aucun résultat trouvé. Veuillez scanner les prix d'abord.</td></tr>
                                ) : analysisData.map((row) => (
                                    <tr key={row.id} className="hover:bg-gray-50">
                                        <td className="px-4 py-3 text-gray-500">#{row.product_id}</td>
                                        <td className="px-4 py-3 font-medium overflow-hidden text-ellipsis line-clamp-2" title={row.product_name}>{row.product_name}</td>
                                        <td className="px-4 py-3 text-xs text-gray-500" title={row.match_title}>
                                            {row.match_title ? (
                                                <div className="line-clamp-2">{row.match_title} <span className="bg-gray-100 px-1 rounded ml-1 whitespace-nowrap" title="Mots en commun matching">(score: {row.match_score})</span></div>
                                            ) : '-'}
                                        </td>
                                        <td className="px-4 py-3 text-right font-medium text-blue-700">${parseFloat(row.prix_oli).toFixed(2)}</td>
                                        <td className="px-4 py-3 text-right text-gray-500">
                                            {row.prix_scraper ? <><span title="Prix source">${parseFloat(row.prix_scraper).toFixed(2)}</span><br /><span className="text-[10px] text-gray-400" title="Livraison calculée">+${parseFloat(row.frais_livraison).toFixed(2)} DDP</span></> : '-'}
                                        </td>
                                        <td className="px-4 py-3 text-right">
                                            {row.statut !== 'SANS_MATCH' && (
                                                <span className={`font-bold ${parseFloat(row.marge_pct) < 20 ? 'text-red-600' : 'text-green-600'}`}>
                                                    {row.marge_pct ? parseFloat(row.marge_pct).toFixed(0) + '%' : '-'}
                                                </span>
                                            )}
                                        </td>
                                        <td className="px-4 py-3 text-right">
                                            {row.suggestion_prix ? <span className="text-gray-900 border-b border-dashed border-gray-400 font-mono">${parseFloat(row.suggestion_prix).toFixed(2)}</span> : '-'}
                                        </td>
                                        <td className="px-4 py-3 text-center">
                                            <span className={`inline-block px-2 py-1 rounded text-xs font-bold
                                                ${row.statut === 'COHERENT' ? 'bg-green-100 text-green-800'
                                                    : row.statut === 'TROP_CHER' ? 'bg-red-100 text-red-800'
                                                        : row.statut === 'TROP_BAS' ? 'bg-orange-100 text-orange-800'
                                                            : 'bg-gray-100 text-gray-600 border border-gray-200'}`}>
                                                {row.statut}
                                            </span>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            {/* ═══ SECTION 4: Rollback (Legacy) ═══ */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-5 border-b border-gray-100">
                    <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                        <ExclamationTriangleIcon className="h-5 w-5 text-amber-600" />
                        Rollback d'Urgence (Produits modifiés)
                    </h2>
                </div>
                <div className="p-5">
                    <p className="text-sm text-gray-500 mb-4">
                        Détecte tous les produits <strong>non-OLI</strong> qui ont été modifiés aujourd'hui et permet de remettre leur prix à $1. Outil utilisé suite au bug d'import FC vers USD.
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
                </div>
            </div>

        </div>
    );
}
