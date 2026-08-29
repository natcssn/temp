import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

export default function LoginPage() {
    const { login } = useAuth();
    const navigate = useNavigate();
    const [email, setEmail] = useState('');
    const [pass, setPass] = useState('');
    const [loading, setLoading] = useState(false);
    const [err, setErr] = useState('');

    const handleLogin = async (e) => {
        e.preventDefault();
        if (!email || !pass) { setErr('Please fill in all fields'); return; }
        setLoading(true);
        setErr('');
        try {
            await login(email, pass);
            toast.success('Welcome back! 🍽️');
            navigate('/');
        } catch (ex) {
            setErr(ex?.response?.data?.detail || 'Login failed. Check your credentials.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="login-page">
            <div className="login-card">
                <div className="login-logo">
                    <span className="emoji">🍽️</span>
                    <h1>EZFOODZ</h1>
                    <p>Restaurant Manager Portal</p>
                </div>

                <form onSubmit={handleLogin}>
                    <div className="form-group">
                        <label>Restaurant Email</label>
                        <input
                            type="email"
                            placeholder="Enter your restaurant email"
                            value={email}
                            onChange={e => setEmail(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && document.getElementById('passInput').focus()}
                            autoFocus
                        />
                    </div>

                    <div className="form-group">
                        <label>Password</label>
                        <input
                            id="passInput"
                            type="password"
                            placeholder="Enter your password"
                            value={pass}
                            onChange={e => setPass(e.target.value)}
                        />
                    </div>

                    {err && <div className="error-msg">{err}</div>}

                    <button
                        type="submit"
                        className="btn btn-primary btn-lg"
                        style={{ marginTop: 20 }}
                        disabled={loading}
                    >
                        {loading ? 'Signing in...' : '🔑 Sign In'}
                    </button>
                </form>

                <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--text-muted)', marginTop: 20 }}>
                    Login with your restaurant email and password
                </p>
            </div>
        </div>
    );
}
