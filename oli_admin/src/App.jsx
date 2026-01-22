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
import AdsManager from './pages/AdsManager';

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
            <Route path="/orders" element={<Orders />} />
            <Route path="/orders" element={<Orders />} />
            <Route path="/orders" element={<Orders />} />
            <Route path="/disputes" element={<Disputes />} />
            <Route path="/ads" element={<AdsManager />} />
            <Route path="/ads" element={<AdsManager />} />
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
