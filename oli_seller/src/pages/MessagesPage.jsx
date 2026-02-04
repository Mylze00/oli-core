import { useState, useEffect, useRef, useCallback } from 'react';
import {
    MessageCircle, Send, Image, Paperclip, Search,
    ChevronLeft, User, Package, RefreshCw, Clock,
    Check, CheckCheck, MoreVertical
} from 'lucide-react';
import { sellerAPI } from '../services/api';
import io from 'socket.io-client';

const API_BASE = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

export default function MessagesPage() {
    const [conversations, setConversations] = useState([]);
    const [selectedConversation, setSelectedConversation] = useState(null);
    const [messages, setMessages] = useState([]);
    const [newMessage, setNewMessage] = useState('');
    const [loading, setLoading] = useState(true);
    const [sending, setSending] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const messagesEndRef = useRef(null);
    const socketRef = useRef(null);
    const fileInputRef = useRef(null);

    // Charger les conversations
    useEffect(() => {
        loadConversations();
        initSocket();

        return () => {
            if (socketRef.current) {
                socketRef.current.disconnect();
            }
        };
    }, []);

    const initSocket = () => {
        const token = localStorage.getItem('seller_token');
        if (!token) return;

        socketRef.current = io(API_BASE, {
            auth: { token },
            transports: ['websocket', 'polling']
        });

        socketRef.current.on('connect', () => {
            console.log('🔌 Socket connected');
        });

        socketRef.current.on('new_message', (data) => {
            // Ajouter le message à la conversation active
            if (selectedConversation && data.conversation_id === selectedConversation.conversation_id) {
                setMessages(prev => [...prev, data]);
                scrollToBottom();
            }
            // Mettre à jour la liste des conversations
            loadConversations();
        });

        socketRef.current.on('messages_read', (data) => {
            // Marquer les messages comme lus
            setMessages(prev => prev.map(msg =>
                msg.conversation_id === data.conversation_id ? { ...msg, is_read: true } : msg
            ));
        });
    };

    const loadConversations = async () => {
        try {
            setLoading(true);
            const data = await sellerAPI.getConversations();
            setConversations(data || []);
        } catch (err) {
            console.error('Erreur chargement conversations:', err);
        } finally {
            setLoading(false);
        }
    };

    const loadMessages = async (otherUserId, productId = null) => {
        try {
            const data = await sellerAPI.getMessages(otherUserId, productId);
            setMessages(data.messages || []);
            scrollToBottom();
        } catch (err) {
            console.error('Erreur chargement messages:', err);
        }
    };

    const handleSelectConversation = (conv) => {
        setSelectedConversation(conv);
        loadMessages(conv.other_id, conv.product_id);
    };

    const sendMessage = async () => {
        if (!newMessage.trim() || !selectedConversation || sending) return;

        try {
            setSending(true);
            await sellerAPI.sendChatMessage({
                conversationId: selectedConversation.conversation_id,
                content: newMessage.trim(),
                recipientId: selectedConversation.other_id
            });
            setNewMessage('');
            // Le message sera ajouté via WebSocket
        } catch (err) {
            console.error('Erreur envoi message:', err);
            alert('Erreur lors de l\'envoi du message');
        } finally {
            setSending(false);
        }
    };

    const handleFileUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file || !selectedConversation) return;

        try {
            setSending(true);
            const uploadResult = await sellerAPI.uploadChatFile(file);

            await sellerAPI.sendChatMessage({
                conversationId: selectedConversation.conversation_id,
                content: file.type.startsWith('image/') ? '📷 Image' : '📎 Fichier',
                recipientId: selectedConversation.other_id,
                type: 'media',
                mediaUrl: uploadResult.url,
                mediaType: uploadResult.type
            });
        } catch (err) {
            console.error('Erreur upload:', err);
            alert('Erreur lors de l\'upload');
        } finally {
            setSending(false);
        }
    };

    const scrollToBottom = () => {
        setTimeout(() => {
            messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
        }, 100);
    };

    const formatTime = (dateStr) => {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        const now = new Date();
        const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

        if (diffDays === 0) {
            return date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
        } else if (diffDays === 1) {
            return 'Hier';
        } else if (diffDays < 7) {
            return date.toLocaleDateString('fr-FR', { weekday: 'short' });
        }
        return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
    };

    const getAvatarUrl = (url) => {
        if (!url) return null;
        if (url.startsWith('http')) return url;
        return `${API_BASE}${url}`;
    };

    const filteredConversations = conversations.filter(c =>
        c.other_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.product_name?.toLowerCase().includes(searchQuery.toLowerCase())
    );

    const currentUser = JSON.parse(localStorage.getItem('seller_user') || '{}');

    return (
        <div className="h-screen flex bg-gray-50">
            {/* Liste des conversations */}
            <div className={`w-full md:w-96 bg-white border-r border-gray-200 flex flex-col ${selectedConversation ? 'hidden md:flex' : 'flex'}`}>
                <div className="p-4 border-b border-gray-100">
                    <h1 className="text-xl font-bold text-gray-900 mb-3">Messages</h1>
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                        <input
                            type="text"
                            placeholder="Rechercher..."
                            className="w-full pl-10 pr-4 py-2 bg-gray-100 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                        />
                    </div>
                </div>

                {loading ? (
                    <div className="flex-1 flex items-center justify-center">
                        <RefreshCw className="animate-spin text-blue-600" size={24} />
                    </div>
                ) : filteredConversations.length === 0 ? (
                    <div className="flex-1 flex flex-col items-center justify-center text-gray-400 p-8">
                        <MessageCircle size={48} className="mb-4" />
                        <p className="text-center">Aucune conversation</p>
                        <p className="text-sm text-center mt-1">Les messages des clients apparaîtront ici</p>
                    </div>
                ) : (
                    <div className="flex-1 overflow-y-auto">
                        {filteredConversations.map(conv => (
                            <div
                                key={conv.conversation_id}
                                onClick={() => handleSelectConversation(conv)}
                                className={`p-4 border-b border-gray-100 cursor-pointer hover:bg-gray-50 transition-colors ${selectedConversation?.conversation_id === conv.conversation_id ? 'bg-blue-50' : ''
                                    }`}
                            >
                                <div className="flex items-start gap-3">
                                    {conv.other_avatar ? (
                                        <img
                                            src={getAvatarUrl(conv.other_avatar)}
                                            alt={conv.other_name}
                                            className="w-12 h-12 rounded-full object-cover"
                                            onError={(e) => e.target.src = `https://ui-avatars.com/api/?name=${conv.other_name || 'U'}`}
                                        />
                                    ) : (
                                        <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center">
                                            <User className="text-blue-600" size={24} />
                                        </div>
                                    )}
                                    <div className="flex-1 min-w-0">
                                        <div className="flex justify-between items-start">
                                            <p className="font-medium text-gray-900 truncate">{conv.other_name}</p>
                                            <span className="text-xs text-gray-400 whitespace-nowrap ml-2">
                                                {formatTime(conv.last_time)}
                                            </span>
                                        </div>
                                        {conv.product_name && (
                                            <p className="text-xs text-blue-600 flex items-center gap-1 truncate">
                                                <Package size={12} /> {conv.product_name}
                                            </p>
                                        )}
                                        <p className="text-sm text-gray-500 truncate">{conv.last_message}</p>
                                    </div>
                                    {conv.unread_count > 0 && (
                                        <span className="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
                                            {conv.unread_count}
                                        </span>
                                    )}
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>

            {/* Zone de chat */}
            {selectedConversation ? (
                <div className="flex-1 flex flex-col">
                    {/* Header */}
                    <div className="bg-white border-b border-gray-200 p-4 flex items-center gap-3">
                        <button
                            onClick={() => setSelectedConversation(null)}
                            className="md:hidden p-2 hover:bg-gray-100 rounded-lg"
                        >
                            <ChevronLeft size={20} />
                        </button>
                        {selectedConversation.other_avatar ? (
                            <img
                                src={getAvatarUrl(selectedConversation.other_avatar)}
                                alt={selectedConversation.other_name}
                                className="w-10 h-10 rounded-full object-cover"
                            />
                        ) : (
                            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center">
                                <User className="text-blue-600" size={20} />
                            </div>
                        )}
                        <div className="flex-1">
                            <p className="font-medium text-gray-900">{selectedConversation.other_name}</p>
                            {selectedConversation.product_name && (
                                <p className="text-xs text-blue-600">À propos: {selectedConversation.product_name}</p>
                            )}
                        </div>
                    </div>

                    {/* Messages */}
                    <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-gray-50">
                        {messages.map((msg, idx) => {
                            const isOwn = msg.sender_id === currentUser.id;
                            const metadata = typeof msg.metadata === 'string' ? JSON.parse(msg.metadata || '{}') : (msg.metadata || {});

                            return (
                                <div key={msg.id || idx} className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
                                    <div className={`max-w-[75%] ${isOwn ? 'order-2' : ''}`}>
                                        <div className={`p-3 rounded-2xl ${isOwn
                                                ? 'bg-blue-600 text-white rounded-br-sm'
                                                : 'bg-white text-gray-900 rounded-bl-sm shadow-sm'
                                            }`}>
                                            {metadata.mediaUrl && metadata.mediaType === 'image' && (
                                                <img
                                                    src={metadata.mediaUrl}
                                                    alt="Image"
                                                    className="rounded-lg mb-2 max-w-full"
                                                />
                                            )}
                                            <p className="text-sm">{msg.content}</p>
                                        </div>
                                        <div className={`flex items-center gap-1 mt-1 ${isOwn ? 'justify-end' : ''}`}>
                                            <span className="text-xs text-gray-400">
                                                {formatTime(msg.created_at)}
                                            </span>
                                            {isOwn && (
                                                msg.is_read
                                                    ? <CheckCheck size={14} className="text-blue-500" />
                                                    : <Check size={14} className="text-gray-400" />
                                            )}
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                        <div ref={messagesEndRef} />
                    </div>

                    {/* Input */}
                    <div className="bg-white border-t border-gray-200 p-4">
                        <div className="flex items-center gap-3">
                            <input
                                type="file"
                                ref={fileInputRef}
                                className="hidden"
                                accept="image/*"
                                onChange={handleFileUpload}
                            />
                            <button
                                onClick={() => fileInputRef.current?.click()}
                                className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                            >
                                <Image size={20} />
                            </button>
                            <input
                                type="text"
                                placeholder="Écrire un message..."
                                className="flex-1 px-4 py-2 bg-gray-100 rounded-full focus:ring-2 focus:ring-blue-500 outline-none"
                                value={newMessage}
                                onChange={(e) => setNewMessage(e.target.value)}
                                onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
                            />
                            <button
                                onClick={sendMessage}
                                disabled={!newMessage.trim() || sending}
                                className="p-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                {sending ? (
                                    <RefreshCw className="animate-spin" size={20} />
                                ) : (
                                    <Send size={20} />
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            ) : (
                <div className="hidden md:flex flex-1 items-center justify-center bg-gray-50">
                    <div className="text-center text-gray-400">
                        <MessageCircle size={64} className="mx-auto mb-4" />
                        <p className="text-lg font-medium">Sélectionnez une conversation</p>
                        <p className="text-sm">Choisissez un client pour voir les messages</p>
                    </div>
                </div>
            )}
        </div>
    );
}
