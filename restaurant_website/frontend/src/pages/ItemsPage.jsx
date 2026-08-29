import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import TopBar from '../components/TopBar';
import { menuApi } from '../api';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';
import { Edit2, Trash2 } from 'lucide-react';

function EditModal({ item, onClose, onSaved }) {
    const [form, setForm] = useState({
        name: item.name, category: item.category, cuisine: item.cuisine || '', price: item.price
    });
    const [saving, setSaving] = useState(false);

    const save = async () => {
        if (!form.name || !form.price) { toast.error('Name and price required'); return; }
        setSaving(true);
        try {
            await menuApi.edit(item.id, form);
            toast.success('Item updated!');
            onSaved();
            onClose();
        } catch { toast.error('Update failed'); }
        finally { setSaving(false); }
    };

    return (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
            <div className="modal">
                <div className="modal-header">
                    <h2>Edit Item</h2>
                    <button className="modal-close" onClick={onClose}>✕</button>
                </div>
                <div className="form-group">
                    <label>Item Name</label>
                    <input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
                </div>
                <div className="form-group">
                    <label>Category</label>
                    <select value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))}>
                        <option value="veg">🟢 Veg</option>
                        <option value="non-veg">🔴 Non-Veg</option>
                        <option value="stationary">🔵 Stationary</option>
                    </select>
                </div>
                <div className="form-row">
                    <div className="form-group">
                        <label>Cuisine</label>
                        <input value={form.cuisine} onChange={e => setForm(f => ({ ...f, cuisine: e.target.value }))} placeholder="e.g. South Indian" />
                    </div>
                    <div className="form-group">
                        <label>Price (₹)</label>
                        <input type="number" value={form.price} onChange={e => setForm(f => ({ ...f, price: e.target.value }))} min="1" />
                    </div>
                </div>
                <button className="btn btn-primary btn-lg" onClick={save} disabled={saving} style={{ marginTop: 8 }}>
                    {saving ? 'Saving...' : 'Update Item'}
                </button>
            </div>
        </div>
    );
}

export default function ItemsPage() {
    const { restaurant } = useAuth();
    const [items, setItems] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editItem, setEditItem] = useState(null);

    const loadItems = useCallback(async () => {
        if (!restaurant?.id) return;
        try {
            const res = await menuApi.getAll(restaurant.id);
            setItems(res.data.items);
        } catch { toast.error('Failed to load items'); }
        finally { setLoading(false); }
    }, [restaurant?.id]);

    useEffect(() => { loadItems(); }, [loadItems]);

    const handleToggle = async (item) => {
        await menuApi.toggle(item.id);
        toast.success(`${item.name} ${item.is_available ? 'marked unavailable' : 'marked available'}!`);
        loadItems();
    };

    const handleDelete = async (item) => {
        if (!confirm(`Delete "${item.name}"?`)) return;
        await menuApi.delete(item.id);
        toast.success('Item deleted');
        loadItems();
    };

    const catClass = (cat) => cat === 'non-veg' ? 'nonveg' : cat;

    return (
        <>
            <TopBar title="Items in Stock" />
            <div className="page-content">
                <div className="page-header">
                    <h2>Menu Items ({items.length})</h2>
                    <Link to="/add-item" style={{ textDecoration: 'none' }}>
                        <button className="btn btn-primary">+ Add New Item</button>
                    </Link>
                </div>

                {loading ? <div className="loading-center"><div className="spinner" /></div> :
                    items.length === 0 ? (
                        <div className="empty-state">
                            <h3>No items yet</h3>
                            <p>Add your first menu item to get started</p>
                        </div>
                    ) : items.map(item => (
                        <div key={item.id} className="item-row" style={{ opacity: item.is_available ? 1 : 0.55 }}>
                            <div className={`item-indicator ind-${catClass(item.category)}`} />
                            <div style={{ flex: 1 }}>
                                <div className="item-name">{item.name}</div>
                                <div className="item-meta">
                                    <span className={`badge badge-${catClass(item.category)}`}>{item.category}</span>
                                    {item.cuisine && <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>{item.cuisine}</span>}
                                    {!item.is_available && (
                                        <span style={{ fontSize: 11, color: 'var(--accent-red)', fontWeight: 600 }}>OUT OF STOCK</span>
                                    )}
                                </div>
                            </div>
                            <span className="item-price">₹{item.price}</span>
                            <div className="item-actions">
                                <label className="switch" title={item.is_available ? 'Mark Out of Stock' : 'Mark Available'}>
                                    <input
                                        type="checkbox"
                                        checked={!!item.is_available}
                                        onChange={() => handleToggle(item)}
                                    />
                                    <span className="slider" />
                                </label>
                                <button className="btn btn-yellow btn-sm" onClick={() => setEditItem(item)}>
                                    <Edit2 size={13} /> Edit
                                </button>
                                <button className="btn btn-red btn-sm" onClick={() => handleDelete(item)}>
                                    <Trash2 size={13} /> Delete
                                </button>
                            </div>
                        </div>
                    ))}

                {editItem && (
                    <EditModal item={editItem} onClose={() => setEditItem(null)} onSaved={loadItems} />
                )}
            </div>
        </>
    );
}
