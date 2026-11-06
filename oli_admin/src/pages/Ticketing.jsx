import { useState, useEffect, useCallback } from 'react';
import { Plus, Trash2, Edit2, Ticket, CheckCircle, XCircle, Send } from 'lucide-react';
import api from '../services/api';

const CATEGORIES = ['concert', 'cinema', 'sport', 'conference', 'festival', 'autre'];
const EVENT_STATUS_LABEL = {
    draft: { text: 'Brouillon', cls: 'bg-gray-100 text-gray-700' },
    published: { text: 'Publié', cls: 'bg-green-100 text-green-700' },
    cancelled: { text: 'Annulé', cls: 'bg-red-100 text-red-700' },
    finished: { text: 'Terminé', cls: 'bg-blue-100 text-blue-700' },
};
const TICKET_STATUS_LABEL = {
    valid: { text: 'Valide', cls: 'bg-green-100 text-green-700' },
    used: { text: 'Utilisé', cls: 'bg-gray-200 text-gray-700' },
    cancelled: { text: 'Annulé', cls: 'bg-red-100 text-red-700' },
    refunded: { text: 'Remboursé', cls: 'bg-orange-100 text-orange-700' },
};

const EMPTY_FORM = {
    title: '', subtitle: '', category: 'concert', event_date: '',
    event_time: '', location: '', image_url: '', status: 'draft',
};

const fc = (n) => `${Number(n || 0).toLocaleString('fr-CD')} FC`;

