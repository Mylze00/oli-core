import { useState, useEffect } from 'react';
import { Trash2, Plus, ToggleLeft, ToggleRight, ExternalLink, Upload } from 'lucide-react';
import api from '../services/api';

function AdsManager() {
    const [ads, setAds] = useState([]);
    const [loading, setLoading] = useState(true);
    const [newAd, setNewAd] = useState({ image_url: '', title: '', link_url: '' });

    useEffect(() => {
        fetchAds();
    }, []);

    const fetchAds = async () => {
        try {
            const res = await api.get('/admin/ads');
            setAds(res.data);
        } catch (err) {
            console.error("Erreur chargement pubs", err);
        } finally {
            setLoading(false);
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm('Supprimer cette publicité ?')) return;
        try {
            await api.delete(`/admin/ads/${id}`);
            setAds(ads.filter(ad => ad.id !== id));
        } catch (err) {
            alert('Erreur lors de la suppression');
        }
    };

    const handleToggle = async (id, currentStatus) => {
        try {
            const res = await api.patch(`/admin/ads/${id}/status`, { is_active: !currentStatus });
            setAds(ads.map(ad => ad.id === id ? res.data : ad));
        } catch (err) {
            alert('Erreur update status');
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const res = await api.post('/admin/ads', newAd);
            setAds([res.data, ...ads]);
            setNewAd({ image_url: '', title: '', link_url: '' });
        } catch (err) {
            alert('Erreur création pub');
        }
    };

    if (loading) return (
        <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
    );

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            <div>
                <h1 className="text-2xl font-bold text-gray-900">Publicités</h1>
                <p className="text-sm text-gray-400 mt-1">Gérez le carrousel publicitaire de l'application</p>
            </div>

            {/* Formulaire Ajout */}
            <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
                <h2 className="text-sm font-semibold text-gray-700 mb-4 flex items-center gap-2">
                    <Plus size={18} className="text-blue-500" /> Ajouter une publicité
                </h2>
                <form onSubmit={handleSubmit} className="flex gap-4 flex-wrap items-end">
                    <div className="flex-1 min-w-[300px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">URL Image (Landscape)</label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                required
                                placeholder="https://..."
                                className="flex-1 bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                                value={newAd.image_url}
                                onChange={e => setNewAd({ ...newAd, image_url: e.target.value })}
                            />
                            <label className="bg-gray-100 hover:bg-gray-200 text-gray-600 px-3 py-2.5 rounded-xl cursor-pointer transition flex items-center gap-1 text-sm" title="Uploader une image">
                                <Upload size={16} />
                                <input
                                    type="file"
                                    className="hidden"
                                    accept="image/*"
                                    onChange={async (e) => {
                                        const file = e.target.files[0];
                                        if (!file) return;
                                        const formData = new FormData();
                                        formData.append('image', file);
                                        try {
                                            setLoading(true);
                                            const res = await api.post('/admin/ads/upload', formData, {
                                                headers: { 'Content-Type': 'multipart/form-data' }
                                            });
                                            setNewAd(prev => ({ ...prev, image_url: res.data.url }));
                                        } catch (err) {
                                            alert("Erreur upload image");
                                        } finally {
                                            setLoading(false);
                                        }
                                    }}
                                />
                            </label>
                        </div>
                    </div>
                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Titre (Optionnel)</label>
                        <input
                            type="text"
                            placeholder="Promo Hiver..."
                            className="w-full bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            value={newAd.title}
                            onChange={e => setNewAd({ ...newAd, title: e.target.value })}
                        />
                    </div>
                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">URL de destination</label>
                        <input
                            type="text"
                            placeholder="https://..."
                            className="w-full bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            value={newAd.link_url}
                            onChange={e => setNewAd({ ...newAd, link_url: e.target.value })}
                        />
                    </div>
                    <button type="submit" className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold text-sm transition shadow-sm">
                        Publier
                    </button>
                </form>
            </div>

            {/* Liste pubs */}
            {ads.length === 0 ? (
                <div className="bg-white rounded-2xl border border-dashed border-gray-200 p-12 text-center">
                    <p className="text-gray-400 text-sm">Aucune publicité active. Ajoutez-en une ci-dessus.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {ads.map(ad => (
                        <div key={ad.id} className={`bg-white rounded-2xl shadow-sm border overflow-hidden ${ad.is_active ? 'border-gray-100' : 'border-red-200 opacity-70'}`}>
                            <div className="h-40 bg-gray-100 relative">
                                <img src={ad.image_url} alt={ad.title} className="w-full h-full object-cover" />
                                <div className={`absolute top-2 right-2 px-2.5 py-1 rounded-full text-xs font-semibold ${ad.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                                    {ad.is_active ? '✅ Actif' : '🔴 Inactif'}
                                </div>
                            </div>
                            <div className="p-4">
                                <h3 className="text-gray-900 font-bold text-base mb-1">{ad.title || 'Sans titre'}</h3>
                                {ad.link_url && (
                                    <a href={ad.link_url} target="_blank" rel="noreferrer" className="text-blue-500 text-xs flex items-center gap-1 mb-4 hover:underline truncate">
                                        <ExternalLink size={12} /> {ad.link_url}
                                    </a>
                                )}
                                <div className="flex items-center justify-between border-t border-gray-100 pt-3">
                                    <button
                                        onClick={() => handleToggle(ad.id, ad.is_active)}
                                        className="text-gray-600 hover:text-gray-900 flex items-center gap-2 transition text-sm"
                                    >
                                        {ad.is_active ? <ToggleRight size={22} className="text-green-500" /> : <ToggleLeft size={22} className="text-gray-400" />}
                                        {ad.is_active ? 'Désactiver' : 'Activer'}
                                    </button>
                                    <button
                                        onClick={() => handleDelete(ad.id)}
                                        className="text-red-500 hover:text-red-600 p-2 rounded-lg hover:bg-red-50 transition"
                                    >
                                        <Trash2 size={18} />
                                    </button>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

export default AdsManager;
