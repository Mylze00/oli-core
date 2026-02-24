import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout/Layout';
import ProtectedRoute from './components/ProtectedRoute';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import UserDetail from './pages/UserDetail';
import Products from './pages/Products';
import Orders from './pages/Orders';
import Disputes from './pages/Disputes';
import Shops from './pages/Shops';
import Requests from './pages/Requests';
import AdsManager from './pages/AdsManager';
import ServicesManager from './pages/ServicesManager'; // ✨ Services
import Support from './pages/Support'; // 🆕 Support
import Verifications from './pages/Verifications'; // 🆕 Certifications
import ProductRequests from './pages/ProductRequests'; // 📦 Demandes produit
import DatabaseManager from './pages/DatabaseManager'; // 🗄️ Gestion DB
import Delivery from './pages/Delivery'; // 🚚 Livreurs
import Finances from './pages/Finances'; // 💰 Finances

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />

        <Route element={<ProtectedRoute />}>
          <Route element={<Layout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/users" element={<Users />} />
            <Route path="/users/:id" element={<UserDetail />} />
            <Route path="/products" element={<Products />} />
            <Route path="/shops" element={<Shops />} />
            <Route path="/requests" element={<Requests />} />
            <Route path="/product-requests" element={<ProductRequests />} /> {/* 📦 */}
            <Route path="/orders" element={<Orders />} />
            <Route path="/disputes" element={<Disputes />} />
            <Route path="/ads" element={<AdsManager />} />
            <Route path="/services" element={<ServicesManager />} />
            <Route path="/support" element={<Support />} /> {/* 🆕 */}
            <Route path="/verifications" element={<Verifications />} /> {/* 🆕 */}
            <Route path="/database" element={<DatabaseManager />} /> {/* 🗄️ */}
            <Route path="/delivery" element={<Delivery />} /> {/* 🚚 */}
            <Route path="/finances" element={<Finances />} /> {/* 💰 */}
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
