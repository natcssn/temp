import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import TopBar from '../components/TopBar';
import { menuApi } from '../api';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

const CATEGORIES = [
    { value: 'veg', label: '🟢 Veg', cls: 'ind-veg' },
    { value: 'non-veg', label: '🔴 Non-Veg', cls: 'ind-nonveg' },
    { value: 'stationary', label: '🔵 Stationary', cls: 'ind-stationary' },
];

export default function AddItemPage() {
    const { restaurant } = useAuth();
    const navigate = useNavigate();
    const [form, setForm] = useState({ name: '', category: 'veg', cuisine: '', price: '' });
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        if (!restaurant?.id) {
            navigate('/login', { replace: true });
        }
    }, [restaurant?.id, navigate]);

    const handleSave = async (e) => {
        e.preventDefault();
        if (!restaurant?.id) {
            toast.error('Session expired. Please login again.');
            navigate('/login', { replace: true });
            return;
        }
        if (!form.name || !form.price) { toast.error('Name and price are required'); return; }
        setSaving(true);
        try {
            await menuApi.add(restaurant.id, form);
            toast.success(`✅ "${form.name}" added to menu!`);
            navigate('/items', { replace: true });
        } catch (ex) {
            if (ex?.response?.status === 401) {
                toast.error('Session expired. Please login again.');
                navigate('/login', { replace: true });
                return;
            }
            toast.error(ex?.response?.data?.detail || 'Failed to add item');
        } finally {
            setSaving(false);
        }
    };

    return (
        <>
            <TopBar title="Add New Item" />
            <div className="page-content">
                <div className="page-header">
                    <h2>Add Menu Item</h2>
                    <button className="btn btn-outline" onClick={() => navigate('/items')}>← Back to Items</button>
                </div>

                <div className="form-card">
                    <form onSubmit={handleSave}>
                        <div className="form-group">
                            <label>Item Name *</label>
                            <input
                                type="text"
                                placeholder="e.g. Chicken Biryani"
                                value={form.name}
                                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                                autoFocus
                            />
                        </div>

                        <div className="form-group">
                            <label>Category *</label>
                            <div className="category-group">
                                {CATEGORIES.map(cat => (
                                    <div
                                        key={cat.value}
                                        className={`cat-option${form.category === cat.value ? ' selected' : ''}`}
                                        onClick={() => setForm(f => ({ ...f, category: cat.value }))}
                                    >
                                        {cat.label}
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="form-row">
                            <div className="form-group">
                                <label>Cuisine</label>
                                <input
                                    type="text"
                                    placeholder="e.g. South Indian"
                                    value={form.cuisine}
                                    onChange={e => setForm(f => ({ ...f, cuisine: e.target.value }))}
                                />
                            </div>
                            <div className="form-group">
                                <label>Price (₹) *</label>
                                <input
                                    type="number"
                                    placeholder="e.g. 120"
                                    min="1"
                                    value={form.price}
                                    onChange={e => setForm(f => ({ ...f, price: e.target.value }))}
                                />
                            </div>
                        </div>

                        <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                            <button type="submit" className="btn btn-primary" style={{ flex: 1, padding: '14px' }} disabled={saving}>
                                {saving ? 'Adding...' : '✅ Add Item'}
                            </button>
                            <button type="button" className="btn btn-outline" onClick={() => navigate('/items')}>Cancel</button>
                        </div>
                    </form>
                </div>
            </div>
        </>
    );
}
