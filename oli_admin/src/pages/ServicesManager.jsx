import { useState, useEffect } from 'react';
import axios from 'axios';
import { Trash2, Plus, Edit2, Upload } from 'lucide-react';

const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

function ServicesManager() {
    const [services, setServices] = useState([]);
    const [loading, setLoading] = useState(true);
    const [formData, setFormData] = useState({
        name: '',
        logo_url: '',
        color_hex: '#000000',
        status: 'coming_soon',
        display_order: 0
    });
    const [isEditing, setIsEditing] = useState(false);
    const [editId, setEditId] = useState(null);

    useEffect(() => {
        fetchServices();
    }, []);

    const fetchServices = async () => {
        try {
            const token = localStorage.getItem('token');
            const res = await axios.get(`${API_URL}/admin/services`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setServices(res.data);
        } catch (err) {
            console.error("Erreur chargement services", err);
        } finally {
            setLoading(false);
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm('Supprimer ce service ?')) return;
        try {
            const token = localStorage.getItem('token');
            await axios.delete(`${API_URL}/admin/services/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setServices(services.filter(s => s.id !== id));
        } catch (err) {
            alert('Erreur lors de la suppression');
        }
    };

    const handleEdit = (service) => {
        setIsEditing(true);
        setEditId(service.id);
        setFormData({
            name: service.name,
            logo_url: service.logo_url,
            color_hex: service.color_hex,
            status: service.status,
            display_order: service.display_order
        });
    };

    const handleCancelEdit = () => {
        setIsEditing(false);
        setEditId(null);
        setFormData({
            name: '',
            logo_url: '',
            color_hex: '#000000',
            status: 'coming_soon',
            display_order: 0
        });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const token = localStorage.getItem('token');
            let res;
            if (isEditing) {
                res = await axios.put(`${API_URL}/admin/services/${editId}`, formData, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                setServices(services.map(s => s.id === editId ? res.data : s));
            } else {
                res = await axios.post(`${API_URL}/admin/services`, formData, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                setServices([res.data, ...services]);
            }
            handleCancelEdit();
        } catch (err) {
            alert('Erreur sauvegarde service');
            console.error(err);
        }
    };

    const handleUpload = async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const uploadData = new FormData();
        uploadData.append('image', file);

        try {
            setLoading(true);
            const token = localStorage.getItem('token');
            // Assuming we reuse the ads/upload or create a generic upload. 
            // I created admin/services/upload!
            const res = await axios.post(`${API_URL}/admin/services/upload`, uploadData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                    Authorization: `Bearer ${token}`
                }
            });
            setFormData(prev => ({ ...prev, logo_url: res.data.url }));
        } catch (err) {
            alert("Erreur upload image");
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    if (loading && services.length === 0) return <div className="p-8 text-white">Chargement...</div>;

    return (
        <div className="p-6">
            <h1 className="text-2xl font-bold text-white mb-6">Gestion Services & Paiements</h1>

            {/* Formulaire */}
            <div className="bg-gray-800 p-4 rounded-lg mb-8 border border-gray-700">
                <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                    {isEditing ? <Edit2 size={20} /> : <Plus size={20} />}
                    {isEditing ? 'Modifier le service' : 'Ajouter un service'}
                </h2>
                <form onSubmit={handleSubmit} className="flex gap-4 flex-wrap items-end">
                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-gray-400 text-sm mb-1">Nom du service</label>
                        <input
                            type="text"
                            required
                            className="w-full bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                            value={formData.name}
                            onChange={e => setFormData({ ...formData, name: e.target.value })}
                        />
                    </div>

                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-gray-400 text-sm mb-1">Logo URL</label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                required
                                value={formData.logo_url}
                                onChange={e => setFormData({ ...formData, logo_url: e.target.value })}
                                className="flex-1 bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                            />
                            <label className="bg-gray-700 hover:bg-gray-600 text-white p-2 rounded cursor-pointer transition-colors flex items-center justify-center">
                                <Upload size={20} />
                                <input type="file" className="hidden" accept="image/*" onChange={handleUpload} />
                            </label>
                        </div>
                    </div>

                    <div className="w-[120px]">
                        <label className="block text-gray-400 text-sm mb-1">Couleur (Hex)</label>
                        <input
                            type="color"
                            className="w-full h-[42px] bg-gray-900 rounded cursor-pointer"
                            value={formData.color_hex}
                            onChange={e => setFormData({ ...formData, color_hex: e.target.value })}
                        />
                    </div>

                    <div className="w-[150px]">
                        <label className="block text-gray-400 text-sm mb-1">Statut</label>
                        <select
                            className="w-full bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                            value={formData.status}
                            onChange={e => setFormData({ ...formData, status: e.target.value })}
                        >
                            <option value="active">Actif</option>
                            <option value="coming_soon">Bientôt</option>
                            <option value="maintenance">Maintenance</option>
                        </select>
                    </div>

                    <div className="w-[100px]">
                        <label className="block text-gray-400 text-sm mb-1">Ordre</label>
                        <input
                            type="number"
                            className="w-full bg-gray-900 text-white rounded p-2 border border-gray-700 outline-none focus:border-blue-500"
                            value={formData.display_order}
                            onChange={e => setFormData({ ...formData, display_order: parseInt(e.target.value) })}
                        />
                    </div>

                    <div className="flex gap-2">
                        {isEditing && (
                            <button
                                type="button"
                                onClick={handleCancelEdit}
                                className="bg-gray-600 hover:bg-gray-500 text-white px-4 py-2 rounded font-medium transition-colors"
                            >
                                Annuler
                            </button>
                        )}
                        <button type="submit" className="bg-blue-600 hover:bg-blue-500 text-white px-6 py-2 rounded font-medium transition-colors">
                            {isEditing ? 'Mettre à jour' : 'Ajouter'}
                        </button>
                    </div>
                </form>
            </div>

            {/* Liste */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {services.map(service => (
                    <div key={service.id} className="bg-gray-800 rounded-lg overflow-hidden border border-gray-700 relative group">
                        <div className="h-32 bg-gray-900 flex items-center justify-center relative p-4" style={{ backgroundColor: service.color_hex + '20' }}>
                            <img src={service.logo_url} alt={service.name} className="h-16 object-contain" />
                            <div className={`absolute top-2 right-2 px-2 py-1 rounded text-xs font-bold ${service.status === 'active' ? 'bg-green-500/20 text-green-400' :
                                service.status === 'coming_soon' ? 'bg-yellow-500/20 text-yellow-400' : 'bg-red-500/20 text-red-400'
                                }`}>
                                {service.status === 'active' ? 'ACTIF' : service.status === 'coming_soon' ? 'BIENTÔT' : 'OFF'}
                            </div>
                            <div className="absolute top-2 left-2 px-2 py-1 bg-gray-700 rounded text-xs text-white">
                                #{service.display_order}
                            </div>
                        </div>
                        <div className="p-4">
                            <h3 className="text-white font-bold text-lg">{service.name}</h3>
                            <div className="flex justify-end gap-2 mt-4 opacity-100 transition-opacity">
                                <button
                                    onClick={() => handleEdit(service)}
                                    className="p-2 text-blue-400 hover:bg-blue-500/10 rounded"
                                    title="Modifier"
                                >
                                    <Edit2 size={18} />
                                </button>
                                <button
                                    onClick={() => handleDelete(service.id)}
                                    className="p-2 text-red-400 hover:bg-red-500/10 rounded"
                                    title="Supprimer"
                                >
                                    <Trash2 size={18} />
                                </button>
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}

export default ServicesManager;
