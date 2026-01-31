/**
 * API Service for Seller App
 * Centralized API calls with authentication
 */

import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'https://oli-api.onrender.com/api';

// Create axios instance with default config
const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json'
    }
});

// Add auth token to requests
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('seller_token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// Handle auth errors
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            // Token expired or invalid
            localStorage.removeItem('seller_token');
            localStorage.removeItem('seller_user');
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

// Auth APIs
export const authAPI = {
    login: async (phone, password) => {
        const response = await axios.post(`${API_URL}/auth/login`, { phone, password });
        return response.data;
    },

    uploadAvatar: async (file) => {
        const formData = new FormData();
        formData.append('avatar', file);

        const response = await api.post('/auth/avatar-upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    }
};

// Seller APIs
export const sellerAPI = {
    // Dashboard
    getDashboard: async () => {
        const response = await api.get('/seller/dashboard');
        return response.data;
    },

    // Products
    getProducts: async (filters = {}) => {
        const params = new URLSearchParams(filters).toString();
        const response = await api.get(`/seller/products?${params}`);
        return response.data;
    },

    toggleProduct: async (productId) => {
        const response = await api.patch(`/seller/products/${productId}/toggle`);
        return response.data;
    },

    // Orders
    getOrders: async (status = null) => {
        const params = status ? `?status=${status}` : '';
        const response = await api.get(`/seller/orders${params}`);
        return response.data;
    },

    getOrderDetails: async (orderId) => {
        const response = await api.get(`/seller/orders/${orderId}`);
        return response.data;
    },

    // Sales Stats
    getSalesChart: async (period = '7d') => {
        const response = await api.get(`/seller/stats/sales?period=${period}`);
        return response.data;
    },

    // Certification & Subscription
    getCertification: async () => {
        const response = await api.get('/seller/certification');
        return response.data;
    },

    upgradeSubscription: async (plan, paymentMethod) => {
        // Uses the centralized subscription API
        const response = await api.post('/subscription/upgrade', { plan, paymentMethod });
        return response.data;
    },

    checkSubscriptionStatus: async () => {
        const response = await api.get('/subscription/status');
        return response.data;
    }
};

// Product APIs
export const productAPI = {
    create: async (formData) => {
        const response = await api.post('/products', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    },

    update: async (productId, formData) => {
        const response = await api.patch(`/products/${productId}`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    },

    delete: async (productId) => {
        const response = await api.delete(`/products/${productId}`);
        return response.data;
    },

    uploadImages: async (files) => {
        const formData = new FormData();
        files.forEach((file, index) => {
            formData.append('images', file);
        });
        const response = await api.post('/products/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    }
};

// Shop APIs
export const shopAPI = {
    getMyShops: async () => {
        const response = await api.get('/shops/my-shops');
        return response.data;
    },

    update: async (shopId, formData) => {
        const response = await api.patch(`/shops/${shopId}`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    }
};

export default api;
