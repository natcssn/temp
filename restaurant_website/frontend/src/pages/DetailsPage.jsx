import { useState, useEffect } from 'react';
import TopBar from '../components/TopBar';
import { BASE, restaurantApi } from '../api';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

export default function DetailsPage() {
    const { restaurant, refreshRestaurant, imageUrl } = useAuth();
    const [form, setForm] = useState({ name: '', description: '', cuisine_type: '', address: '', phone: '' });
    const [saving, setSaving] = useState(false);
    const [imgSrc, setImgSrc] = useState('');

    useEffect(() => {
        if (restaurant) {
            setForm({
                name: restaurant.name || '',
                description: restaurant.description || '',
                cuisine_type: restaurant.cuisine_type || '',
                address: restaurant.address || '',
                phone: restaurant.phone || '',
            });
            if (restaurant.image_path) setImgSrc(imageUrl(restaurant.image_path));
        }
    }, [restaurant, imageUrl]);

    const handleSave = async (e) => {
        e.preventDefault();
        setSaving(true);
        try {
            await restaurantApi.update(restaurant.id, form);
            await refreshRestaurant();
            toast.success('✅ Restaurant details saved!');
        } catch {
            toast.error('Failed to save details');
        } finally {
            setSaving(false);
        }
    };

    const handleImage = async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        try {
            const res = await restaurantApi.uploadImage(restaurant.id, file);
            const url = `${BASE}${res.data.image_url}`;
            setImgSrc(url);
            toast.success('📷 Image uploaded!');
            await refreshRestaurant();
        } catch {
            toast.error('Image upload failed');
        }
    };

    if (!restaurant) return <div className="loading-center"><div className="spinner" /></div>;

    return (
        <>
            <TopBar title="Restaurant Details" />
            <div className="page-content">
                <div className="page-header">
                    <h2>Edit Restaurant Info</h2>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 24, alignItems: 'start' }}>
                    <div className="form-card" style={{ maxWidth: '100%' }}>
                        <form onSubmit={handleSave}>
                            <div className="form-row">
                                <div className="form-group">
                                    <label>Restaurant Name</label>
                                    <input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
                                </div>
                                <div className="form-group">
                                    <label>Cuisine Type</label>
                                    <input value={form.cuisine_type} onChange={e => setForm(f => ({ ...f, cuisine_type: e.target.value }))} placeholder="e.g. Indian, South Indian" />
                                </div>
                            </div>
                            <div className="form-row">
                                <div className="form-group">
                                    <label>Phone Number</label>
                                    <input value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="e.g. 9876543210" />
                                </div>
                                <div className="form-group">
                                    <label>Address</label>
                                    <input value={form.address} onChange={e => setForm(f => ({ ...f, address: e.target.value }))} placeholder="Location on campus" />
                                </div>
                            </div>
                            <div className="form-group">
                                <label>Description</label>
                                <textarea
                                    value={form.description}
                                    onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                                    rows={3}
                                    placeholder="Describe your restaurant..."
                                />
                            </div>
                            <button type="submit" className="btn btn-primary btn-lg" disabled={saving}>
                                {saving ? 'Saving...' : '💾 Save Details'}
                            </button>
                        </form>
                    </div>

                    <div>
                        <div className="form-card" style={{ maxWidth: '100%' }}>
                            <div className="form-group" style={{ marginBottom: 0 }}>
                                <label>Restaurant Image</label>
                                <div className="image-upload" style={{ marginTop: 8 }}>
                                    {imgSrc ? (
                                        <img src={imgSrc} alt="Restaurant" style={{ width: '100%', maxHeight: 160, objectFit: 'cover' }} />
                                    ) : (
                                        <div style={{ padding: '30px 0' }}>
                                            <div style={{ fontSize: 36 }}>🏪</div>
                                            <p>Click to upload image</p>
                                        </div>
                                    )}
                                    <input type="file" accept="image/*" onChange={handleImage} />
                                </div>
                            </div>
                        </div>

                        <div className="card" style={{ marginTop: 0 }}>
                            <h3 style={{ fontSize: 14, color: 'var(--text-secondary)', marginBottom: 12, fontWeight: 600 }}>RESTAURANT INFO</h3>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                                <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>ID: <strong style={{ color: 'var(--text-primary)' }}>#{restaurant.id}</strong></div>
                                <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Rating: <strong style={{ color: 'var(--accent-yellow)' }}>⭐ {restaurant.rating}</strong></div>
                                <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Status: <strong style={{ color: (restaurant.is_open ? 'var(--accent-green)' : 'var(--accent-red)') }}>{restaurant.is_open ? 'OPEN' : 'CLOSED'}</strong></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}
