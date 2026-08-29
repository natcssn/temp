import { useAuth } from '../context/AuthContext';
import { restaurantApi } from '../api';
import toast from 'react-hot-toast';
import { useState } from 'react';

export default function TopBar({ title }) {
    const { restaurant, refreshRestaurant } = useAuth();
    const [toggling, setToggling] = useState(false);
    const isOpen = restaurant?.is_open === 1 || restaurant?.is_open === true;
    const restId = restaurant?.id;

    const handleToggle = async () => {
        if (!restId || toggling) return;
        setToggling(true);
        try {
            await restaurantApi.toggle(restId);
            const updated = await refreshRestaurant();
            const nowOpen = updated?.is_open === 1 || updated?.is_open === true;
            toast.success(nowOpen ? '✅ Restaurant is now OPEN' : '🔴 Restaurant is now CLOSED');
        } catch {
            toast.error('Failed to toggle status');
        } finally {
            setToggling(false);
        }
    };

    return (
        <div className="topbar">
            <span className="topbar-title">{title}</span>
            <div className="topbar-right">
                <button
                    className={`status-pill ${isOpen ? 'status-open' : 'status-closed'}`}
                    onClick={handleToggle}
                    disabled={toggling}
                    title="Click to toggle open/close"
                >
                    <span className={`status-dot ${isOpen ? 'dot-open' : 'dot-closed'}`} />
                    {toggling ? 'Updating...' : isOpen ? 'OPEN — Click to Close' : 'CLOSED — Click to Open'}
                </button>
            </div>
        </div>
    );
}
