import { useState, useEffect, useCallback, useRef } from 'react';
import TopBar from '../components/TopBar';
import { ordersApi } from '../api';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';
import { RefreshCw } from 'lucide-react';

function formatTime(ts) {
    if (!ts) return '';
    const d = new Date(ts + 'Z');
    return d.toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

export default function OrdersPage() {
    const { restaurant } = useAuth();
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const intervalRef = useRef(null);

    const loadOrders = useCallback(async () => {
        if (!restaurant?.id) return;
        try {
            const res = await ordersApi.getCurrent(restaurant.id);
            setOrders(res.data.orders);
        } catch { /* silent */ }
        finally { setLoading(false); }
    }, [restaurant?.id]);

    useEffect(() => {
        loadOrders();
        intervalRef.current = setInterval(loadOrders, 5000);
        return () => clearInterval(intervalRef.current);
    }, [loadOrders]);

    const handleUpdateStatus = async (orderId, newStatus) => {
        try {
            await ordersApi.updateStatus(orderId, newStatus);
            toast.success(`Order marked as ${newStatus.toUpperCase()} ✅`);
            loadOrders();
        } catch (ex) {
            toast.error(ex?.response?.data?.detail || 'Failed to update order');
        }
    };

    const getActionBtn = (order) => {
        const isDelivery = String(order.fulfillment_mode || '').toLowerCase() === 'delivery';
        if (order.status === 'preparing') return (
            <button className="btn btn-green btn-sm" onClick={() => handleUpdateStatus(order.id, 'ready')}>
                🍳 Mark Ready
            </button>
        );
        if (order.status === 'ready' && isDelivery) return (
            <span
                style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--text-muted)',
                    border: '1px solid #d9dee8',
                    padding: '6px 10px',
                    borderRadius: 999,
                    background: '#f8fafc',
                }}
            >
                Delivery Partner Will Complete
            </span>
        );
        if (order.status === 'ready') return (
            <button className="btn btn-blue btn-sm" onClick={() => handleUpdateStatus(order.id, 'given')}>
                ✓ Mark Given
            </button>
        );
        return null;
    };

    return (
        <>
            <TopBar title="Current Orders" />
            <div className="page-content">
                <div className="page-header">
                    <div>
                        <h2>Active Orders ({orders.length})</h2>
                        <p style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>Auto-refreshes every 5 seconds</p>
                    </div>
                    <button className="btn btn-outline" onClick={loadOrders}>
                        <RefreshCw size={14} /> Refresh
                    </button>
                </div>

                {loading ? <div className="loading-center"><div className="spinner" /></div> :
                    orders.length === 0 ? (
                        <div className="empty-state">
                            <div style={{ fontSize: 48 }}>🎉</div>
                            <h3>No active orders</h3>
                            <p>New orders will appear here automatically</p>
                        </div>
                    ) : orders.map(order => (
                        <div key={order.id} className="order-card">
                            <div className="order-header">
                                <span className="order-code">{order.secret_code}</span>
                                <span className={`order-status-badge status-${order.status}`}>{order.status.toUpperCase()}</span>
                            </div>

                            {/* Customer Delivery Details */}
                            {String(order.fulfillment_mode || '').toLowerCase() === 'delivery' ? (
                                <div style={{
                                    background: 'rgba(255, 107, 53, 0.05)',
                                    border: '1px solid rgba(255, 107, 53, 0.15)',
                                    borderRadius: '8px',
                                    padding: '12px',
                                    marginBottom: '14px',
                                    fontSize: '13px'
                                }}>
                                    <div style={{ fontWeight: 700, color: 'var(--primary)', marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                                        <span>🚚 Delivery Order</span>
                                        {order.customer_hostel && (
                                            <span style={{ background: 'var(--primary)', color: 'white', fontSize: '11px', padding: '2px 6px', borderRadius: '4px', marginLeft: 'auto' }}>
                                                {String(order.customer_hostel).toUpperCase()}
                                            </span>
                                        )}
                                    </div>
                                    <div style={{ color: 'var(--text-secondary)' }}>
                                        <div><strong>Customer Name:</strong> {order.customer_name || 'N/A'}</div>
                                        {order.customer_phone && <div><strong>Phone Number:</strong> {order.customer_phone}</div>}
                                        {order.customer_college && <div><strong>College:</strong> {order.customer_college}</div>}
                                        {order.customer_identification && (
                                            <div style={{ marginTop: '6px', padding: '6px', background: 'rgba(255,255,255,0.7)', borderRadius: '4px', fontStyle: 'italic', color: 'var(--text-muted)' }}>
                                                ✍️ "{order.customer_identification}"
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div style={{
                                    background: 'rgba(41, 128, 185, 0.05)',
                                    border: '1px solid rgba(41, 128, 185, 0.15)',
                                    borderRadius: '8px',
                                    padding: '12px',
                                    marginBottom: '14px',
                                    fontSize: '13px'
                                }}>
                                    <div style={{ fontWeight: 700, color: 'var(--accent-blue)', marginBottom: '6px' }}>
                                        🛍️ Takeaway / Pickup Order
                                    </div>
                                    <div style={{ color: 'var(--text-secondary)' }}>
                                        <div><strong>Customer Name:</strong> {order.customer_name || 'N/A'}</div>
                                        {order.customer_phone && <div><strong>Phone:</strong> {order.customer_phone}</div>}
                                    </div>
                                </div>
                            )}

                            <ul className="order-items-list">
                                {order.items.map((item, i) => (
                                    <li key={i}>
                                        <span>{item.item_name} × {item.quantity}</span>
                                        <span>₹{(item.price * item.quantity).toFixed(0)}</span>
                                    </li>
                                ))}
                            </ul>

                            <div className="order-footer">
                                <span className="order-total">Total: ₹{order.total.toFixed(0)}</span>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                                    <span className="order-time">🕐 {formatTime(order.created_at)}</span>
                                    {getActionBtn(order)}
                                </div>
                            </div>
                        </div>
                    ))}
            </div>
        </>
    );
}
