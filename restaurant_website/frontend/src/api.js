import axios from 'axios';

const RAW_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';
const BASE_URL = RAW_BASE_URL.replace(/\/+$/, '');

const api = axios.create({ baseURL: BASE_URL });

// Attach auth token automatically
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('rtoken');
    if (token) config.headers['Authorization'] = `Bearer ${token}`;
    return config;
});

api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error?.response?.status === 401) {
            localStorage.removeItem('rtoken');
            localStorage.removeItem('rrestId');
            if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
                window.location.replace('/login');
            }
        }
        return Promise.reject(error);
    }
);

export const restaurantApi = {
    login: (email, password) => {
        const fd = new FormData();
        fd.append('email', email);
        fd.append('password', password);
        return api.post('/restaurant/login', fd);
    },
    me: () => api.get('/restaurant/me'),
    update: (id, data) => {
        const fd = new FormData();
        Object.entries(data).forEach(([k, v]) => fd.append(k, v));
        return api.put(`/restaurants/${id}`, fd);
    },
    toggle: (id) => api.put(`/restaurants/${id}/toggle`),
    uploadImage: (id, file) => {
        const fd = new FormData();
        fd.append('file', file);
        return api.post(`/restaurants/${id}/image`, fd);
    },
};

export const menuApi = {
    getAll: (restaurant_id) => api.get(`/menu/${restaurant_id}?all=true`),
    add: (restaurant_id, data) => {
        const fd = new FormData();
        Object.entries(data).forEach(([k, v]) => fd.append(k, v));
        return api.post(`/menu/${restaurant_id}`, fd);
    },
    edit: (item_id, data) => {
        const fd = new FormData();
        Object.entries(data).forEach(([k, v]) => fd.append(k, v));
        return api.put(`/menu/item/${item_id}`, fd);
    },
    toggle: (item_id) => api.put(`/menu/item/${item_id}/toggle`),
    delete: (item_id) => api.delete(`/menu/item/${item_id}`),
};

export const ordersApi = {
    getCurrent: (restaurant_id) => api.get(`/orders/restaurant/${restaurant_id}`),
    getHistory: (restaurant_id) => api.get(`/orders/restaurant/${restaurant_id}/history`),
    updateStatus: (order_id, status) =>
        api.put(`/orders/${order_id}/status`, { status }, { headers: { 'Content-Type': 'application/json' } }),
};

export const BASE = BASE_URL;
export default api;
