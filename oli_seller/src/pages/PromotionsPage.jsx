import { useState, useEffect } from 'react';
import {
    Tag, Gift, Star, Plus, Trash2, Edit, Copy,
    Calendar, Users, TrendingUp, RefreshCw, Check,
    Percent, DollarSign, Truck, Award, Settings
} from 'lucide-react';
import { sellerAPI } from '../services/api';

const COUPON_TYPES = [
    { value: 'percentage', label: 'Pourcentage', icon: Percent },
    { value: 'fixed_amount', label: 'Montant fixe', icon: DollarSign },
    { value: 'free_shipping', label: 'Livraison gratuite', icon: Truck }
];

const TIERS = [
    { value: 'bronze', label: 'Bronze', color: 'text-amber-700 bg-amber-100' },
    { value: 'silver', label: 'Argent', color: 'text-gray-600 bg-gray-100' },
    { value: 'gold', label: 'Or', color: 'text-yellow-600 bg-yellow-100' },
    { value: 'platinum', label: 'Platine', color: 'text-purple-600 bg-purple-100' }
];

export default function PromotionsPage() {
    const [activeTab, setActiveTab] = useState('coupons');
    const [coupons, setCoupons] = useState([]);
    const [loyaltyStats, setLoyaltyStats] = useState(null);
    const [loyaltySettings, setLoyaltySettings] = useState(null);
    const [loyaltyCustomers, setLoyaltyCustomers] = useState([]);
    const [couponStats, setCouponStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editingCoupon, setEditingCoupon] = useState(null);
    const [formData, setFormData] = useState({
        code: '',
        type: 'percentage',
        value: '',
        min_order_amount: 0,
        max_discount_amount: '',
        max_uses: '',
        max_uses_per_user: 1,
        valid_from: new Date().toISOString().slice(0, 16),
        valid_until: ''
    });

    useEffect(() => {
        if (activeTab === 'coupons') {
            loadCoupons();
        } else {
            loadLoyalty();
        }
    }, [activeTab]);

    const loadCoupons = async () => {
        try {
            setLoading(true);
            const [couponsData, statsData] = await Promise.all([
                sellerAPI.getCoupons(),
                sellerAPI.getCouponStats()
            ]);
            setCoupons(couponsData || []);
            setCouponStats(statsData);
        } catch (err) {
            console.error('Erreur chargement coupons:', err);
        } finally {
            setLoading(false);
        }
    };

    const loadLoyalty = async () => {
        try {
            setLoading(true);
            const [settings, stats, customers] = await Promise.all([
                sellerAPI.getLoyaltySettings(),
                sellerAPI.getLoyaltyStats(),
                sellerAPI.getLoyaltyCustomers()
            ]);
            setLoyaltySettings(settings);
            setLoyaltyStats(stats);
            setLoyaltyCustomers(customers || []);
        } catch (err) {
            console.error('Erreur chargement fidélité:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleCreateCoupon = async () => {
        try {
            if (!formData.code || !formData.value) {
                alert('Code et valeur requis');
                return;
            }
            if (editingCoupon) {
                await sellerAPI.updateCoupon(editingCoupon.id, formData);
            } else {
                await sellerAPI.createCoupon(formData);
            }
            setShowModal(false);
            setEditingCoupon(null);
            resetForm();
            loadCoupons();
        } catch (err) {
            alert(err.response?.data?.error || 'Erreur');
        }
    };

    const handleDeleteCoupon = async (id) => {
        if (!confirm('Supprimer ce coupon ?')) return;
        try {
            await sellerAPI.deleteCoupon(id);
            loadCoupons();
        } catch (err) {
            alert('Erreur suppression');
        }
    };

    const handleEditCoupon = (coupon) => {
        setEditingCoupon(coupon);
        setFormData({
            code: coupon.code,
            type: coupon.type,
            value: coupon.value,
            min_order_amount: coupon.min_order_amount || 0,
            max_discount_amount: coupon.max_discount_amount || '',
            max_uses: coupon.max_uses || '',
            max_uses_per_user: coupon.max_uses_per_user || 1,
            valid_from: coupon.valid_from?.slice(0, 16) || '',
            valid_until: coupon.valid_until?.slice(0, 16) || ''
        });
        setShowModal(true);
    };

    const handleToggleCoupon = async (coupon) => {
        try {
            await sellerAPI.updateCoupon(coupon.id, { is_active: !coupon.is_active });
            loadCoupons();
        } catch (err) {
            alert('Erreur');
        }
    };

    const handleSaveLoyaltySettings = async () => {
        try {
            await sellerAPI.updateLoyaltySettings(loyaltySettings);
            alert('Paramètres sauvegardés');
        } catch (err) {
            alert('Erreur sauvegarde');
        }
    };

    const resetForm = () => {
        setFormData({
            code: '',
            type: 'percentage',
            value: '',
            min_order_amount: 0,
            max_discount_amount: '',
            max_uses: '',
            max_uses_per_user: 1,
            valid_from: new Date().toISOString().slice(0, 16),
            valid_until: ''
        });
    };

    const copyCode = (code) => {
        navigator.clipboard.writeText(code);
        alert(`Code "${code}" copié !`);
    };

    const generateCode = () => {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = '';
        for (let i = 0; i < 8; i++) code += chars[Math.floor(Math.random() * chars.length)];
        setFormData({ ...formData, code });
    };

    const formatCurrency = (val) => parseFloat(val || 0).toLocaleString('fr-FR', { style: 'currency', currency: 'USD' });

    const MetricCard = ({ icon: Icon, label, value, color = 'blue' }) => (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <div className={`p-2 bg-${color}-50 rounded-lg w-fit mb-3`}>
                <Icon className={`text-${color}-600`} size={20} />
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            <p className="text-sm text-gray-500">{label}</p>
        </div>
    );

    return (
        <div className="p-8">
            {/* Header */}
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Promotions & Fidélité</h1>
                    <p className="text-gray-500">Gérez vos codes promo et programme de fidélité</p>
                </div>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 mb-6 border-b border-gray-200 pb-2">
                {[
                    { key: 'coupons', label: 'Codes Promo', icon: Tag },
                    { key: 'loyalty', label: 'Fidélité', icon: Star }
                ].map(tab => (
                    <button
                        key={tab.key}
                        onClick={() => setActiveTab(tab.key)}
                        className={`flex items-center gap-2 px-4 py-2 rounded-t-lg font-medium transition-colors ${activeTab === tab.key
                                ? 'bg-blue-600 text-white'
                                : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                            }`}
                    >
                        <tab.icon size={18} />
                        {tab.label}
                    </button>
                ))}
            </div>

            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <RefreshCw className="animate-spin text-blue-600" size={32} />
                </div>
            ) : activeTab === 'coupons' ? (
                /* ONGLET COUPONS */
                <div className="space-y-6">
                    {/* Stats */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <MetricCard icon={Tag} label="Total coupons" value={couponStats?.total_coupons || 0} />
                        <MetricCard icon={Check} label="Actifs" value={couponStats?.active_coupons || 0} color="green" />
                        <MetricCard icon={Users} label="Utilisations" value={couponStats?.total_uses || 0} color="purple" />
                        <MetricCard icon={DollarSign} label="Remises données" value={formatCurrency(couponStats?.total_discount_given)} color="orange" />
                    </div>

                    {/* Actions */}
                    <div className="flex justify-end">
                        <button
                            onClick={() => { resetForm(); setEditingCoupon(null); setShowModal(true); }}
                            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                        >
                            <Plus size={18} /> Créer un coupon
                        </button>
                    </div>

                    {/* Liste des coupons */}
                    <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                        <table className="w-full">
                            <thead className="bg-gray-50 text-xs uppercase text-gray-500">
                                <tr>
                                    <th className="text-left p-4">Code</th>
                                    <th className="text-left p-4">Type</th>
                                    <th className="text-center p-4">Valeur</th>
                                    <th className="text-center p-4">Utilisations</th>
                                    <th className="text-center p-4">Statut</th>
                                    <th className="text-right p-4">Actions</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {coupons.length === 0 ? (
                                    <tr>
                                        <td colSpan="6" className="p-8 text-center text-gray-400">
                                            Aucun coupon créé
                                        </td>
                                    </tr>
                                ) : coupons.map(coupon => (
                                    <tr key={coupon.id} className="hover:bg-gray-50">
                                        <td className="p-4">
                                            <div className="flex items-center gap-2">
                                                <code className="bg-gray-100 px-2 py-1 rounded font-mono font-bold">
                                                    {coupon.code}
                                                </code>
                                                <button onClick={() => copyCode(coupon.code)} className="text-gray-400 hover:text-gray-600">
                                                    <Copy size={14} />
                                                </button>
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            {coupon.type === 'percentage' && <span className="flex items-center gap-1"><Percent size={14} /> Pourcentage</span>}
                                            {coupon.type === 'fixed_amount' && <span className="flex items-center gap-1"><DollarSign size={14} /> Montant</span>}
                                            {coupon.type === 'free_shipping' && <span className="flex items-center gap-1"><Truck size={14} /> Livraison</span>}
                                        </td>
                                        <td className="p-4 text-center font-medium">
                                            {coupon.type === 'percentage' ? `${coupon.value}%` :
                                                coupon.type === 'free_shipping' ? 'Gratuite' :
                                                    formatCurrency(coupon.value)}
                                        </td>
                                        <td className="p-4 text-center">
                                            {coupon.current_uses || 0}{coupon.max_uses ? `/${coupon.max_uses}` : ''}
                                        </td>
                                        <td className="p-4 text-center">
                                            <button
                                                onClick={() => handleToggleCoupon(coupon)}
                                                className={`px-2 py-1 rounded text-xs font-medium ${coupon.is_active
                                                        ? 'bg-green-100 text-green-700'
                                                        : 'bg-gray-100 text-gray-500'
                                                    }`}
                                            >
                                                {coupon.is_active ? 'Actif' : 'Inactif'}
                                            </button>
                                        </td>
                                        <td className="p-4 text-right">
                                            <div className="flex justify-end gap-2">
                                                <button onClick={() => handleEditCoupon(coupon)} className="p-1 text-gray-400 hover:text-blue-600">
                                                    <Edit size={16} />
                                                </button>
                                                <button onClick={() => handleDeleteCoupon(coupon.id)} className="p-1 text-gray-400 hover:text-red-600">
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            ) : (
                /* ONGLET FIDÉLITÉ */
                <div className="space-y-6">
                    {/* Stats */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <MetricCard icon={Users} label="Membres" value={loyaltyStats?.total_members || 0} />
                        <MetricCard icon={Star} label="Points en circulation" value={loyaltyStats?.total_points_outstanding || 0} color="yellow" />
                        <MetricCard icon={TrendingUp} label="Points distribués" value={loyaltyStats?.total_points_earned || 0} color="green" />
                        <MetricCard icon={Gift} label="Points utilisés" value={loyaltyStats?.total_points_redeemed || 0} color="purple" />
                    </div>

                    {/* Tiers */}
                    <div className="grid grid-cols-4 gap-4">
                        {TIERS.map(tier => (
                            <div key={tier.value} className={`p-4 rounded-lg ${tier.color} text-center`}>
                                <Award size={24} className="mx-auto mb-2" />
                                <p className="font-bold">{tier.label}</p>
                                <p className="text-2xl font-bold">{loyaltyStats?.[`${tier.value}_members`] || 0}</p>
                            </div>
                        ))}
                    </div>

                    {/* Paramètres Fidélité */}
                    {loyaltySettings && (
                        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                                <Settings size={20} /> Configuration
                            </h3>
                            <div className="grid md:grid-cols-3 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Programme actif</label>
                                    <button
                                        onClick={() => setLoyaltySettings({ ...loyaltySettings, is_enabled: !loyaltySettings.is_enabled })}
                                        className={`w-full px-4 py-2 rounded-lg font-medium ${loyaltySettings.is_enabled ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                                            }`}
                                    >
                                        {loyaltySettings.is_enabled ? '✓ Activé' : 'Désactivé'}
                                    </button>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Points par $</label>
                                    <input
                                        type="number"
                                        step="0.1"
                                        value={loyaltySettings.points_per_dollar || 1}
                                        onChange={(e) => setLoyaltySettings({ ...loyaltySettings, points_per_dollar: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Valeur d'un point ($)</label>
                                    <input
                                        type="number"
                                        step="0.001"
                                        value={loyaltySettings.points_value || 0.01}
                                        onChange={(e) => setLoyaltySettings({ ...loyaltySettings, points_value: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Min. points à utiliser</label>
                                    <input
                                        type="number"
                                        value={loyaltySettings.min_points_redeem || 100}
                                        onChange={(e) => setLoyaltySettings({ ...loyaltySettings, min_points_redeem: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Bonus bienvenue</label>
                                    <input
                                        type="number"
                                        value={loyaltySettings.welcome_bonus || 0}
                                        onChange={(e) => setLoyaltySettings({ ...loyaltySettings, welcome_bonus: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div className="flex items-end">
                                    <button
                                        onClick={handleSaveLoyaltySettings}
                                        className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                                    >
                                        Sauvegarder
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Top Clients */}
                    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                        <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Clients Fidèles</h3>
                        <div className="space-y-3">
                            {loyaltyCustomers.slice(0, 10).map((customer, idx) => (
                                <div key={customer.id} className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                                    <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-bold">
                                        {idx + 1}
                                    </span>
                                    <div className="flex-1">
                                        <p className="font-medium text-gray-900">{customer.user_name}</p>
                                        <p className="text-sm text-gray-500">{customer.user_phone}</p>
                                    </div>
                                    <span className={`px-2 py-1 rounded text-xs font-medium ${TIERS.find(t => t.value === customer.tier)?.color || 'bg-gray-100'
                                        }`}>
                                        {customer.tier}
                                    </span>
                                    <span className="font-bold text-blue-600">{customer.points_balance} pts</span>
                                </div>
                            ))}
                            {loyaltyCustomers.length === 0 && (
                                <p className="text-center text-gray-400 py-8">Aucun client fidélité</p>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* Modal Coupon */}
            {showModal && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
                    <div className="bg-white rounded-xl shadow-xl max-w-md w-full max-h-[90vh] overflow-y-auto p-6">
                        <h3 className="text-xl font-bold text-gray-900 mb-4">
                            {editingCoupon ? 'Modifier le coupon' : 'Créer un coupon'}
                        </h3>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Code</label>
                                <div className="flex gap-2">
                                    <input
                                        type="text"
                                        value={formData.code}
                                        onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                                        className="flex-1 px-4 py-2 border border-gray-300 rounded-lg uppercase"
                                        placeholder="SUMMER20"
                                    />
                                    <button onClick={generateCode} className="px-3 py-2 bg-gray-100 rounded-lg hover:bg-gray-200">
                                        Générer
                                    </button>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
                                <div className="grid grid-cols-3 gap-2">
                                    {COUPON_TYPES.map(type => (
                                        <button
                                            key={type.value}
                                            onClick={() => setFormData({ ...formData, type: type.value })}
                                            className={`p-3 rounded-lg border text-center ${formData.type === type.value
                                                    ? 'border-blue-500 bg-blue-50 text-blue-700'
                                                    : 'border-gray-200 hover:border-gray-300'
                                                }`}
                                        >
                                            <type.icon size={20} className="mx-auto mb-1" />
                                            <span className="text-xs">{type.label}</span>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    {formData.type === 'percentage' ? 'Pourcentage (%)' : 'Montant ($)'}
                                </label>
                                <input
                                    type="number"
                                    value={formData.value}
                                    onChange={(e) => setFormData({ ...formData, value: e.target.value })}
                                    className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    placeholder={formData.type === 'percentage' ? '20' : '10'}
                                    disabled={formData.type === 'free_shipping'}
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Min. commande ($)</label>
                                    <input
                                        type="number"
                                        value={formData.min_order_amount}
                                        onChange={(e) => setFormData({ ...formData, min_order_amount: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Max utilisations</label>
                                    <input
                                        type="number"
                                        value={formData.max_uses}
                                        onChange={(e) => setFormData({ ...formData, max_uses: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                        placeholder="Illimité"
                                    />
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Début</label>
                                    <input
                                        type="datetime-local"
                                        value={formData.valid_from}
                                        onChange={(e) => setFormData({ ...formData, valid_from: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">Fin (optionnel)</label>
                                    <input
                                        type="datetime-local"
                                        value={formData.valid_until}
                                        onChange={(e) => setFormData({ ...formData, valid_until: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="flex gap-3 mt-6">
                            <button
                                onClick={() => { setShowModal(false); setEditingCoupon(null); }}
                                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={handleCreateCoupon}
                                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                            >
                                {editingCoupon ? 'Modifier' : 'Créer'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