function Ticketing() {
    const [tab, setTab] = useState('events');
    const [stats, setStats] = useState(null);
    const [events, setEvents] = useState([]);
    const [sales, setSales] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const [form, setForm] = useState(EMPTY_FORM);
    const [editId, setEditId] = useState(null);
    const [showForm, setShowForm] = useState(false);

    // Catégories de billets de l'événement ouvert
    const [openEvent, setOpenEvent] = useState(null);
    const [types, setTypes] = useState([]);
    const [typeForm, setTypeForm] = useState({ name: '', price_fc: '', quantity_total: '' });
    const [issueQty, setIssueQty] = useState({});

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [s, e] = await Promise.all([
                api.get('/admin/ticketing/stats'),
                api.get('/admin/ticketing/events'),
            ]);
            setStats(s.data);
            setEvents(e.data);
        } catch (err) {
            setError("Impossible de charger la billetterie. Vérifiez que la migration a été appliquée.");
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { load(); }, [load]);

    const loadSales = async (eventId = '') => {
        try {
            const res = await api.get('/admin/ticketing/sales' + (eventId ? `?event_id=${eventId}` : ''));
            setSales(res.data);
        } catch {
            setError('Impossible de charger les ventes.');
        }
    };

    const submitEvent = async (ev) => {
        ev.preventDefault();
        try {
            if (editId) await api.put(`/admin/ticketing/events/${editId}`, form);
            else await api.post('/admin/ticketing/events', form);
            setForm(EMPTY_FORM); setEditId(null); setShowForm(false);
            load();
        } catch (err) {
            alert(err.response?.data?.error || "Erreur lors de l'enregistrement");
        }
    };

    const editEvent = (e) => {
        setEditId(e.id);
        setForm({
            title: e.title || '', subtitle: e.subtitle || '', category: e.category || 'concert',
            event_date: e.event_date ? e.event_date.substring(0, 10) : '',
            event_time: e.event_time || '', location: e.location || '',
            image_url: e.image_url || '', status: e.status || 'draft',
        });
        setShowForm(true);
    };

    const setStatus = async (id, status) => {
        try {
            await api.patch(`/admin/ticketing/events/${id}/status`, { status });
            load();
        } catch (err) {
            alert(err.response?.data?.error || 'Erreur');
        }
    };

    const removeEvent = async (id) => {
        if (!window.confirm('Supprimer cet événement ?')) return;
        try {
            await api.delete(`/admin/ticketing/events/${id}`);
            load();
        } catch (err) {
            alert(err.response?.data?.error || 'Suppression impossible');
        }
    };

    const openTypes = async (e) => {
        setOpenEvent(e);
        try {
            const res = await api.get(`/admin/ticketing/events/${e.id}/types`);
            setTypes(res.data);
        } catch { setTypes([]); }
    };

    const addType = async (ev) => {
        ev.preventDefault();
        try {
            await api.post(`/admin/ticketing/events/${openEvent.id}/types`, typeForm);
            setTypeForm({ name: '', price_fc: '', quantity_total: '' });
            openTypes(openEvent);
            load();
        } catch (err) {
            alert(err.response?.data?.error || 'Erreur');
        }
    };

    const removeType = async (id) => {
        if (!window.confirm('Supprimer cette catégorie ?')) return;
        try {
            await api.delete(`/admin/ticketing/types/${id}`);
            openTypes(openEvent);
        } catch (err) {
            alert(err.response?.data?.error || 'Suppression impossible');
        }
    };

    const issueTickets = async (typeId) => {
        const quantity = parseInt(issueQty[typeId] || '1', 10);
        try {
            await api.post(`/admin/ticketing/events/${openEvent.id}/issue`, { ticket_type_id: typeId, quantity });
            alert(`${quantity} billet(s) émis.`);
            openTypes(openEvent);
            load();
        } catch (err) {
            alert(err.response?.data?.error || "Émission impossible");
        }
    };

    const setTicketStatus = async (id, status) => {
        try {
            await api.patch(`/admin/ticketing/tickets/${id}/status`, { status });
            loadSales();
        } catch (err) {
            alert(err.response?.data?.error || 'Erreur');
        }
    };

    if (loading) return <div className="p-8 text-gray-500">Chargement de la billetterie…</div>;

    return (
        <div className="p-6 space-y-6">
            <div className="flex items-center justify-between">
                <h1 className="text-2xl font-bold flex items-center gap-2">
                    <Ticket className="w-6 h-6 text-indigo-600" /> Billetterie O-Ticket
                </h1>
                <button
                    onClick={() => { setForm(EMPTY_FORM); setEditId(null); setShowForm(!showForm); }}
                    className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700"
                >
                    <Plus className="w-4 h-4" /> Nouvel événement
                </button>
            </div>

            {error && <div className="p-3 rounded-lg bg-red-50 text-red-700 text-sm">{error}</div>}

            {/* Statistiques */}
            {stats && (
                <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                    <Stat label="Événements" value={stats.total_events} />
                    <Stat label="Publiés" value={stats.published_events} />
                    <Stat label="Billets vendus" value={stats.tickets_sold} />
                    <Stat label="Billets utilisés" value={stats.tickets_used} />
                    <Stat label="Recettes" value={fc(stats.revenue_fc)} />
                </div>
            )}

            {/* Formulaire événement */}
            {showForm && (
                <form onSubmit={submitEvent} className="bg-white p-5 rounded-xl shadow space-y-4">
                    <h2 className="font-semibold">{editId ? "Modifier l'événement" : 'Nouvel événement'}</h2>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <Field label="Titre *" value={form.title} onChange={v => setForm({ ...form, title: v })} required />
                        <Field label="Sous-titre" value={form.subtitle} onChange={v => setForm({ ...form, subtitle: v })} />
                        <div>
                            <label className="block text-sm text-gray-600 mb-1">Catégorie</label>
                            <select className="w-full border rounded-lg px-3 py-2"
                                value={form.category} onChange={e => setForm({ ...form, category: e.target.value })}>
                                {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm text-gray-600 mb-1">Statut</label>
                            <select className="w-full border rounded-lg px-3 py-2"
                                value={form.status} onChange={e => setForm({ ...form, status: e.target.value })}>
                                {Object.keys(EVENT_STATUS_LABEL).map(s =>
                                    <option key={s} value={s}>{EVENT_STATUS_LABEL[s].text}</option>)}
                            </select>
                        </div>
                        <Field label="Date *" type="date" value={form.event_date} onChange={v => setForm({ ...form, event_date: v })} required />
                        <Field label="Heure" placeholder="20:00" value={form.event_time} onChange={v => setForm({ ...form, event_time: v })} />
                        <Field label="Lieu *" value={form.location} onChange={v => setForm({ ...form, location: v })} required />
                        <Field label="Image (URL)" value={form.image_url} onChange={v => setForm({ ...form, image_url: v })} />
                    </div>
                    <div className="flex gap-2">
                        <button type="submit" className="bg-indigo-600 text-white px-4 py-2 rounded-lg">
                            {editId ? 'Enregistrer' : 'Créer'}
                        </button>
                        <button type="button" onClick={() => { setShowForm(false); setEditId(null); }}
                            className="px-4 py-2 rounded-lg border">Annuler</button>
                    </div>
                </form>
            )}

            {/* Onglets */}
            <div className="flex gap-2 border-b">
                <Tab active={tab === 'events'} onClick={() => setTab('events')}>Événements ({events.length})</Tab>
                <Tab active={tab === 'sales'} onClick={() => { setTab('sales'); loadSales(); }}>Ventes</Tab>
            </div>

            {/* Événements */}
            {tab === 'events' && (
                <div className="bg-white rounded-xl shadow overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead className="bg-gray-50 text-gray-600">
                            <tr>
                                <Th>Événement</Th><Th>Date</Th><Th>Lieu</Th><Th>Statut</Th>
                                <Th>Vendus</Th><Th>Recettes</Th><Th>Actions</Th>
                            </tr>
                        </thead>
                        <tbody>
                            {events.length === 0 && (
                                <tr><td colSpan="7" className="p-6 text-center text-gray-400">Aucun événement</td></tr>
                            )}
                            {events.map(e => {
                                const st = EVENT_STATUS_LABEL[e.status] || EVENT_STATUS_LABEL.draft;
                                return (
                                    <tr key={e.id} className="border-t hover:bg-gray-50">
                                        <td className="p-3">
                                            <div className="font-medium">{e.title}</div>
                                            <div className="text-xs text-gray-500">{e.category}</div>
                                        </td>
                                        <td className="p-3">{(e.event_date || '').substring(0, 10)} {e.event_time || ''}</td>
                                        <td className="p-3">{e.location}</td>
                                        <td className="p-3"><span className={`px-2 py-1 rounded-full text-xs ${st.cls}`}>{st.text}</span></td>
                                        <td className="p-3">{e.tickets_sold}{e.capacity > 0 ? ` / ${e.capacity}` : ''}</td>
                                        <td className="p-3 font-medium">{fc(e.revenue_fc)}</td>
                                        <td className="p-3">
                                            <div className="flex gap-2">
                                                <button onClick={() => openTypes(e)} title="Billets"
                                                    className="p-1.5 rounded hover:bg-indigo-50 text-indigo-600"><Ticket className="w-4 h-4" /></button>
                                                <button onClick={() => editEvent(e)} title="Modifier"
                                                    className="p-1.5 rounded hover:bg-gray-100"><Edit2 className="w-4 h-4" /></button>
                                                {e.status !== 'published'
                                                    ? <button onClick={() => setStatus(e.id, 'published')} title="Publier"
                                                        className="p-1.5 rounded hover:bg-green-50 text-green-600"><CheckCircle className="w-4 h-4" /></button>
                                                    : <button onClick={() => setStatus(e.id, 'cancelled')} title="Annuler"
                                                        className="p-1.5 rounded hover:bg-red-50 text-red-600"><XCircle className="w-4 h-4" /></button>}
                                                <button onClick={() => removeEvent(e.id)} title="Supprimer"
                                                    className="p-1.5 rounded hover:bg-red-50 text-red-600"><Trash2 className="w-4 h-4" /></button>
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}

            {/* Ventes */}
            {tab === 'sales' && (
                <div className="bg-white rounded-xl shadow overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead className="bg-gray-50 text-gray-600">
                            <tr><Th>Code</Th><Th>Événement</Th><Th>Catégorie</Th><Th>Acheteur</Th><Th>Prix</Th><Th>Statut</Th><Th>Actions</Th></tr>
                        </thead>
                        <tbody>
                            {sales.length === 0 && (
                                <tr><td colSpan="7" className="p-6 text-center text-gray-400">Aucune vente</td></tr>
                            )}
                            {sales.map(t => {
                                const st = TICKET_STATUS_LABEL[t.status] || TICKET_STATUS_LABEL.valid;
                                return (
                                    <tr key={t.id} className="border-t hover:bg-gray-50">
                                        <td className="p-3 font-mono text-xs">{t.ticket_code}</td>
                                        <td className="p-3">{t.event_title}</td>
                                        <td className="p-3">{t.type_name || '—'}</td>
                                        <td className="p-3">{t.buyer_name || 'Guichet'}<div className="text-xs text-gray-500">{t.buyer_phone || ''}</div></td>
                                        <td className="p-3">{fc(t.price_paid_fc)}</td>
                                        <td className="p-3"><span className={`px-2 py-1 rounded-full text-xs ${st.cls}`}>{st.text}</span></td>
                                        <td className="p-3">
                                            <div className="flex gap-2">
                                                {t.status === 'valid' && (
                                                    <button onClick={() => setTicketStatus(t.id, 'used')}
                                                        className="text-xs px-2 py-1 rounded border hover:bg-gray-50">Marquer utilisé</button>
                                                )}
                                                {t.status !== 'cancelled' && (
                                                    <button onClick={() => setTicketStatus(t.id, 'cancelled')}
                                                        className="text-xs px-2 py-1 rounded border text-red-600 hover:bg-red-50">Annuler</button>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}

            {/* Panneau catégories de billets */}
            {openEvent && (
                <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50"
                    onClick={() => setOpenEvent(null)}>
                    <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl p-5 space-y-4"
                        onClick={e => e.stopPropagation()}>
                        <div className="flex items-center justify-between">
                            <h2 className="font-semibold">Billets — {openEvent.title}</h2>
                            <button onClick={() => setOpenEvent(null)} className="text-gray-400 hover:text-gray-700">✕</button>
                        </div>

                        <table className="w-full text-sm">
                            <thead className="bg-gray-50 text-gray-600">
                                <tr><Th>Catégorie</Th><Th>Prix</Th><Th>Vendus / Total</Th><Th>Émettre</Th><Th></Th></tr>
                            </thead>
                            <tbody>
                                {types.length === 0 && (
                                    <tr><td colSpan="5" className="p-4 text-center text-gray-400">Aucune catégorie</td></tr>
                                )}
                                {types.map(t => (
                                    <tr key={t.id} className="border-t">
                                        <td className="p-2 font-medium">{t.name}</td>
                                        <td className="p-2">{fc(t.price_fc)}</td>
                                        <td className="p-2">{t.quantity_sold} / {t.quantity_total || '∞'}</td>
                                        <td className="p-2">
                                            <div className="flex items-center gap-1">
                                                <input type="number" min="1" placeholder="1"
                                                    className="w-16 border rounded px-2 py-1"
                                                    value={issueQty[t.id] || ''}
                                                    onChange={e => setIssueQty({ ...issueQty, [t.id]: e.target.value })} />
                                                <button onClick={() => issueTickets(t.id)}
                                                    className="p-1.5 rounded bg-indigo-600 text-white hover:bg-indigo-700"
                                                    title="Émettre au guichet"><Send className="w-3.5 h-3.5" /></button>
                                            </div>
                                        </td>
                                        <td className="p-2">
                                            <button onClick={() => removeType(t.id)}
                                                className="p-1.5 rounded text-red-600 hover:bg-red-50"><Trash2 className="w-4 h-4" /></button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>

                        <form onSubmit={addType} className="flex flex-wrap gap-2 items-end border-t pt-4">
                            <Field label="Catégorie" value={typeForm.name} onChange={v => setTypeForm({ ...typeForm, name: v })} required small />
                            <Field label="Prix (FC)" type="number" value={typeForm.price_fc} onChange={v => setTypeForm({ ...typeForm, price_fc: v })} required small />
                            <Field label="Quantité" type="number" value={typeForm.quantity_total} onChange={v => setTypeForm({ ...typeForm, quantity_total: v })} required small />
                            <button type="submit" className="bg-indigo-600 text-white px-4 py-2 rounded-lg">Ajouter</button>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

const Stat = ({ label, value }) => (
    <div className="bg-white p-4 rounded-xl shadow">
        <div className="text-xs text-gray-500">{label}</div>
        <div className="text-xl font-bold mt-1">{value ?? 0}</div>
    </div>
);

const Th = ({ children }) => <th className="p-3 text-left font-medium">{children}</th>;

const Tab = ({ active, onClick, children }) => (
    <button onClick={onClick}
        className={`px-4 py-2 -mb-px border-b-2 text-sm font-medium ${active ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500'}`}>
        {children}
    </button>
);

const Field = ({ label, value, onChange, type = 'text', required, placeholder, small }) => (
    <div className={small ? 'w-32' : ''}>
        <label className="block text-sm text-gray-600 mb-1">{label}</label>
        <input type={type} value={value} required={required} placeholder={placeholder}
            onChange={e => onChange(e.target.value)}
            className="w-full border rounded-lg px-3 py-2" />
    </div>
);

export default Ticketing;
