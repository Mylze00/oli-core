import { useState, useEffect } from 'react';
import axios from 'axios';
import { Trash2, Plus, ToggleLeft, ToggleRight, ExternalLink, Upload } from 'lucide-react';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

function AdsManager() {
    const [ads, setAds] = useState([]);
    const [loading, setLoading] = useState(true);
    const [newAd, setNewAd] = useState({ image_url: '', title: '', link_url: '' });

    useEffect(() => {
        fetchAds();
    }, []);

    const fetchAds = async () => {
        try {
            const token = localStorage.getItem('token');
            const res = await axios.get(`${API_URL}/admin/ads`, {
                headers: { Authorization: `Bearer ${token}` }
            });
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
            const token = localStorage.getItem('token');
            await axios.delete(`${API_URL}/admin/ads/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setAds(ads.filter(ad => ad.id !== id));
        } catch (err) {
            alert('Erreur lors de la suppression');
        }
    };

    const handleToggle = async (id, currentStatus) => {
        try {
            const token = localStorage.getItem('token');
            const res = await axios.patch(`${API_URL}/admin/ads/${id}/status`,
                { is_active: !currentStatus },
                { headers: { Authorization: `Bearer ${token}` } }
            );
            setAds(ads.map(ad => ad.id === id ? res.data : ad));
        } catch (err) {
            alert('Erreur update status');
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const token = localStorage.getItem('token');
            const res = await axios.post(`${API_URL}/admin/ads`, newAd, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setAds([res.data, ...ads]);
            setNewAd({ image_url: '', title: '', link_url: '' });
        } catch (err) {
            alert('Erreur création pub');
        }
    };

    if (loading) return <div className="p-8 text-white">Chargement...</div>;

    return (
        <div className="p-6">
            <h1 className="text-2xl font-bold text-white mb-6">Gestion Publicité (Carrousel Accueil)</h1>

            {/* Formulaire Ajout */}
            <div className="bg-gray-800 p-4 rounded-lg mb-8 border border-gray-700">
                <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                    <Plus size={20} /> Ajouter une publicité
                </h2>
                <form onSubmit={handleSubmit} className="flex gap-4 flex-wrap items-end">
                    <div className="flex-1 min-w-[300px]">
                        <label className="block text-gray-400 text-sm mb-1">URL Image (Landscape recommandé)</label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                required
                                placeholder="https://..."
                                className="flex-1 bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                                value={newAd.image_url}
                                onChange={e => setNewAd({ ...newAd, image_url: e.target.value })}
                            />
                            <label className="bg-gray-700 hover:bg-gray-600 text-white p-2 rounded cursor-pointer transition-colors flex items-center justify-center" title="Uploader une image">
                                <Upload size={20} />
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
                                            setLoading(true); // Petit loading global ou local ? Global c'est bourrin mais simple
                                            const token = localStorage.getItem('token');
                                            const res = await axios.post(`${API_URL}/admin/ads/upload`, formData, {
                                                headers: {
                                                    'Content-Type': 'multipart/form-data',
                                                    Authorization: `Bearer ${token}`
                                                }
                                            });
                                            setNewAd(prev => ({ ...prev, image_url: res.data.url }));
                                        } catch (err) {
                                            alert("Erreur upload image");
                                            console.error(err);
                                        } finally {
                                            setLoading(false);
                                        }
                                    }}
                                />
                            </label>
                        </div>
                    </div>
                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-gray-400 text-sm mb-1">Titre (Optionnel)</label>
                        <input
                            type="text"
                            placeholder="Promo Hiver..."
                            className="w-full bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                            value={newAd.title}
                            onChange={e => setNewAd({ ...newAd, title: e.target.value })}
                        />
                    </div>
                    <button type="submit" className="bg-blue-600 hover:bg-blue-500 text-white px-6 py-2 rounded font-medium transition-colors">
                        Publier
                    </button>
                </form>
            </div>

            {/* Liste */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {ads.map(ad => (
                    <div key={ad.id} className={`bg-gray-800 rounded-lg overflow-hidden border ${ad.is_active ? 'border-gray-700' : 'border-red-900 opacity-70'}`}>
                        <div className="h-40 bg-gray-900 relative">
                            <img src={ad.image_url} alt={ad.title} className="w-full h-full object-cover" />
                            <div className="absolute top-2 right-2 bg-black/60 rounded px-2 py-1 text-xs text-white">
                                {ad.is_active ? '✅ Actif' : '🔴 Inactif'}
                            </div>
                        </div>
                        <div className="p-4">
                            <h3 className="text-white font-bold text-lg mb-1">{ad.title || 'Sans titre'}</h3>
                            <a href={ad.link_url} target="_blank" rel="noreferrer" className="text-blue-400 text-sm flex items-center gap-1 mb-4 hover:underline">
                                <ExternalLink size={14} /> {ad.link_url || 'Pas de lien'}
                            </a>

                            <div className="flex items-center justify-between border-t border-gray-700 pt-4">
                                <button
                                    onClick={() => handleToggle(ad.id, ad.is_active)}
                                    className="text-gray-400 hover:text-white flex items-center gap-2 transition-colors"
                                    title={ad.is_active ? "Désactiver" : "Activer"}
                                >
                                    {ad.is_active ? <ToggleRight size={24} className="text-green-500" /> : <ToggleLeft size={24} />}
                                    {ad.is_active ? 'Désactiver' : 'Activer'}
                                </button>
                                <button
                                    onClick={() => handleDelete(ad.id)}
                                    className="text-red-500 hover:text-red-400 p-2 rounded hover:bg-red-500/10 transition-colors"
                                    title="Supprimer"
                                >
                                    <Trash2 size={20} />
                                </button>
                            </div>
                        </div>
                    </div>
                ))}

                {ads.length === 0 && (
                    <div className="col-span-full text-center py-12 text-gray-500 italic">
                        Aucune publicité active. Ajoutez-en une ci-dessus.
                    </div>
                )}
            </div>
        </div>
    );
}

export default AdsManager;
