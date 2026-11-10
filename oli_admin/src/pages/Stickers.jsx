import { useCallback, useEffect, useRef, useState } from 'react';
import api from '../services/api';

export default function Stickers() {
    const [stickers, setStickers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [name, setName] = useState('');
    const [pack, setPack] = useState('Oli');
    const [file, setFile] = useState(null);
    const [saving, setSaving] = useState(false);
    const fileInput = useRef(null);

    const fetchStickers = useCallback(async () => {
        setError('');
        try {
            const { data } = await api.get('/admin/stickers');
            setStickers(data);
        } catch (err) {
            console.error('Erreur stickers:', err);
            setError('Impossible de charger les stickers.');
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchStickers();
    }, [fetchStickers]);

    const addSticker = async (event) => {
        event.preventDefault();
        if (!file || !name.trim()) return;

        setSaving(true);
        try {
            const body = new FormData();
            body.append('image', file);
            body.append('name', name.trim());
            body.append('pack', pack.trim());
            await api.post('/admin/stickers', body, {
                headers: { 'Content-Type': 'multipart/form-data' },
                timeout: 120000,
            });
            setName('');
            setFile(null);
            if (fileInput.current) fileInput.current.value = '';
            await fetchStickers();
        } catch (err) {
            console.error('Erreur ajout sticker:', err);
            alert(err.response?.data?.error || "Erreur lors de l'ajout du sticker");
        } finally {
            setSaving(false);
        }
    };

    const setStatus = async (sticker, status) => {
        try {
            await api.patch(`/admin/stickers/${sticker.id}`, { status });
            await fetchStickers();
        } catch (err) {
            console.error('Erreur statut sticker:', err);
            alert(err.response?.data?.error || 'Erreur lors de la mise à jour');
        }
    };

    return (
        <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-6">Stickers des commentaires</h1>

            <form onSubmit={addSticker} className="bg-white rounded-xl shadow p-4 mb-6 flex flex-wrap items-end gap-4">
                <label className="text-sm text-gray-700">
                    Image (PNG ou WebP à fond transparent)
                    <input
                        ref={fileInput}
                        type="file"
                        accept="image/png,image/webp"
                        onChange={(event) => setFile(event.target.files[0] || null)}
                        className="block mt-1 text-sm"
                    />
                </label>
                <label className="text-sm text-gray-700">
                    Nom
                    <input
                        value={name}
                        onChange={(event) => setName(event.target.value)}
                        maxLength={60}
                        className="block mt-1 border rounded-lg px-3 py-2"
                    />
                </label>
                <label className="text-sm text-gray-700">
                    Pack
                    <input
                        value={pack}
                        onChange={(event) => setPack(event.target.value)}
                        maxLength={60}
                        className="block mt-1 border rounded-lg px-3 py-2"
                    />
                </label>
                <button
                    type="submit"
                    disabled={saving || !file || !name.trim()}
                    className="px-4 py-2 rounded-lg bg-primary text-white disabled:opacity-50"
                >
                    {saving ? 'Envoi...' : 'Ajouter le sticker'}
                </button>
            </form>

            {error && <p className="text-red-600 mb-4">{error}</p>}
            {loading && <p className="text-gray-500">Chargement des stickers...</p>}
            {!loading && !error && stickers.length === 0 && (
                <p className="text-gray-500">Aucun sticker pour le moment.</p>
            )}

            <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-4">
                {stickers.map((sticker) => (
                    <article
                        key={sticker.id}
                        className={`bg-white rounded-xl shadow p-3 text-center ${sticker.status === 'hidden' ? 'opacity-50' : ''}`}
                    >
                        <img src={sticker.image_url} alt={sticker.name} className="w-24 h-24 object-contain mx-auto" />
                        <p className="text-sm font-medium text-gray-900 mt-2 truncate">{sticker.name}</p>
                        <p className="text-xs text-gray-500 mb-2 truncate">{sticker.pack}</p>
                        <button
                            onClick={() => setStatus(sticker, sticker.status === 'active' ? 'hidden' : 'active')}
                            className="text-sm text-indigo-600 hover:text-indigo-900"
                        >
                            {sticker.status === 'active' ? 'Masquer' : 'Réafficher'}
                        </button>
                    </article>
                ))}
            </div>
        </div>
    );
}
