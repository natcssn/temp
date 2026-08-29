import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import TopBar from '../components/TopBar';
import { menuApi, ordersApi } from '../api';
import { useAuth } from '../context/AuthContext';
import { Package, ClipboardList, TrendingUp, Star } from 'lucide-react';

export default function DashboardPage() {
    const { restaurant, imageUrl } = useAuth();
    const [stats, setStats] = useState({ total: 0, available: 0, activeOrders: 0 });
    const [recentOrders, setRecentOrders] = useState([]);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        if (!restaurant?.id) return;
        try {
            const [menuRes, ordersRes] = await Promise.all([
                menuApi.getAll(restaurant.id),
                ordersApi.getCurrent(restaurant.id),
            ]);
            const items = menuRes.data.items;
            setStats({
                total: items.length,
                available: items.filter(i => i.is_available).length,
                activeOrders: ordersRes.data.orders.length,
            });
            setRecentOrders(ordersRes.data.orders.slice(0, 3));
        } catch { /* silent */ }
        finally { setLoading(false); }
    }, [restaurant?.id]);

    useEffect(() => { load(); }, [load]);

    const isOpen = restaurant?.is_open === 1 || restaurant?.is_open === true;

    return (
        <>
            <TopBar title="Dashboard" />
            <div className="page-content">
                {/* Welcome Banner */}
                <div className="card" style={{
                    background: 'linear-gradient(135deg, #FF6B35, #FF8C42)',
                    border: 'none',
                    color: 'white',
                    marginBottom: 28,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '28px 32px',
                }}>
                    <div>
                        <h2 style={{ fontSize: 24, fontWeight: 800, color: 'white' }}>
                            Welcome back! 🍽️
                        </h2>
                        <p style={{ opacity: 0.9, marginTop: 6, fontSize: 15 }}>
                            {restaurant?.name} — {isOpen ? '✅ Currently Open' : '🔴 Currently Closed'}
                        </p>
                    </div>
                    {restaurant?.image_path && (
                        <img
                            src={imageUrl(restaurant.image_path)}
                            alt={restaurant.name}
                            style={{ width: 72, height: 72, borderRadius: 14, objectFit: 'cover', border: '3px solid rgba(255,255,255,0.3)' }}
                        />
                    )}
                </div>

                {/* Stats */}
                <div className="stats-bar">
                    <div className="stat-card">
                        <div className="stat-label">Total Items</div>
                        <div className="stat-value orange">{loading ? '—' : stats.total}</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-label">Available Now</div>
                        <div className="stat-value green">{loading ? '—' : stats.available}</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-label">Active Orders</div>
                        <div className="stat-value yellow">{loading ? '—' : stats.activeOrders}</div>
                    </div>
                </div>

                {/* Quick Actions */}
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 14, color: 'var(--text-secondary)' }}>QUICK ACTIONS</h3>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14, marginBottom: 32 }}>
                    {[
                        { to: '/items', icon: Package, label: 'Manage Items', color: '#FF6B35', bg: 'rgba(255,107,53,0.08)' },
                        { to: '/add-item', icon: TrendingUp, label: 'Add New Item', color: '#27AE60', bg: 'rgba(39,174,96,0.08)' },
                        { to: '/orders', icon: ClipboardList, label: 'View Orders', color: '#F39C12', bg: 'rgba(243,156,18,0.08)' },
                        { to: '/details', icon: Star, label: 'Edit Details', color: '#2980B9', bg: 'rgba(41,128,185,0.08)' },
                    ].map(({ to, icon: Icon, label, color, bg }) => (
                        <Link key={to} to={to} style={{ textDecoration: 'none' }}>
                            <div className="card" style={{
                                textAlign: 'center',
                                padding: '22px 16px',
                                cursor: 'pointer',
                                background: bg,
                                border: `1.5px solid ${color}30`,
                                transition: 'all 0.2s',
                            }}
                                onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-3px)'}
                                onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
                            >
                                <Icon size={28} color={color} style={{ marginBottom: 10 }} />
                                <div style={{ fontSize: 13, fontWeight: 600, color }}>{label}</div>
                            </div>
                        </Link>
                    ))}
                </div>

                {/* Recent Orders */}
                {recentOrders.length > 0 && (
                    <>
                        <div className="page-header" style={{ marginBottom: 16 }}>
                            <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-secondary)' }}>RECENT ACTIVE ORDERS</h3>
                            <Link to="/orders" style={{ textDecoration: 'none' }}>
                                <button className="btn btn-outline btn-sm">View All →</button>
                            </Link>
                        </div>
                        {recentOrders.map(order => (
                            <div key={order.id} className="order-card">
                                <div className="order-header">
                                    <span className="order-code">{order.secret_code}</span>
                                    <span className={`order-status-badge status-${order.status}`}>{order.status.toUpperCase()}</span>
                                </div>
                                <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>
                                    {order.items.map(i => `${i.item_name} ×${i.quantity}`).join(' · ')}
                                </div>
                                <div style={{ marginTop: 8, fontSize: 14, fontWeight: 700, color: 'var(--primary)' }}>₹{order.total.toFixed(0)}</div>
                            </div>
                        ))}
                    </>
                )}
            </div>
        </>
    );
}
