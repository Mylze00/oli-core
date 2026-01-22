import { useState } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import SellerDashboard from './pages/SellerDashboard';
import ProductEditor from './pages/ProductEditor';
import ProductList from './pages/ProductList';
import Login from './pages/Login';

// Placeholder for auth context/layout
const SellerLayout = ({ children }) => {
    return (
        <div className="flex h-screen bg-gray-50">
            {/* Sidebar Mockup */}
            <aside className="w-64 bg-slate-900 text-white p-4">
                <h1 className="text-xl font-bold mb-8">Oli Seller Center</h1>
                <nav className="space-y-2">
                    <a href="/dashboard" className="block p-3 rounded hover:bg-slate-800">Tableau de bord</a>
                    <a href="/products" className="block p-3 rounded bg-blue-600">Produits</a>
                    <a href="/orders" className="block p-3 rounded hover:bg-slate-800">Commandes</a>
                    <a href="/messages" className="block p-3 rounded hover:bg-slate-800">Messages B2B</a>
                </nav>
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

                <Route path="/dashboard" element={
                    <SellerLayout><SellerDashboard /></SellerLayout>
                } />

                <Route path="/products" element={
                    <SellerLayout><ProductList /></SellerLayout>
                } />

                <Route path="/products/new" element={
                    <SellerLayout><ProductEditor /></SellerLayout>
                } />

                <Route path="/" element={<Navigate to="/dashboard" replace />} />
            </Routes>
        </BrowserRouter>
    )
}

export default App
