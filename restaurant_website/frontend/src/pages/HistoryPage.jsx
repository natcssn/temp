import { useState, useEffect, useCallback } from 'react';
import TopBar from '../components/TopBar';
import { ordersApi } from '../api';
import { useAuth } from '../context/AuthContext';

function formatTime(ts) {
    if (!ts) return '';
    const d = new Date(ts + 'Z');
    return d.toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function HistoryPage() {
    const { restaurant } = useAuth();
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        if (!restaurant?.id) return;
        try {
            const res = await ordersApi.getHistory(restaurant.id);
            setOrders(res.data.orders);
        } catch { /* silent */ }
        finally { setLoading(false); }
    }, [restaurant?.id]);

    useEffect(() => { load(); }, [load]);

    const total = orders.reduce((s, o) => s + o.total, 0);

    return (
        <>
            <TopBar title="Order History" />
            <div className="page-content">
                <div className="page-header">
                    <div>
                        <h2>Completed Orders ({orders.length})</h2>
                        {orders.length > 0 && (
                            <p style={{ fontSize: 14, color: 'var(--text-secondary)', marginTop: 4 }}>
                                Total Revenue: <strong style={{ color: 'var(--accent-green)' }}>₹{total.toFixed(0)}</strong>
                            </p>
                        )}
                    </div>
                </div>

                {loading ? <div className="loading-center"><div className="spinner" /></div> :
                    orders.length === 0 ? (
                        <div className="empty-state">
                            <div style={{ fontSize: 48 }}>📋</div>
                            <h3>No order history yet</h3>
                            <p>Completed orders will appear here</p>
                        </div>
                    ) : orders.map(order => (
                        <div key={order.id} className="order-card" style={{ opacity: 0.85 }}>
                            <div className="order-header">
                                <span className="order-code" style={{ fontSize: 18 }}>{order.secret_code}</span>
                                <span className="order-status-badge status-given">✓ COMPLETED</span>
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
                                    <div style={{ color: 'var(--text-secondary)', textAlign: 'left' }}>
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
                                    <div style={{ color: 'var(--text-secondary)', textAlign: 'left' }}>
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
                                <span className="order-total">₹{order.total.toFixed(0)}</span>
                                <span className="order-time">🕐 {formatTime(order.created_at)}</span>
                            </div>
                        </div>
                    ))}
            </div>
        </>
    );
}
