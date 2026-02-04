import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import SellerDashboard from './pages/SellerDashboard';
import ProductEditor from './pages/ProductEditor';
import ProductList from './pages/ProductList';
import Login from './pages/Login';
import SubscriptionPage from './pages/SubscriptionPage';
import ImportExportPage from './pages/ImportExportPage';
import VariantsEditor from './pages/VariantsEditor';
import OrderManagement from './pages/OrderManagement';
import ReportsPage from './pages/ReportsPage';
import MessagesPage from './pages/MessagesPage';
import PromotionsPage from './pages/PromotionsPage';

// Composant pour protéger les routes
const ProtectedRoute = ({ children }) => {
    const token = localStorage.getItem('seller_token');
    const location = useLocation();

    if (!token) {
        // Rediriger vers login si pas de token, tout en gardant l'URL d'origine
        return <Navigate to="/login" state={{ from: location }} replace />;
    }

    return children;
};

const SellerLayout = ({ children }) => {
    const user = JSON.parse(localStorage.getItem('seller_user') || '{}');
    const location = useLocation();

    const handleLogout = () => {
        localStorage.removeItem('seller_token');
        localStorage.removeItem('seller_user');
        window.location.href = '/login';
    };

    const getAvatarUrl = (avatarPath) => {
        if (!avatarPath) return null;
        if (avatarPath.startsWith('http')) return avatarPath;

        const CLOUD_NAME = 'dbfpnxjmm';
        const cleanPath = avatarPath.startsWith('/') ? avatarPath.slice(1) : avatarPath;

        if (cleanPath.startsWith('uploads/')) {
            const API_URL = import.meta.env.VITE_API_URL || 'https://oli-core.onrender.com';
            return `${API_URL}/${cleanPath}`;
        }

        return `https://res.cloudinary.com/${CLOUD_NAME}/image/upload/${cleanPath}`;
    };

    const isActive = (path) => location.pathname.startsWith(path);

    return (
        <div className="flex h-screen bg-gray-50">
            {/* Sidebar */}
            <aside className="w-64 bg-slate-900 text-white flex flex-col">
                <div className="p-4">
                    <h1 className="text-xl font-bold mb-4">Oli Seller Center</h1>

                    {/* User Profile Section */}
                    <div className="bg-slate-800 rounded-lg p-3 mb-6">
                        <div className="flex items-center gap-3">
                            <img
                                src={getAvatarUrl(user.avatar_url) || `https://ui-avatars.com/api/?name=${user.name || 'User'}&background=3b82f6&color=fff&size=128`}
                                alt="Avatar"
                                className="w-12 h-12 rounded-full object-cover border-2 border-blue-500"
                                onError={(e) => e.target.src = `https://ui-avatars.com/api/?name=${user.name || 'User'}&background=3b82f6&color=fff`}
                            />
                            <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold truncate">{user.name || 'Vendeur'}</p>
                                <p className="text-xs text-gray-400 truncate">{user.phone || ''}</p>
                            </div>
                        </div>
                    </div>

                    <nav className="space-y-1">
                        <a
                            href="/dashboard"
                            className={`block p-3 rounded transition-colors ${isActive('/dashboard') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            📊 Tableau de bord
                        </a>
                        <a
                            href="/products"
                            className={`block p-3 rounded transition-colors ${isActive('/products') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            📦 Produits
                        </a>
                        <a
                            href="/import-export"
                            className={`block p-3 rounded transition-colors ${isActive('/import-export') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            📥 Import / Export
                        </a>
                        <a
                            href="/orders"
                            className={`block p-3 rounded transition-colors ${isActive('/orders') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            🛒 Commandes
                        </a>
                        <a
                            href="/reports"
                            className={`block p-3 rounded transition-colors ${isActive('/reports') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            📈 Rapports
                        </a>
                        <a
                            href="/messages"
                            className={`block p-3 rounded transition-colors ${isActive('/messages') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            💬 Messages B2B
                        </a>
                        <a
                            href="/promotions"
                            className={`block p-3 rounded transition-colors ${isActive('/promotions') ? 'bg-blue-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            🎁 Promotions
                        </a>
                        <a
                            href="/subscription"
                            className={`block p-3 rounded transition-colors text-amber-400 ${isActive('/subscription') ? 'bg-amber-600 text-white' : 'hover:bg-slate-800'
                                }`}
                        >
                            ⭐ Certification
                        </a>
                    </nav>
                </div>
                <div className="mt-auto p-4 border-t border-slate-800">
                    <button
                        onClick={handleLogout}
                        className="w-full text-left p-2 text-red-400 hover:text-red-300 text-sm"
                    >
                        Se déconnecter
                    </button>
                </div>
            </aside>
            <main className="flex-1 overflow-auto">
                {children}
            </main>
        </div>
    )
};

function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="/login" element={<Login />} />

                {/* Routes Protégées */}
                <Route path="/dashboard" element={
                    <ProtectedRoute>
                        <SellerLayout><SellerDashboard /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/products" element={
                    <ProtectedRoute>
                        <SellerLayout><ProductList /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/products/new" element={
                    <ProtectedRoute>
                        <SellerLayout><ProductEditor /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/products/:productId/variants" element={
                    <ProtectedRoute>
                        <SellerLayout><VariantsEditor /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/import-export" element={
                    <ProtectedRoute>
                        <SellerLayout><ImportExportPage /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/orders" element={
                    <ProtectedRoute>
                        <SellerLayout><OrderManagement /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/reports" element={
                    <ProtectedRoute>
                        <SellerLayout><ReportsPage /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/messages" element={
                    <ProtectedRoute>
                        <MessagesPage />
                    </ProtectedRoute>
                } />

                <Route path="/promotions" element={
                    <ProtectedRoute>
                        <SellerLayout><PromotionsPage /></SellerLayout>
                    </ProtectedRoute>
                } />

                <Route path="/subscription" element={
                    <ProtectedRoute>
                        <SellerLayout><SubscriptionPage /></SellerLayout>
                    </ProtectedRoute>
                } />

                {/* Redirection par défaut */}
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
            </Routes>
        </BrowserRouter>
    )
}

export default App

