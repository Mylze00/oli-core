/**
 * API Service for Seller App
 * Centralized API calls with authentication
 */

import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';

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

        const response = await api.post('/auth/upload-avatar', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    }
};

// Seller APIs
export const sellerAPI = {
    // Dashboard
    getDashboard: async () => {
        const response = await api.get('/api/seller/dashboard');
        return response.data;
    },

    // Products
    getProducts: async (filters = {}) => {
        const params = new URLSearchParams(filters).toString();
        const response = await api.get(`/api/seller/products?${params}`);
        return response.data;
    },

    toggleProduct: async (productId) => {
        const response = await api.patch(`/api/seller/products/${productId}/toggle`);
        return response.data;
    },

    // Orders
    getOrders: async (status = null) => {
        const params = status ? `?status=${status}` : '';
        const response = await api.get(`/api/seller/orders${params}`);
        return response.data;
    },

    getOrderDetails: async (orderId) => {
        const response = await api.get(`/api/seller/orders/${orderId}`);
        return response.data;
    },

    // Sales Stats
    getSalesChart: async (period = '7d') => {
        const response = await api.get(`/api/seller/stats/sales?period=${period}`);
        return response.data;
    },

    // Certification & Subscription
    getCertification: async () => {
        const response = await api.get('/api/seller/certification');
        return response.data;
    },

    upgradeSubscription: async (plan, paymentMethod) => {
        // Uses the centralized subscription API
        const response = await api.post('/api/subscription/upgrade', { plan, paymentMethod });
        return response.data;
    },

    checkSubscriptionStatus: async () => {
        const response = await api.get('/api/subscription/status');
        return response.data;
    },

    // 📊 Analytics Avancés
    getAnalyticsOverview: async () => {
        const response = await api.get('/api/analytics/overview');
        return response.data;
    },

    getTopProducts: async (limit = 10) => {
        const response = await api.get(`/api/analytics/top-products?limit=${limit}`);
        return response.data;
    },

    getProductsWithoutSales: async (days = 30) => {
        const response = await api.get(`/api/analytics/products-without-sales?days=${days}`);
        return response.data;
    },

    getRecentOrders: async (limit = 5) => {
        const response = await api.get(`/api/analytics/recent-orders?limit=${limit}`);
        return response.data;
    },

    getAnalyticsSalesChart: async (period = '7d') => {
        const response = await api.get(`/api/analytics/sales-chart?period=${period}`);
        return response.data;
    },

    // 📥 Import/Export CSV
    getImportTemplate: () => {
        return `${api.defaults.baseURL}/api/import-export/template`;
    },

    importProducts: async (file) => {
        const formData = new FormData();
        formData.append('file', file);
        const response = await api.post('/api/import-export/import', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    },

    exportProducts: () => {
        return `${api.defaults.baseURL}/api/import-export/export`;
    },

    getImportHistory: async () => {
        const response = await api.get('/api/import-export/history');
        return response.data;
    },

    // 🎨 Variantes produits
    getVariants: async (productId) => {
        const response = await api.get(`/api/variants/${productId}`);
        return response.data;
    },

    addVariant: async (productId, variant) => {
        const response = await api.post(`/api/variants/${productId}`, variant);
        return response.data;
    },

    addVariantsBulk: async (productId, variants) => {
        const response = await api.post(`/api/variants/${productId}/bulk`, { variants });
        return response.data;
    },

    updateVariant: async (variantId, data) => {
        const response = await api.put(`/api/variants/${variantId}`, data);
        return response.data;
    },

    deleteVariant: async (variantId) => {
        const response = await api.delete(`/api/variants/${variantId}`);
        return response.data;
    },

    getVariantSuggestions: async () => {
        const response = await api.get('/api/variants/types/suggestions');
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
        const response = await api.get('/api/shops/my-shops');
        return response.data;
    },

    update: async (shopId, formData) => {
        const response = await api.patch(`/api/shops/${shopId}`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        return response.data;
    }
};

export default api;
