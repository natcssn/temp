import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
    LayoutDashboard, Package, PlusCircle, Store, ClipboardList, History, LogOut
} from 'lucide-react';

const navItems = [
    { to: '/', icon: LayoutDashboard, label: 'Dashboard', exact: true },
    { to: '/items', icon: Package, label: 'Items in Stock' },
    { to: '/add-item', icon: PlusCircle, label: 'Add Item' },
    { to: '/details', icon: Store, label: 'Restaurant Details' },
    { to: '/orders', icon: ClipboardList, label: 'Current Orders' },
    { to: '/history', icon: History, label: 'Order History' },
];

export default function Sidebar() {
    const { restaurant, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <div className="sidebar">
            <div className="sidebar-logo">
                <h1>🍽️ EZFOODZ</h1>
                <p>Manager Portal</p>
            </div>

            {restaurant && (
                <div className="sidebar-rest-name">
                    <div className="label">Restaurant</div>
                    <div className="name">{restaurant.name}</div>
                </div>
            )}

            <nav className="sidebar-nav">
                {navItems.map(({ to, icon: Icon, label, exact }) => (
                    <NavLink
                        key={to}
                        to={to}
                        end={exact}
                        className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
                    >
                        <Icon size={18} />
                        {label}
                    </NavLink>
                ))}
            </nav>

            <div className="sidebar-bottom">
                <button className="nav-item" onClick={handleLogout} style={{ color: 'rgba(231,76,60,0.7)' }}>
                    <LogOut size={18} />
                    Logout
                </button>
            </div>
        </div>
    );
}
