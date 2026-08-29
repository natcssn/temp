import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import Sidebar from './components/Sidebar';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import ItemsPage from './pages/ItemsPage';
import AddItemPage from './pages/AddItemPage';
import DetailsPage from './pages/DetailsPage';
import OrdersPage from './pages/OrdersPage';
import HistoryPage from './pages/HistoryPage';

function ProtectedRoute({ children }) {
  const { restaurant, loading } = useAuth();
  if (loading) return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
      <div className="spinner" />
    </div>
  );
  if (!restaurant) return <Navigate to="/login" replace />;
  return children;
}

function DashboardLayout({ children }) {
  return (
    <div className="app-layout">
      <Sidebar />
      <div className="main-area">{children}</div>
    </div>
  );
}

function AppRoutes() {
  const { restaurant, loading } = useAuth();
  if (loading) return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
      <div className="spinner" />
    </div>
  );

  return (
    <Routes>
      <Route path="/login" element={restaurant ? <Navigate to="/" replace /> : <LoginPage />} />
      <Route path="/" element={
        <ProtectedRoute>
          <DashboardLayout><DashboardPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="/items" element={
        <ProtectedRoute>
          <DashboardLayout><ItemsPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="/add-item" element={
        <ProtectedRoute>
          <DashboardLayout><AddItemPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="/details" element={
        <ProtectedRoute>
          <DashboardLayout><DetailsPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="/orders" element={
        <ProtectedRoute>
          <DashboardLayout><OrdersPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="/history" element={
        <ProtectedRoute>
          <DashboardLayout><HistoryPage /></DashboardLayout>
        </ProtectedRoute>
      } />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
        <Toaster
          position="bottom-right"
          toastOptions={{
            duration: 3000,
            style: {
              fontFamily: 'Inter, sans-serif',
              fontSize: '14px',
              fontWeight: 500,
              borderRadius: '12px',
              padding: '14px 20px',
            },
            success: { iconTheme: { primary: '#27AE60', secondary: '#fff' } },
            error: { iconTheme: { primary: '#E74C3C', secondary: '#fff' } },
          }}
        />
      </AuthProvider>
    </BrowserRouter>
  );
}
