import { useEffect, useState } from 'react';
import {
    ArrowDown,
    ArrowUp,
    CheckCircle2,
    Edit2,
    ExternalLink,
    Film,
    Image as ImageIcon,
    LayoutList,
    Plus,
    RefreshCw,
    ToggleLeft,
    ToggleRight,
    Trash2,
    Upload,
    XCircle,
} from 'lucide-react';
import api from '../../services/api';

const EMPTY_FORM = {
    media_type: 'image',
    media_url: '',
    poster_url: '',
    title: '',
    link_url: '',
    is_active: true,
};

/**
 * Gestion des bannières du fil d'accueil : images (avec lien) ou vidéos
 * compressées, insérées entre les blocs de produits du Top Classement.
 * L'application les garde en cache sur le téléphone.
 */
function FeedBannersManager() {
    const [banners, setBanners] = useState([]);
    const [loading, setLoading] = useState(true);
    const [uploading, setUploading] = useState(false);
    const [editingId, setEditingId] = useState(null);
    const [form, setForm] = useState(EMPTY_FORM);
    const [message, setMessage] = useState(null);

    useEffect(() => {
        fetchBanners();
    }, []);

    const notify = (text, isError = false) => {
        setMessage({ text, isError });
        setTimeout(() => setMessage(null), 3500);
    };

    const fetchBanners = async () => {
        setLoading(true);
        try {
            const res = await api.get('/admin/feed-banners');
            setBanners(res.data);
        } catch (err) {
            console.error('Erreur chargement bannières:', err);
            notify('Impossible de charger les bannières du fil.', true);
        } finally {
            setLoading(false);
        }
    };

    // ── Import d'un fichier (image ou vidéo) ─────────────────────
    const handleUpload = async (e) => {
        const file = e.target.files[0];
        e.target.value = '';
        if (!file) return;

        const isVideo = file.type.startsWith('video/');
        if (isVideo && file.size > 50 * 1024 * 1024) {
            notify('Vidéo trop lourde : 50 Mo maximum.', true);
            return;
        }

        const data = new FormData();
        data.append('file', file);
        try {
            setUploading(true);
            const res = await api.post('/admin/feed-banners/upload', data, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });
            setForm(prev => ({
                ...prev,
                media_type: res.data.media_type,
                media_url: res.data.media_url,
                poster_url: res.data.poster_url || '',
            }));
            notify(isVideo
                ? 'Vidéo importée : la version compressée est préparée par Cloudinary.'
                : 'Image importée.');
        } catch (err) {
            console.error('Erreur upload bannière:', err);
            notify("Erreur lors de l'import du fichier.", true);
        } finally {
            setUploading(false);
        }
    };

    // ── Création / modification ──────────────────────────────────
    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!form.media_url.trim()) {
            notify('Ajoutez une image ou une vidéo.', true);
            return;
        }
        try {
            if (editingId) {
                const res = await api.put(`/admin/feed-banners/${editingId}`, form);
                setBanners(banners.map(b => (b.id === editingId ? res.data : b)));
                notify('Bannière modifiée.');
            } else {
                const res = await api.post('/admin/feed-banners', form);
                setBanners([...banners, res.data]);
                notify("Bannière publiée dans l'application.");
            }
            resetForm();
        } catch (err) {
            console.error('Erreur enregistrement bannière:', err);
            notify("Erreur lors de l'enregistrement.", true);
        }
    };

    const startEdit = (banner) => {
        setEditingId(banner.id);
        setForm({
            media_type: banner.media_type,
            media_url: banner.media_url || '',
            poster_url: banner.poster_url || '',
            title: banner.title || '',
            link_url: banner.link_url || '',
            is_active: banner.is_active ?? true,
        });
        document.getElementById('feed-banners')?.scrollIntoView({ behavior: 'smooth' });
    };

    const resetForm = () => {
        setEditingId(null);
        setForm(EMPTY_FORM);
    };

    const handleDelete = async (banner) => {
        if (!window.confirm(`Supprimer définitivement la bannière « ${banner.title || 'Sans titre'} » ?`)) return;
        try {
            await api.delete(`/admin/feed-banners/${banner.id}`);
            setBanners(banners.filter(b => b.id !== banner.id));
            notify('Bannière supprimée.');
        } catch (err) {
            console.error('Erreur suppression bannière:', err);
            notify('Erreur lors de la suppression.', true);
        }
    };

    const handleToggle = async (banner) => {
        try {
            const res = await api.patch(`/admin/feed-banners/${banner.id}/status`, { is_active: !banner.is_active });
            setBanners(banners.map(b => (b.id === banner.id ? res.data : b)));
        } catch (err) {
            console.error('Erreur statut bannière:', err);
            notify('Erreur lors du changement de statut.', true);
        }
    };

    const handleMove = async (index, direction) => {
        const target = index + direction;
        if (target < 0 || target >= banners.length) return;
        const next = [...banners];
        [next[index], next[target]] = [next[target], next[index]];
        const reordered = next.map((b, i) => ({ ...b, display_order: i + 1 }));
        setBanners(reordered);
        try {
            await api.patch('/admin/feed-banners/reorder', {
                orders: reordered.map((b, i) => ({ id: b.id, order: i + 1 })),
            });
        } catch (err) {
            console.error('Erreur ordre bannières:', err);
            notify("Erreur lors de l'enregistrement de l'ordre.", true);
            fetchBanners();
        }
    };

    const isVideo = form.media_type === 'video';

    return (
        <section id="feed-banners" className="space-y-4 pt-6 border-t border-slate-200">
            {/* ── En-tête ── */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
                <div>
                    <h2 className="text-xl md:text-2xl font-extrabold text-slate-900 flex items-center gap-2">
                        <LayoutList className="text-violet-600" size={24} />
                        Bannières du fil d'accueil
                    </h2>
                    <p className="text-sm text-slate-500 mt-1">
                        Images avec lien ou vidéos courtes, placées entre les blocs de produits du Top Classement.
                        Elles tournent dans l'ordre ci-dessous et restent en cache sur le téléphone.
                    </p>
                </div>
                <button
                    onClick={fetchBanners}
                    className="self-start p-2.5 bg-white hover:bg-slate-100 text-slate-700 rounded-xl border border-slate-200 shadow-sm transition"
                    title="Actualiser"
                >
                    <RefreshCw size={18} className={loading ? 'animate-spin text-violet-600' : ''} />
                </button>
            </div>

            {message && (
                <div className={`p-4 rounded-xl flex items-center gap-3 text-sm font-medium ${
                    message.isError
                        ? 'bg-rose-50 border border-rose-200 text-rose-700'
                        : 'bg-emerald-50 border border-emerald-200 text-emerald-800'
                }`}>
                    {message.isError ? <XCircle size={20} /> : <CheckCircle2 size={20} />}
                    {message.text}
                </div>
            )}

            {/* ── Formulaire ── */}
            <form onSubmit={handleSubmit} className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 space-y-4">
                <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                    {editingId
                        ? <><Edit2 size={18} className="text-amber-500" /> Modifier la bannière #{editingId}</>
                        : <><Plus size={18} className="text-violet-600" /> Nouvelle bannière</>}
                </h3>

                {/* Type de média */}
                <div className="flex gap-2">
                    {[
                        { value: 'image', label: 'Image + lien', icon: <ImageIcon size={16} /> },
                        { value: 'video', label: 'Vidéo', icon: <Film size={16} /> },
                    ].map(({ value, label, icon }) => (
                        <button
                            key={value}
                            type="button"
                            onClick={() => setForm({ ...form, media_type: value, media_url: '', poster_url: '' })}
                            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold border transition ${
                                form.media_type === value
                                    ? 'bg-violet-600 text-white border-violet-600'
                                    : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100'
                            }`}
                        >
                            {icon} {label}
                        </button>
                    ))}
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                    {/* Fichier */}
                    <div>
                        <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                            {isVideo ? 'Vidéo (50 Mo max, compressée automatiquement) *' : 'Image (paysage) *'}
                        </label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                placeholder={isVideo ? 'https://.../video.mp4' : 'https://.../banniere.jpg'}
                                className="flex-1 min-w-0 bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-violet-500 outline-none"
                                value={form.media_url}
                                onChange={e => setForm({ ...form, media_url: e.target.value })}
                            />
                            <label className="bg-violet-50 hover:bg-violet-100 text-violet-700 px-3.5 py-2.5 rounded-xl cursor-pointer transition flex items-center gap-1.5 text-xs font-bold border border-violet-200">
                                <Upload size={16} />
                                <span>{uploading ? 'Import...' : 'Fichier'}</span>
                                <input
                                    type="file"
                                    className="hidden"
                                    accept={isVideo ? 'video/*' : 'image/*'}
                                    disabled={uploading}
                                    onChange={handleUpload}
                                />
                            </label>
                        </div>
                    </div>

                    {/* Titre */}
                    <div>
                        <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                            Titre interne (facultatif)
                        </label>
                        <input
                            type="text"
                            placeholder="Ex : Fintech Western Union"
                            className="w-full bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-violet-500 outline-none"
                            value={form.title}
                            onChange={e => setForm({ ...form, title: e.target.value })}
                        />
                    </div>

                    {/* Lien */}
                    <div>
                        <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                            Lien au toucher (facultatif)
                        </label>
                        <input
                            type="text"
                            placeholder="https://..."
                            className="w-full bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-violet-500 outline-none"
                            value={form.link_url}
                            onChange={e => setForm({ ...form, link_url: e.target.value })}
                        />
                    </div>
                </div>

                {/* Aperçu */}
                {form.media_url && (
                    <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                        <p className="text-xs font-bold text-slate-700 mb-2">Aperçu</p>
                        <div className="max-w-md rounded-md overflow-hidden bg-slate-900">
                            {isVideo ? (
                                <video
                                    src={form.media_url}
                                    poster={form.poster_url || undefined}
                                    className="w-full"
                                    muted
                                    loop
                                    autoPlay
                                    playsInline
                                />
                            ) : (
                                <img src={form.media_url} alt="Aperçu" className="w-full" />
                            )}
                        </div>
                        {isVideo && (
                            <p className="text-xs text-slate-500 mt-2">
                                La vidéo est lue sans son, en boucle. La première lecture peut prendre quelques secondes
                                le temps que Cloudinary prépare la version compressée.
                            </p>
                        )}
                    </div>
                )}

                <div className="flex justify-end gap-3">
                    {editingId && (
                        <button
                            type="button"
                            onClick={resetForm}
                            className="px-5 py-2.5 rounded-xl text-slate-600 hover:bg-slate-100 font-bold text-sm transition"
                        >
                            Annuler
                        </button>
                    )}
                    <button
                        type="submit"
                        disabled={uploading}
                        className={`px-6 py-2.5 text-white rounded-xl font-bold text-sm transition shadow-sm flex items-center gap-2 disabled:opacity-50 ${
                            editingId ? 'bg-amber-600 hover:bg-amber-700' : 'bg-violet-600 hover:bg-violet-700'
                        }`}
                    >
                        {editingId ? <Edit2 size={16} /> : <Plus size={16} />}
                        {editingId ? 'Mettre à jour' : 'Publier la bannière'}
                    </button>
                </div>
            </form>

            {/* ── Liste ── */}
            {banners.length === 0 ? (
                <div className="bg-white rounded-2xl border-2 border-dashed border-slate-200 p-10 text-center">
                    <p className="text-slate-500 font-semibold">Aucune bannière du fil.</p>
                    <p className="text-slate-400 text-xs mt-1">
                        Sans bannière, l'application affiche la bannière fintech par défaut.
                    </p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
                    {banners.map((banner, index) => (
                        <div
                            key={banner.id}
                            className={`bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col ${
                                banner.is_active ? '' : 'opacity-60'
                            }`}
                        >
                            <div className="relative bg-slate-900 aspect-[3/1]">
                                {banner.media_type === 'video' ? (
                                    <video
                                        src={banner.media_url}
                                        poster={banner.poster_url || undefined}
                                        className="w-full h-full object-cover"
                                        muted
                                        loop
                                        playsInline
                                        onMouseEnter={e => e.target.play()}
                                        onMouseLeave={e => e.target.pause()}
                                    />
                                ) : (
                                    <img src={banner.media_url} alt={banner.title || 'Bannière'} className="w-full h-full object-cover" />
                                )}
                                <span className="absolute top-2 left-2 bg-slate-900/80 text-amber-300 px-2.5 py-0.5 rounded-full text-xs font-black">
                                    #{index + 1}
                                </span>
                                <span className="absolute top-2 right-2 bg-slate-900/80 text-white px-2.5 py-0.5 rounded-full text-xs font-bold flex items-center gap-1">
                                    {banner.media_type === 'video' ? <><Film size={12} /> Vidéo</> : <><ImageIcon size={12} /> Image</>}
                                </span>
                                <div className="absolute bottom-2 right-2 flex gap-1 bg-slate-900/85 p-1 rounded-xl">
                                    <button
                                        disabled={index === 0}
                                        onClick={() => handleMove(index, -1)}
                                        className="p-1.5 rounded-lg text-white hover:bg-violet-600 disabled:opacity-30 disabled:hover:bg-transparent"
                                        title="Monter"
                                    >
                                        <ArrowUp size={14} />
                                    </button>
                                    <button
                                        disabled={index === banners.length - 1}
                                        onClick={() => handleMove(index, 1)}
                                        className="p-1.5 rounded-lg text-white hover:bg-violet-600 disabled:opacity-30 disabled:hover:bg-transparent"
                                        title="Descendre"
                                    >
                                        <ArrowDown size={14} />
                                    </button>
                                </div>
                            </div>

                            <div className="p-4 flex-1 flex flex-col justify-between gap-3">
                                <div className="min-w-0">
                                    <h4 className="font-bold text-slate-900 truncate">{banner.title || 'Bannière sans titre'}</h4>
                                    {banner.link_url ? (
                                        <a
                                            href={banner.link_url}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="text-violet-600 hover:underline text-xs flex items-center gap-1 truncate"
                                        >
                                            <ExternalLink size={12} className="flex-shrink-0" />
                                            <span className="truncate">{banner.link_url}</span>
                                        </a>
                                    ) : (
                                        <p className="text-slate-400 text-xs italic">Aucun lien</p>
                                    )}
                                </div>
                                <div className="flex items-center justify-between border-t border-slate-100 pt-3">
                                    <button
                                        onClick={() => handleToggle(banner)}
                                        className="flex items-center gap-2 text-xs font-bold"
                                    >
                                        {banner.is_active
                                            ? <><ToggleRight size={26} className="text-emerald-500" /><span className="text-emerald-700">En ligne</span></>
                                            : <><ToggleLeft size={26} className="text-slate-400" /><span className="text-slate-400">Masquée</span></>}
                                    </button>
                                    <div className="flex gap-1">
                                        <button
                                            onClick={() => startEdit(banner)}
                                            className="p-2 text-slate-500 hover:text-amber-600 hover:bg-amber-50 rounded-xl"
                                            title="Modifier"
                                        >
                                            <Edit2 size={16} />
                                        </button>
                                        <button
                                            onClick={() => handleDelete(banner)}
                                            className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-xl"
                                            title="Supprimer"
                                        >
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </section>
    );
}

export default FeedBannersManager;
