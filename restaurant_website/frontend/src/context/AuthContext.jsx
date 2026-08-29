import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { restaurantApi, BASE } from '../api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
    const [restaurant, setRestaurant] = useState(null);
    const [loading, setLoading] = useState(true);

    const fetchMe = useCallback(async () => {
        const token = localStorage.getItem('rtoken');
        if (!token) { setLoading(false); return; }
        try {
            const res = await restaurantApi.me();
            setRestaurant(res.data);
        } catch {
            localStorage.removeItem('rtoken');
            localStorage.removeItem('rrestId');
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { fetchMe(); }, [fetchMe]);

    const login = async (email, password) => {
        const res = await restaurantApi.login(email, password);
        localStorage.setItem('rtoken', res.data.token);
        localStorage.setItem('rrestId', res.data.restaurant_id);
        const meRes = await restaurantApi.me();
        setRestaurant(meRes.data);
        return res.data;
    };

    const logout = () => {
        localStorage.removeItem('rtoken');
        localStorage.removeItem('rrestId');
        setRestaurant(null);
    };

    const refreshRestaurant = async () => {
        const res = await restaurantApi.me();
        setRestaurant(res.data);
        return res.data;
    };

    const imageUrl = (path) => path ? `${BASE}/uploads/${path}` : null;

    return (
        <AuthContext.Provider value={{ restaurant, loading, login, logout, refreshRestaurant, imageUrl }}>
            {children}
        </AuthContext.Provider>
    );
}

export const useAuth = () => useContext(AuthContext);
