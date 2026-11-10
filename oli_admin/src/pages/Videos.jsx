import { useCallback, useEffect, useState } from 'react';
import api from '../services/api';

const FILTERS = [
    { value: 'pending', label: 'À traiter' },
    { value: 'removed', label: 'Retirées' },
    { value: 'all', label: 'Toutes' },
];

const REASON_LABELS = {
    spam: 'Spam ou publicité trompeuse',
    arnaque: 'Arnaque',
    contenu_choquant: 'Contenu choquant ou inapproprié',
    contrefacon: 'Contrefaçon',
    autre: 'Autre',
};

const STATUS_STYLES = {
    active: { label: 'En ligne', color: 'bg-green-100 text-green-800' },
    removed: { label: 'Retirée', color: 'bg-red-100 text-red-800' },
};

const ACTION_CONFIRMATIONS = {
    remove: 'Retirer cette vidéo du fil ?',
    restore: 'Remettre cette vidéo en ligne ?',
    dismiss: 'Classer ces signalements sans retirer la vidéo ?',
};

export default function Videos() {
    const [filter, setFilter] = useState('pending');
    const [videos, setVideos] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [busyVideoId, setBusyVideoId] = useState(null);

    const fetchVideos = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const { data } = await api.get('/admin/videos', { params: { filter } });
            setVideos(data);
        } catch (err) {
            console.error('Erreur vidéos:', err);
            setError('Impossible de charger les vidéos.');
        } finally {
            setLoading(false);
        }
    }, [filter]);

    useEffect(() => {
        fetchVideos();
    }, [fetchVideos]);

    const moderate = async (videoId, action) => {
        if (!window.confirm(ACTION_CONFIRMATIONS[action])) return;

        setBusyVideoId(videoId);
        try {
            await api.post(`/admin/videos/${videoId}/moderate`, { action });
            await fetchVideos();
        } catch (err) {
            console.error('Erreur modération:', err);
            alert(err.response?.data?.error || "Erreur lors de l'action de modération");
        } finally {
            setBusyVideoId(null);
        }
    };

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Modération des vidéos</h1>

            <div className="flex gap-2 mb-6">
                {FILTERS.map((item) => (
                    <button
                        key={item.value}
                        onClick={() => setFilter(item.value)}
                        className={`px-4 py-2 rounded-lg text-sm font-medium ${
                            filter === item.value
                                ? 'bg-primary text-white'
                                : 'bg-white text-gray-700 border border-gray-200'
                        }`}
                    >
                        {item.label}
                    </button>
                ))}
            </div>

            {error && <p className="text-red-600 mb-4">{error}</p>}
            {loading && <p className="text-gray-500">Chargement des vidéos...</p>}
            {!loading && !error && videos.length === 0 && (
                <p className="text-gray-500">Aucune vidéo dans cette catégorie.</p>
            )}

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {!loading && videos.map((video) => {
                    const status = STATUS_STYLES[video.status];
                    const isBusy = busyVideoId === video.id;
                    return (
                        <article key={video.id} className="bg-white rounded-xl shadow p-4 flex gap-4">
                            <video
                                src={video.video_url}
                                controls
                                preload="metadata"
                                className="w-40 h-72 bg-black rounded-lg flex-shrink-0"
                            />

                            <div className="flex-1 min-w-0">
                                <div className="flex items-center justify-between gap-2 mb-2">
                                    <h2 className="font-semibold text-gray-900 truncate">
                                        {video.title || `Vidéo #${video.id}`}
                                    </h2>
                                    {status && (
                                        <span className={`px-2 py-1 rounded-full text-xs ${status.color}`}>
                                            {status.label}
                                        </span>
                                    )}
                                </div>

                                <p className="text-sm text-gray-600">
                                    {video.seller_name} · {video.seller_phone}
                                </p>
                                <p className="text-sm text-gray-500 mb-3">
                                    {video.views_count} vues · {video.likes_count} j'aime ·{' '}
                                    {video.pending_reports} signalement(s) à traiter
                                </p>

                                <ul className="space-y-2 max-h-32 overflow-y-auto mb-3">
                                    {video.reports.map((report) => (
                                        <li key={report.id} className="text-sm border-l-2 border-gray-200 pl-2">
                                            <span className="font-medium">
                                                {REASON_LABELS[report.reason] || report.reason}
                                            </span>
                                            <span className="text-gray-500"> · {report.reporter_name}</span>
                                            {report.details && (
                                                <p className="text-gray-600">{report.details}</p>
                                            )}
                                        </li>
                                    ))}
                                </ul>

                                <div className="flex flex-wrap gap-2">
                                    {video.status === 'active' && (
                                        <button
                                            disabled={isBusy}
                                            onClick={() => moderate(video.id, 'remove')}
                                            className="px-3 py-2 rounded-lg text-sm bg-red-600 text-white disabled:opacity-50"
                                        >
                                            Retirer la vidéo
                                        </button>
                                    )}
                                    {video.status === 'removed' && (
                                        <button
                                            disabled={isBusy}
                                            onClick={() => moderate(video.id, 'restore')}
                                            className="px-3 py-2 rounded-lg text-sm bg-green-600 text-white disabled:opacity-50"
                                        >
                                            Remettre en ligne
                                        </button>
                                    )}
                                    {video.pending_reports > 0 && (
                                        <button
                                            disabled={isBusy}
                                            onClick={() => moderate(video.id, 'dismiss')}
                                            className="px-3 py-2 rounded-lg text-sm bg-gray-100 text-gray-800 disabled:opacity-50"
                                        >
                                            Classer sans suite
                                        </button>
                                    )}
                                </div>
                            </div>
                        </article>
                    );
                })}
            </div>
        </div>
    );
}
