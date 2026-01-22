import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import SellerDashboard from './pages/SellerDashboard';
import ProductEditor from './pages/ProductEditor';
import ProductList from './pages/ProductList';
import Login from './pages/Login';

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
    const handleLogout = () => {
        localStorage.removeItem('seller_token');
        localStorage.removeItem('seller_user');
        window.location.href = '/login';
    };

    return (
        <div className="flex h-screen bg-gray-50">
            {/* Sidebar */}
            <aside className="w-64 bg-slate-900 text-white flex flex-col">
                <div className="p-4">
                    <h1 className="text-xl font-bold mb-8">Oli Seller Center</h1>
                    <nav className="space-y-2">
                        <a href="/dashboard" className="block p-3 rounded hover:bg-slate-800">Tableau de bord</a>
                        <a href="/products" className="block p-3 rounded hover:bg-slate-800">Produits</a>
                        <a href="/orders" className="block p-3 rounded hover:bg-slate-800">Commandes</a>
                        <a href="/messages" className="block p-3 rounded hover:bg-slate-800">Messages B2B</a>
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

                {/* Redirection par défaut */}
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
            </Routes>
        </BrowserRouter>
    )
}

export default App
