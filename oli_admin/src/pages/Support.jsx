import { useEffect, useState, useRef } from 'react';
import api from '../services/api';
import { getImageUrl } from '../utils/image';
import {
    ChatBubbleLeftRightIcon,
    UserIcon,
    ClockIcon,
    CheckCircleIcon,
    XCircleIcon,
    PaperAirplaneIcon,
    ExclamationTriangleIcon
} from '@heroicons/react/24/solid';

const PRIORITY_COLORS = {
    low: 'bg-gray-100 text-gray-800',
    normal: 'bg-blue-100 text-blue-800',
    high: 'bg-orange-100 text-orange-800',
    urgent: 'bg-red-100 text-red-800'
};

const STATUS_COLORS = {
    open: 'bg-green-100 text-green-800',
    pending: 'bg-yellow-100 text-yellow-800',
    resolved: 'bg-gray-100 text-gray-800',
    closed: 'bg-gray-200 text-gray-600'
};

export default function Support() {
    const [tickets, setTickets] = useState([]);
    const [stats, setStats] = useState({});
    const [loading, setLoading] = useState(true);
    const [selectedTicket, setSelectedTicket] = useState(null);
    const [ticketDetail, setTicketDetail] = useState(null);
    const [messages, setMessages] = useState([]);
    const [msgLoading, setMsgLoading] = useState(false);
    const [msgError, setMsgError] = useState(null);
    const [reply, setReply] = useState('');
    const scrollRef = useRef(null);

    useEffect(() => {
        fetchTickets();
        fetchStats();
    }, []);

    // Use selectedTicket?.id to avoid infinite re-triggers
    const selectedTicketId = selectedTicket?.id;
    useEffect(() => {
        if (selectedTicketId) {
            fetchMessages(selectedTicketId);
        }
    }, [selectedTicketId]);

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [messages]);

    const fetchTickets = async () => {
        try {
            const { data } = await api.get('/admin/support');
            setTickets(data);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const fetchStats = async () => {
        try {
            const { data } = await api.get('/admin/support/stats');
            setStats(data);
        } catch (error) {
            console.error(error);
        }
    };

    const fetchMessages = async (ticketId) => {
        setMsgLoading(true);
        setMsgError(null);
        try {
            const { data } = await api.get(`/admin/support/${ticketId}`);
            setMessages(data.messages || []);
            // Store detail separately to avoid re-triggering useEffect
            setTicketDetail(data.ticket);
        } catch (error) {
            console.error('Erreur chargement messages:', error);
            setMsgError('Impossible de charger la conversation');
            setMessages([]);
        } finally {
            setMsgLoading(false);
        }
    };

    const sendReply = async (e) => {
        e.preventDefault();
        if (!reply.trim()) return;

        try {
            await api.post(`/admin/support/${selectedTicket.id}/reply`, {
                message: reply,
                status: 'pending' // Devient en attente de la réponse user
            });
            setReply('');
            fetchMessages(selectedTicket.id);
            fetchTickets(); // Refresh list to update status/date
        } catch (error) {
            alert('Erreur envoi réponse');
        }
    };

    const startTicket = (ticket) => {
        setSelectedTicket(ticket);
        setTicketDetail(null);
        setMessages([]);
    };

    const updateStatus = async (status) => {
        if (!window.confirm(`Passer le ticket en ${status} ?`)) return;
        try {
            await api.patch(`/admin/support/${selectedTicket.id}`, { status });
            fetchMessages(selectedTicket.id);
            fetchTickets();
        } catch (error) {
            alert('Erreur maj status');
        }
    };

    if (loading) return <div>Chargement...</div>;

    return (
        <div className="flex h-[calc(100vh-8rem)] gap-6">
            {/* Liste des tickets */}
            <div className={`${selectedTicket ? 'w-1/3 hidden md:block' : 'w-full'} bg-white shadow rounded-lg flex flex-col`}>
                <div className="p-4 border-b">
                    <h2 className="text-lg font-bold flex items-center gap-2">
                        <ChatBubbleLeftRightIcon className="h-5 w-5" />
                        Tickets Support
                    </h2>
                    <div className="flex gap-2 mt-2 text-xs">
                        <span className="bg-green-100 text-green-800 px-2 py-0.5 rounded">
                            {stats.open_count || 0} Ouverts
                        </span>
                        <span className="bg-red-100 text-red-800 px-2 py-0.5 rounded">
                            {stats.urgent_count || 0} Urgents
                        </span>
                    </div>
                </div>

                <div className="flex-1 overflow-y-auto">
                    {tickets.length === 0 && (
                        <div className="p-8 text-center text-gray-500">Aucun ticket</div>
                    )}
                    {tickets.map(ticket => (
                        <div
                            key={ticket.id}
                            onClick={() => startTicket(ticket)}
                            className={`p-4 border-b cursor-pointer hover:bg-gray-50 ${selectedTicket?.id === ticket.id ? 'bg-blue-50 border-l-4 border-l-blue-500' : ''}`}
                        >
                            <div className="flex justify-between items-start mb-1">
                                <span className={`text-xs px-2 py-0.5 rounded-full uppercase font-bold ${PRIORITY_COLORS[ticket.priority]}`}>
                                    {ticket.priority}
                                </span>
                                <span className="text-xs text-gray-400">
                                    {new Date(ticket.updated_at).toLocaleDateString()}
                                </span>
                            </div>
                            <h3 className="font-semibold text-gray-900 truncate">{ticket.subject}</h3>
                            <div className="flex justify-between items-center mt-2">
                                <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[ticket.status]}`}>
                                    {ticket.status}
                                </span>
                                <div className="flex items-center gap-1 text-xs text-gray-500">
                                    <UserIcon className="h-3 w-3" />
                                    {ticket.user_name}
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Zone de discussion */}
            {selectedTicket ? (
                <div className="flex-1 bg-white shadow rounded-lg flex flex-col h-full border overflow-hidden">
                    {/* Header Chat */}
                    <div className="p-4 border-b flex justify-between items-center bg-gray-50">
                        <div>
                            <div className="flex items-center gap-2">
                                <button onClick={() => setSelectedTicket(null)} className="md:hidden mr-2 text-gray-500">
                                    ←
                                </button>
                                <h3 className="font-bold text-lg">#{selectedTicket.id} - {selectedTicket.subject}</h3>
                            </div>
                            <p className="text-sm text-gray-500 ml-6 md:ml-0">
                                {ticketDetail?.user_name || selectedTicket.user_name} ({ticketDetail?.user_phone || selectedTicket.user_phone})
                            </p>
                        </div>
                        <div className="flex gap-2">
                            {selectedTicket.status !== 'resolved' && (
                                <button
                                    onClick={() => updateStatus('resolved')}
                                    className="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-sm flex items-center gap-1"
                                >
                                    <CheckCircleIcon className="h-4 w-4" /> Résoudre
                                </button>
                            )}
                            <button
                                onClick={() => updateStatus('closed')}
                                className="bg-gray-200 hover:bg-gray-300 text-gray-800 px-3 py-1 rounded text-sm"
                            >
                                Fermer
                            </button>
                        </div>
                    </div>

                    {/* Messages */}
                    <div className="flex-1 overflow-y-auto p-4 bg-slate-50 space-y-4" ref={scrollRef}>
                        {msgLoading ? (
                            <div className="text-center text-gray-400 mt-10">Chargement de la conversation...</div>
                        ) : msgError ? (
                            <div className="text-center text-red-400 mt-10">
                                <ExclamationTriangleIcon className="h-8 w-8 mx-auto mb-2" />
                                <p>{msgError}</p>
                                <button onClick={() => fetchMessages(selectedTicket.id)} className="mt-2 text-blue-500 underline text-sm">Réessayer</button>
                            </div>
                        ) : (
                            <>
                                {messages.length === 0 && (
                                    <div className="text-center text-gray-400 italic my-4">Début de la conversation</div>
                                )}
                                {messages.map(msg => {
                                    // Compare against ticket user_id: if sender is NOT the user, it's admin/staff
                                    const ticketUserId = ticketDetail?.user_id || selectedTicket.user_id;
                                    const isMe = msg.sender_id !== ticketUserId;

                                    const roleStyle = isMe ? 'ml-auto bg-blue-600 text-white' : 'mr-auto bg-white border text-gray-800';

                                    return (
                                        <div key={msg.id} className={`flex flex-col max-w-[80%] ${isMe ? 'items-end' : 'items-start'}`}>
                                            <div className={`p-3 rounded-lg shadow-sm ${roleStyle}`}>
                                                <p className="text-sm whitespace-pre-wrap">{msg.message}</p>
                                            </div>
                                            <span className="text-xs text-gray-400 mt-1">
                                                {msg.sender_name} • {new Date(msg.created_at).toLocaleString()}
                                            </span>
                                        </div>
                                    );
                                })}
                            </>
                        )}
                    </div>

                    {/* Input */}
                    <form onSubmit={sendReply} className="p-4 border-t bg-white">
                        <div className="flex gap-2">
                            <input
                                type="text"
                                className="flex-1 border rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500 outline-none"
                                placeholder="Écrire une réponse..."
                                value={reply}
                                onChange={(e) => setReply(e.target.value)}
                            />
                            <button
                                type="submit"
                                disabled={!reply.trim()}
                                className="bg-blue-600 hover:bg-blue-700 text-white p-2 rounded-lg disabled:opacity-50 transition"
                            >
                                <PaperAirplaneIcon className="h-6 w-6" />
                            </button>
                        </div>
                    </form>
                </div>
            ) : (
                <div className="flex-1 hidden md:flex items-center justify-center bg-gray-50 rounded-lg border border-dashed border-gray-300">
                    <div className="text-center text-gray-400">
                        <ChatBubbleLeftRightIcon className="h-16 w-16 mx-auto mb-4 opacity-50" />
                        <p className="text-lg">Sélectionnez un ticket pour voir la conversation</p>
                    </div>
                </div>
            )}
        </div>
    );
}
