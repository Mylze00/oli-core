import io from 'socket.io-client';

class SocketService {
    constructor() {
        this.socket = null;
        this.listeners = new Map();
    }

    connect(token) {
        if (this.socket?.connected) {
            console.log('🟡 Socket already connected');
            return;
        }

        const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

        this.socket = io(API_URL, {
            transports: ['websocket'],
            auth: { token: `Bearer ${token}` },
            reconnection: true,
            reconnectionDelay: 1000,
            reconnectionAttempts: 5
        });

        this.socket.on('connect', () => {
            console.log('🟢 Socket.IO connected');
        });

        this.socket.on('disconnect', (reason) => {
            console.log('🔴 Socket.IO disconnected:', reason);
        });

        this.socket.on('connect_error', (error) => {
            console.error('❌ Socket.IO connection error:', error.message);
        });

        // Auto re-attach listeners on reconnect
        this.socket.on('reconnect', () => {
            console.log('🔄 Socket.IO reconnected');
            this.listeners.forEach((callback, event) => {
                this.socket.on(event, callback);
            });
        });
    }

    on(event, callback) {
        if (!this.socket) {
            console.warn('Socket not initialized');
            return;
        }
        this.listeners.set(event, callback);
        this.socket.on(event, callback);
    }

    off(event) {
        if (!this.socket) return;
        this.listeners.delete(event);
        this.socket.off(event);
    }

    emit(event, data) {
        if (!this.socket) {
            console.warn('Socket not initialized');
            return;
        }
        this.socket.emit(event, data);
    }

    disconnect() {
        if (this.socket) {
            this.socket.disconnect();
            this.socket = null;
            this.listeners.clear();
            console.log('🔌 Socket disconnected manually');
        }
    }
}

export default new SocketService();
