import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { setToken, setUser } from '../utils/auth';

export default function Login() {
    const navigate = useNavigate();
    const [step, setStep] = useState(1); // 1: Phone, 2: OTP
    const [phone, setPhone] = useState('');
    const [otp, setOtp] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleSendOtp = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');

        try {
            await api.post('/auth/send-otp', { phone });
            setStep(2);
        } catch (err) {
            console.error(err);
            setError(err.response?.data?.error || "Erreur lors de l'envoi du code");
        } finally {
            setLoading(false);
        }
    };

    const handleVerifyOtp = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');

        try {
            const { data } = await api.post('/auth/verify-otp', { phone, otpCode: otp });

            // Vérifier si admin
            if (!data.user.is_admin) {
                setError("Accès refusé. Vous n'êtes pas administrateur.");
                return;
            }

            setToken(data.token);
            setUser(data.user);
            navigate('/');
        } catch (err) {
            console.error(err);
            setError(err.response?.data?.error || "Code invalide");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-100">
            <div className="bg-white p-8 rounded-lg shadow-md w-full max-w-md">
                <h1 className="text-2xl font-bold text-center mb-6 text-primary">
                    Oli Admin Login
                </h1>

                {error && (
                    <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4 text-sm">
                        {error}
                    </div>
                )}

                {step === 1 ? (
                    <form onSubmit={handleSendOtp} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Numéro de téléphone
                            </label>
                            <input
                                type="text"
                                placeholder="+243..."
                                value={phone}
                                onChange={(e) => setPhone(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded focus:ring-secondary focus:border-secondary"
                                required
                            />
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-primary text-white py-2 rounded hover:bg-slate-800 transition disabled:opacity-50"
                        >
                            {loading ? 'Envoi...' : 'Recevoir le code'}
                        </button>
                    </form>
                ) : (
                    <form onSubmit={handleVerifyOtp} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Code OTP
                            </label>
                            <input
                                type="text"
                                placeholder="123456"
                                value={otp}
                                onChange={(e) => setOtp(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded focus:ring-secondary focus:border-secondary"
                                required
                            />
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-secondary text-white py-2 rounded hover:bg-blue-600 transition disabled:opacity-50"
                        >
                            {loading ? 'Vérification...' : 'Se connecter'}
                        </button>
                        <button
                            type="button"
                            onClick={() => setStep(1)}
                            className="w-full text-sm text-gray-500 hover:text-gray-700"
                        >
                            Changer de numéro
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
}
