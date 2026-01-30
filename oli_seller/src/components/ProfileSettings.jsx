import { useState, useEffect } from 'react';
import { Camera, Image as ImageIcon, Save, Loader } from 'lucide-react';
import { authAPI, shopAPI } from '../services/api';

export default function ProfileSettings({ shopId, currentAvatar, currentBanner, onUpdate }) {
    const [avatar, setAvatar] = useState(null);
    const [banner, setBanner] = useState(null);
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState(null);

    const handleAvatarChange = async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        setLoading(true);
        try {
            const res = await authAPI.uploadAvatar(file);
            setAvatar(res.avatar_url);
            setMessage({ type: 'success', text: 'Avatar mis à jour !' });
            if (onUpdate) onUpdate();
        } catch (err) {
            const errorMsg = err.response?.data?.error || 'Erreur upload avatar';
            setMessage({ type: 'error', text: errorMsg });
            // Handle limit error specifically if needed, code LIMIT_REACHED sent by backend
            if (err.response?.data?.code === 'LIMIT_REACHED') {
                alert(err.response.data.error);
            }
        } finally {
            setLoading(false);
        }
    };

    const handleBannerChange = async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        if (!shopId) {
            setMessage({ type: 'error', text: 'Aucune boutique détectée' });
            return;
        }

        setLoading(true);
        try {
            const formData = new FormData();
            formData.append('banner', file);
            await shopAPI.update(shopId, formData);

            // Preview
            const reader = new FileReader();
            reader.onload = (e) => setBanner(e.target.result);
            reader.readAsDataURL(file);

            setMessage({ type: 'success', text: 'Bannière mise à jour !' });
            if (onUpdate) onUpdate();
        } catch (err) {
            setMessage({ type: 'error', text: 'Erreur upload bannière' });
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-8">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Apparence de la boutique</h2>

            {message && (
                <div className={`mb-4 p-3 rounded ${message.type === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                    {message.text}
                </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* Avatar Section */}
                <div className="flex flex-col items-center">
                    <span className="text-sm font-medium text-gray-700 mb-2">Avatar (Profil & Logo)</span>
                    <div className="relative group">
                        <div className="w-24 h-24 rounded-full overflow-hidden border-2 border-gray-200 bg-gray-50 flex items-center justify-center">
                            {avatar || currentAvatar ? (
                                <img src={avatar || currentAvatar} alt="Avatar" className="w-full h-full object-cover" />
                            ) : (
                                <Camera className="text-gray-400" size={32} />
                            )}
                        </div>
                        <label className="absolute bottom-0 right-0 bg-blue-600 text-white p-2 rounded-full cursor-pointer hover:bg-blue-700 shadow-md transition-colors">
                            <Camera size={16} />
                            <input
                                type="file"
                                className="hidden"
                                accept="image/*"
                                onChange={handleAvatarChange}
                                disabled={loading}
                            />
                        </label>
                    </div>
                    <p className="text-xs text-gray-500 mt-2 text-center">
                        Limite: 30 changements. <br />
                        Sera aussi utilisé comme logo de la boutique.
                    </p>
                </div>

                {/* Banner Section */}
                <div className="flex flex-col">
                    <span className="text-sm font-medium text-gray-700 mb-2">Bannière</span>
                    <div className="relative group w-full h-32 rounded-lg overflow-hidden border-2 border-gray-200 bg-gray-50 flex items-center justify-center">
                        {banner || currentBanner ? (
                            <img src={banner || currentBanner} alt="Bannière" className="w-full h-full object-cover" />
                        ) : (
                            <div className="text-gray-400 flex flex-col items-center">
                                <ImageIcon size={32} />
                                <span className="text-xs mt-1">1000x300 recommended</span>
                            </div>
                        )}
                        <label className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all flex items-center justify-center cursor-pointer">
                            <div className="opacity-0 group-hover:opacity-100 bg-white text-gray-800 px-4 py-2 rounded-lg font-medium shadow-sm transform scale-95 group-hover:scale-100 transition-all">
                                Changer
                            </div>
                            <input
                                type="file"
                                className="hidden"
                                accept="image/*"
                                onChange={handleBannerChange}
                                disabled={loading}
                            />
                        </label>
                    </div>
                </div>
            </div>

            {loading && (
                <div className="mt-4 flex items-center justify-center text-blue-600">
                    <Loader className="animate-spin mr-2" size={16} />
                    <span className="text-sm">Traitement en cours...</span>
                </div>
            )}
        </div>
    );
}
