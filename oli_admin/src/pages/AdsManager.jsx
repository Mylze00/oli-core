import { useState, useEffect } from 'react';
import { 
    Trash2, 
    Plus, 
    ToggleLeft, 
    ToggleRight, 
    ExternalLink, 
    Upload, 
    ArrowUp, 
    ArrowDown, 
    Edit2, 
    Eye, 
    RefreshCw, 
    Layers, 
    CheckCircle2, 
    XCircle 
} from 'lucide-react';
import api from '../services/api';

function AdsManager() {
    const [ads, setAds] = useState([]);
    const [loading, setLoading] = useState(true);
    const [uploading, setUploading] = useState(false);
    const [editingAdId, setEditingAdId] = useState(null);
    const [statusMessage, setStatusMessage] = useState(null);

    const [formAd, setFormAd] = useState({
        image_url: '',
        title: '',
        link_url: '',
        is_active: true
    });

    useEffect(() => {
        fetchAds();
    }, []);

    const showMessage = (msg, isError = false) => {
        setStatusMessage({ text: msg, isError });
        setTimeout(() => setStatusMessage(null), 3500);
    };

    const fetchAds = async () => {
        setLoading(true);
        try {
            const res = await api.get('/admin/ads');
            // S'assurer que les pubs sont triées par display_order croissant
            const sorted = [...res.data].sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0));
            setAds(sorted);
        } catch (err) {
            console.error("Erreur chargement pubs:", err);
            showMessage("Impossible de charger les publicités. Vérifiez la connexion serveur.", true);
        } finally {
            setLoading(false);
        }
    };

    // ── Upload d'image ──────────────────────────────────────────
    const handleImageUpload = async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const formData = new FormData();
        formData.append('image', file);

        try {
            setUploading(true);
            const res = await api.post('/admin/ads/upload', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });
            if (res.data?.url) {
                setFormAd(prev => ({ ...prev, image_url: res.data.url }));
                showMessage("Image importée avec succès !");
            }
        } catch (err) {
            console.error("Erreur upload:", err);
            showMessage("Erreur lors de l'upload de l'image.", true);
        } finally {
            setUploading(false);
        }
    };

    // ── Soumission (Création ou Mise à jour) ─────────────────────
    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!formAd.image_url.trim()) {
            showMessage("L'URL de l'image est requise.", true);
            return;
        }

        try {
            if (editingAdId) {
                // Modification
                const res = await api.put(`/admin/ads/${editingAdId}`, formAd);
                setAds(ads.map(ad => ad.id === editingAdId ? res.data : ad));
                showMessage("Publicité modifiée avec succès !");
                cancelEdit();
            } else {
                // Nouvelle publication
                const res = await api.post('/admin/ads', {
                    ...formAd,
                    display_order: ads.length + 1
                });
                setAds([...ads, res.data]);
                showMessage("Nouvelle publicité publiée dans l'application !");
                setFormAd({ image_url: '', title: '', link_url: '', is_active: true });
            }
        } catch (err) {
            console.error("Erreur soumission pub:", err);
            showMessage("Erreur lors de l'enregistrement de la publicité.", true);
        }
    };

    // ── Commencer l'édition ──────────────────────────────────────
    const startEdit = (ad) => {
        setEditingAdId(ad.id);
        setFormAd({
            image_url: ad.image_url || '',
            title: ad.title || '',
            link_url: ad.link_url || '',
            is_active: ad.is_active ?? true
        });
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    const cancelEdit = () => {
        setEditingAdId(null);
        setFormAd({ image_url: '', title: '', link_url: '', is_active: true });
    };

    // ── Suppression ─────────────────────────────────────────────
    const handleDelete = async (id, title) => {
        if (!window.confirm(`Confirmer la suppression définitive de la publicité « ${title || 'Sans titre'} » ?`)) return;

        try {
            await api.delete(`/admin/ads/${id}`);
            const updated = ads.filter(ad => ad.id !== id);
            setAds(updated);
            showMessage("Publicité retirée avec succès.");
        } catch (err) {
            console.error("Erreur suppression:", err);
            showMessage("Erreur lors de la suppression.", true);
        }
    };

    // ── Toggle Actif/Inactif ─────────────────────────────────────
    const handleToggle = async (id, currentStatus) => {
        try {
            const res = await api.patch(`/admin/ads/${id}/status`, { is_active: !currentStatus });
            setAds(ads.map(ad => ad.id === id ? res.data : ad));
            showMessage(!currentStatus ? "Publicité activée en ligne." : "Publicité mise en pause (masquée).");
        } catch (err) {
            console.error("Erreur toggle status:", err);
            showMessage("Erreur lors du changement de statut.", true);
        }
    };

    // ── Réordonner (Monter / Descendre) ──────────────────────────
    const handleMove = async (index, direction) => {
        const targetIndex = index + direction;
        if (targetIndex < 0 || targetIndex >= ads.length) return;

        const newAds = [...ads];
        const temp = newAds[index];
        newAds[index] = newAds[targetIndex];
        newAds[targetIndex] = temp;

        // Mise à jour locale immédiate pour réactivité parfaite
        const reordered = newAds.map((ad, idx) => ({ ...ad, display_order: idx + 1 }));
        setAds(reordered);

        // Envoi au backend
        try {
            const ordersPayload = reordered.map((ad, idx) => ({ id: ad.id, order: idx + 1 }));
            await api.patch('/admin/ads/reorder', { orders: ordersPayload });
            showMessage("Ordre d'affichage mis à jour dans l'application !");
        } catch (err) {
            console.error("Erreur réordonnancement:", err);
            showMessage("Erreur lors de l'enregistrement de l'ordre.", true);
            fetchAds(); // rollback
        }
    };

    const activeCount = ads.filter(a => a.is_active).length;
    const inactiveCount = ads.length - activeCount;

    return (
        <div className="space-y-6 p-4 md:p-8 bg-slate-50 min-h-screen">
            {/* ── Top Header & Stats ───────────────────────────────── */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl md:text-3xl font-extrabold text-slate-900 flex items-center gap-2">
                        <Layers className="text-blue-600" size={28} />
                        Gestion du Carrousel Publicitaire
                    </h1>
                    <p className="text-sm text-slate-500 mt-1">
                        Pilotez directement les bannières visibles sur l'application mobile (ordre, activation et liens).
                    </p>
                </div>

                <div className="flex items-center gap-3">
                    <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-xl shadow-sm border border-slate-200">
                        <span className="flex h-2.5 w-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
                        <span className="text-xs font-semibold text-slate-700">{activeCount} En ligne</span>
                        <span className="text-slate-300">|</span>
                        <span className="text-xs font-semibold text-slate-400">{inactiveCount} Masquées</span>
                    </div>

                    <button
                        onClick={fetchAds}
                        className="p-2.5 bg-white hover:bg-slate-100 text-slate-700 rounded-xl border border-slate-200 shadow-sm transition"
                        title="Actualiser la liste"
                    >
                        <RefreshCw size={18} className={loading ? 'animate-spin text-blue-600' : ''} />
                    </button>
                </div>
            </div>

            {/* ── Notification Toast ──────────────────────────────── */}
            {statusMessage && (
                <div className={`p-4 rounded-xl flex items-center gap-3 text-sm font-medium shadow-sm transition ${
                    statusMessage.isError 
                        ? 'bg-rose-50 border border-rose-200 text-rose-700' 
                        : 'bg-emerald-50 border border-emerald-200 text-emerald-800'
                }`}>
                    {statusMessage.isError ? <XCircle size={20} /> : <CheckCircle2 size={20} />}
                    {statusMessage.text}
                </div>
            )}

            {/* ── Formulaire d'Ajout / Modification ──────────────── */}
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
                <div className="flex items-center justify-between mb-4">
                    <h2 className="text-base font-bold text-slate-800 flex items-center gap-2">
                        {editingAdId ? (
                            <>
                                <Edit2 size={18} className="text-amber-500" />
                                Modifier la publicité #{editingAdId}
                            </>
                        ) : (
                            <>
                                <Plus size={18} className="text-blue-600" />
                                Publier une nouvelle publicité
                            </>
                        )}
                    </h2>
                    {editingAdId && (
                        <button
                            onClick={cancelEdit}
                            className="text-xs font-semibold text-slate-500 hover:text-slate-800 underline"
                        >
                            Annuler la modification
                        </button>
                    )}
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                        {/* URL Image & Upload */}
                        <div className="lg:col-span-1">
                            <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                                Image Bannière (Paysage) *
                            </label>
                            <div className="flex gap-2">
                                <input
                                    type="text"
                                    required
                                    placeholder="https://.../banniere.jpg"
                                    className="flex-1 bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                                    value={formAd.image_url}
                                    onChange={e => setFormAd({ ...formAd, image_url: e.target.value })}
                                />
                                <label
                                    className="bg-blue-50 hover:bg-blue-100 text-blue-700 px-3.5 py-2.5 rounded-xl cursor-pointer transition flex items-center gap-1.5 text-xs font-bold border border-blue-200"
                                    title="Uploader un fichier image depuis votre ordinateur"
                                >
                                    <Upload size={16} />
                                    <span>{uploading ? 'Upload...' : 'Fichier'}</span>
                                    <input
                                        type="file"
                                        className="hidden"
                                        accept="image/*"
                                        disabled={uploading}
                                        onChange={handleImageUpload}
                                    />
                                </label>
                            </div>
                        </div>

                        {/* Titre */}
                        <div>
                            <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                                Titre / Légende (Optionnel)
                            </label>
                            <input
                                type="text"
                                placeholder="Ex: Promotion 50$ ou plus, Fally Ipupa..."
                                className="w-full bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                                value={formAd.title}
                                onChange={e => setFormAd({ ...formAd, title: e.target.value })}
                            />
                        </div>

                        {/* Lien de redirection */}
                        <div>
                            <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                                Lien de Destination (Redirection au clic)
                            </label>
                            <input
                                type="text"
                                placeholder="https://... ou lien interne"
                                className="w-full bg-slate-50 text-slate-900 rounded-xl px-3.5 py-2.5 border border-slate-200 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                                value={formAd.link_url}
                                onChange={e => setFormAd({ ...formAd, link_url: e.target.value })}
                            />
                        </div>
                    </div>

                    {/* Aperçu direct si image saisie */}
                    {formAd.image_url && (
                        <div className="mt-3 p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-center gap-4">
                            <div className="w-36 h-20 rounded-lg overflow-hidden bg-slate-200 flex-shrink-0 border border-slate-300">
                                <img
                                    src={formAd.image_url}
                                    alt="Aperçu"
                                    className="w-full h-full object-cover"
                                    onError={(e) => { e.target.src = 'https://placehold.co/600x300?text=Erreur+Image'; }}
                                />
                            </div>
                            <div className="flex-1 text-xs text-slate-600">
                                <span className="font-bold text-slate-800">Aperçu direct de la bannière :</span>
                                <p className="truncate mt-0.5">{formAd.title || 'Sans titre'}</p>
                                <p className="text-slate-400 truncate">{formAd.link_url || 'Aucun lien de destination'}</p>
                            </div>
                        </div>
                    )}

                    {/* Boutons d'action du formulaire */}
                    <div className="flex justify-end gap-3 pt-2">
                        {editingAdId && (
                            <button
                                type="button"
                                onClick={cancelEdit}
                                className="px-5 py-2.5 rounded-xl text-slate-600 hover:bg-slate-100 font-bold text-sm transition"
                            >
                                Annuler
                            </button>
                        )}
                        <button
                            type="submit"
                            disabled={uploading}
                            className={`px-6 py-2.5 text-white rounded-xl font-bold text-sm transition shadow-sm flex items-center gap-2 ${
                                editingAdId
                                    ? 'bg-amber-600 hover:bg-amber-700'
                                    : 'bg-blue-600 hover:bg-blue-700'
                            }`}
                        >
                            {editingAdId ? <Edit2 size={16} /> : <Plus size={16} />}
                            {editingAdId ? 'Mettre à jour la publicité' : 'Publier dans l\'application'}
                        </button>
                    </div>
                </form>
            </div>

            {/* ── Liste ordonnée des publicités publiées ───────────── */}
            <div className="space-y-4">
                <div className="flex items-center justify-between">
                    <h2 className="text-lg font-bold text-slate-800 flex items-center gap-2">
                        <Eye size={20} className="text-slate-500" />
                        Bannières en circulation ({ads.length})
                    </h2>
                    <span className="text-xs text-slate-400">
                        L'ordre ci-dessous correspond exactement à l'ordre de défilement dans l'application mobile.
                    </span>
                </div>

                {ads.length === 0 ? (
                    <div className="bg-white rounded-2xl border-2 border-dashed border-slate-200 p-12 text-center">
                        <p className="text-slate-500 font-semibold">Aucune publicité enregistrée.</p>
                        <p className="text-slate-400 text-xs mt-1">Utilisez le formulaire ci-dessus pour ajouter votre première publicité au carrousel.</p>
                    </div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
                        {ads.map((ad, index) => {
                            const isFirst = index === 0;
                            const isLast = index === ads.length - 1;

                            return (
                                <div
                                    key={ad.id}
                                    className={`bg-white rounded-2xl shadow-sm border transition flex flex-col justify-between overflow-hidden ${
                                        ad.is_active
                                            ? 'border-slate-200 hover:shadow-md'
                                            : 'border-slate-200 bg-slate-50 opacity-70'
                                    }`}
                                >
                                    {/* Image & Badges */}
                                    <div className="h-44 bg-slate-900 relative">
                                        <img
                                            src={ad.image_url}
                                            alt={ad.title || 'Publicité'}
                                            className="w-full h-full object-cover"
                                            onError={(e) => { e.target.src = 'https://placehold.co/600x300?text=Image+Indisponible'; }}
                                        />

                                        {/* Badge Position / Ordre */}
                                        <div className="absolute top-3 left-3 bg-slate-900/80 backdrop-blur-md text-amber-300 px-3 py-1 rounded-full text-xs font-black shadow-md border border-white/20">
                                            #{index + 1}
                                        </div>

                                        {/* Badge Statut */}
                                        <div className={`absolute top-3 right-3 px-3 py-1 rounded-full text-xs font-bold shadow-md ${
                                            ad.is_active
                                                ? 'bg-emerald-500 text-white'
                                                : 'bg-slate-600 text-slate-200'
                                        }`}>
                                            {ad.is_active ? '● En ligne' : '○ Masquée'}
                                        </div>

                                        {/* Contrôles de Réordonnancement Rapide (Monter / Descendre) */}
                                        <div className="absolute bottom-3 right-3 flex items-center gap-1.5 bg-slate-900/85 backdrop-blur-md p-1 rounded-xl shadow-md border border-white/10">
                                            <button
                                                disabled={isFirst}
                                                onClick={() => handleMove(index, -1)}
                                                className={`p-1.5 rounded-lg text-white transition ${
                                                    isFirst ? 'opacity-30 cursor-not-allowed' : 'hover:bg-blue-600'
                                                }`}
                                                title="Avancer dans l'ordre de défilement (vers la gauche)"
                                            >
                                                <ArrowUp size={16} />
                                            </button>
                                            <button
                                                disabled={isLast}
                                                onClick={() => handleMove(index, 1)}
                                                className={`p-1.5 rounded-lg text-white transition ${
                                                    isLast ? 'opacity-30 cursor-not-allowed' : 'hover:bg-blue-600'
                                                }`}
                                                title="Reculer dans l'ordre de défilement (vers la droite)"
                                            >
                                                <ArrowDown size={16} />
                                            </button>
                                        </div>
                                    </div>

                                    {/* Infos Publicité */}
                                    <div className="p-4 flex-1 flex flex-col justify-between">
                                        <div>
                                            <h3 className="text-slate-900 font-bold text-base mb-1 truncate" title={ad.title}>
                                                {ad.title || 'Publicité sans titre'}
                                            </h3>

                                            {ad.link_url ? (
                                                <a
                                                    href={ad.link_url}
                                                    target="_blank"
                                                    rel="noreferrer"
                                                    className="text-blue-600 hover:text-blue-800 text-xs flex items-center gap-1 mb-3 hover:underline truncate"
                                                    title={ad.link_url}
                                                >
                                                    <ExternalLink size={12} className="flex-shrink-0" />
                                                    <span className="truncate">{ad.link_url}</span>
                                                </a>
                                            ) : (
                                                <p className="text-slate-400 text-xs mb-3 italic">Aucun lien de redirection</p>
                                            )}
                                        </div>

                                        {/* Actions Bar */}
                                        <div className="flex items-center justify-between border-t border-slate-100 pt-3 mt-2">
                                            {/* Bouton Toggle Actif */}
                                            <button
                                                onClick={() => handleToggle(ad.id, ad.is_active)}
                                                className="text-slate-700 hover:text-slate-900 flex items-center gap-2 transition text-xs font-bold"
                                            >
                                                {ad.is_active ? (
                                                    <>
                                                        <ToggleRight size={26} className="text-emerald-500" />
                                                        <span className="text-emerald-700">En ligne</span>
                                                    </>
                                                ) : (
                                                    <>
                                                        <ToggleLeft size={26} className="text-slate-400" />
                                                        <span className="text-slate-400">Masquée</span>
                                                    </>
                                                )}
                                            </button>

                                            {/* Boutons Éditer et Supprimer */}
                                            <div className="flex items-center gap-1">
                                                <button
                                                    onClick={() => startEdit(ad)}
                                                    className="p-2 text-slate-500 hover:text-amber-600 hover:bg-amber-50 rounded-xl transition"
                                                    title="Modifier cette publicité"
                                                >
                                                    <Edit2 size={16} />
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(ad.id, ad.title)}
                                                    className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-xl transition"
                                                    title="Supprimer définitivement"
                                                >
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>
        </div>
    );
}

export default AdsManager;
