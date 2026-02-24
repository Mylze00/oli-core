import { useState, useEffect } from 'react';
import { Trash2, Plus, Edit2, Upload } from 'lucide-react';
import api from '../services/api';

function ServicesManager() {
    const [services, setServices] = useState([]);
    const [loading, setLoading] = useState(true);
    const [formData, setFormData] = useState({
        name: '',
        logo_url: '',
        color_hex: '#2563EB',
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
            const res = await api.get('/admin/services');
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
            await api.delete(`/admin/services/${id}`);
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
        setFormData({ name: '', logo_url: '', color_hex: '#2563EB', status: 'coming_soon', display_order: 0 });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            let res;
            if (isEditing) {
                res = await api.put(`/admin/services/${editId}`, formData);
                setServices(services.map(s => s.id === editId ? res.data : s));
            } else {
                res = await api.post('/admin/services', formData);
                setServices([res.data, ...services]);
            }
            handleCancelEdit();
        } catch (err) {
            alert('Erreur sauvegarde service');
        }
    };

    const handleUpload = async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const uploadData = new FormData();
        uploadData.append('image', file);
        try {
            setLoading(true);
            const res = await api.post('/admin/services/upload', uploadData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });
            setFormData(prev => ({ ...prev, logo_url: res.data.url }));
        } catch (err) {
            alert("Erreur upload image");
        } finally {
            setLoading(false);
        }
    };

    const statusInfo = (status) => {
        const map = {
            active: { label: 'ACTIF', bg: 'bg-green-100 text-green-700' },
            coming_soon: { label: 'BIENTÔT', bg: 'bg-amber-100 text-amber-700' },
            maintenance: { label: 'OFF', bg: 'bg-red-100 text-red-700' },
        };
        return map[status] || map.coming_soon;
    };

    if (loading && services.length === 0) return (
        <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
    );

    return (
        <div className="space-y-6 p-4 md:p-6 bg-gray-50 min-h-screen">
            <div>
                <h1 className="text-2xl font-bold text-gray-900">Services & Paiements</h1>
                <p className="text-sm text-gray-400 mt-1">Gérez les services disponibles dans l'application</p>
            </div>

            {/* Formulaire */}
            <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
                <h2 className="text-sm font-semibold text-gray-700 mb-4 flex items-center gap-2">
                    {isEditing ? <Edit2 size={18} className="text-blue-500" /> : <Plus size={18} className="text-blue-500" />}
                    {isEditing ? 'Modifier le service' : 'Ajouter un service'}
                </h2>
                <form onSubmit={handleSubmit} className="flex gap-4 flex-wrap items-end">
                    <div className="flex-1 min-w-[200px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Nom du service</label>
                        <input
                            type="text"
                            required
                            className="w-full bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            value={formData.name}
                            onChange={e => setFormData({ ...formData, name: e.target.value })}
                        />
                    </div>

                    <div className="flex-1 min-w-[220px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Logo URL</label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                required
                                value={formData.logo_url}
                                onChange={e => setFormData({ ...formData, logo_url: e.target.value })}
                                className="flex-1 bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            />
                            <label className="bg-gray-100 hover:bg-gray-200 text-gray-600 px-3 py-2.5 rounded-xl cursor-pointer transition flex items-center">
                                <Upload size={16} />
                                <input type="file" className="hidden" accept="image/*" onChange={handleUpload} />
                            </label>
                        </div>
                    </div>

                    <div className="w-[120px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Couleur</label>
                        <input
                            type="color"
                            className="w-full h-[42px] rounded-xl cursor-pointer border border-gray-200"
                            value={formData.color_hex}
                            onChange={e => setFormData({ ...formData, color_hex: e.target.value })}
                        />
                    </div>

                    <div className="w-[150px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Statut</label>
                        <select
                            className="w-full bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            value={formData.status}
                            onChange={e => setFormData({ ...formData, status: e.target.value })}
                        >
                            <option value="active">Actif</option>
                            <option value="coming_soon">Bientôt</option>
                            <option value="maintenance">Maintenance</option>
                        </select>
                    </div>

                    <div className="w-[90px]">
                        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Ordre</label>
                        <input
                            type="number"
                            className="w-full bg-gray-50 text-gray-900 rounded-xl px-3 py-2.5 border border-gray-200 outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            value={formData.display_order}
                            onChange={e => setFormData({ ...formData, display_order: parseInt(e.target.value) })}
                        />
                    </div>

                    <div className="flex gap-2">
                        {isEditing && (
                            <button type="button" onClick={handleCancelEdit}
                                className="px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl font-medium text-sm transition hover:bg-gray-200">
                                Annuler
                            </button>
                        )}
                        <button type="submit"
                            className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold text-sm transition shadow-sm">
                            {isEditing ? 'Mettre à jour' : 'Ajouter'}
                        </button>
                    </div>
                </form>
            </div>

            {/* Liste */}
            {services.length === 0 ? (
                <div className="bg-white rounded-2xl border border-dashed border-gray-200 p-12 text-center">
                    <p className="text-gray-400 text-sm">Aucun service configuré.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    {services.map(service => {
                        const s = statusInfo(service.status);
                        return (
                            <div key={service.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                                <div className="h-32 flex items-center justify-center relative p-4" style={{ backgroundColor: service.color_hex + '15' }}>
                                    <img src={service.logo_url} alt={service.name} className="h-16 object-contain" />
                                    <div className={`absolute top-2 right-2 px-2.5 py-1 rounded-full text-xs font-bold ${s.bg}`}>
                                        {s.label}
                                    </div>
                                    <div className="absolute top-2 left-2 w-6 h-6 bg-white rounded-full flex items-center justify-center shadow-sm text-xs font-bold text-gray-600">
                                        {service.display_order}
                                    </div>
                                </div>
                                <div className="p-4">
                                    <h3 className="text-gray-900 font-bold text-base">{service.name}</h3>
                                    <div className="flex justify-end gap-2 mt-3">
                                        <button onClick={() => handleEdit(service)}
                                            className="p-2 text-blue-500 hover:bg-blue-50 rounded-lg transition" title="Modifier">
                                            <Edit2 size={16} />
                                        </button>
                                        <button onClick={() => handleDelete(service.id)}
                                            className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition" title="Supprimer">
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
}

export default ServicesManager;
