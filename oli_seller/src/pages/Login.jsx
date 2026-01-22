import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

export default function Login() {
    const [step, setStep] = useState(1); // 1: Téléphone, 2: OTP
    const [phone, setPhone] = useState('');
    const [otpCode, setOtpCode] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const navigate = useNavigate();

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
            const { data } = await api.post('/auth/verify-otp', { phone, otpCode });

            // Stockage Auth
            localStorage.setItem('seller_token', data.token);
            localStorage.setItem('seller_user', JSON.stringify(data.user));

            navigate('/dashboard');
        } catch (err) {
            console.error(err);
            setError(err.response?.data?.error || "Code invalide");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-slate-900">
            <div className="bg-white p-8 rounded-lg shadow-xl w-full max-w-md">
                <div className="text-center mb-6">
                    <h1 className="text-3xl font-bold text-slate-900">Oli Seller Center</h1>
                    <p className="text-gray-500 mt-2">Accès Sécurisé par Mobile</p>
                </div>

                {error && (
                    <div className="bg-red-50 text-red-600 p-3 rounded mb-4 text-sm text-center">
                        {error}
                    </div>
                )}

                {step === 1 ? (
                    <form onSubmit={handleSendOtp} className="space-y-6">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Numéro de téléphone</label>
                            <input
                                type="tel"
                                required
                                className="w-full border p-3 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                                placeholder="+243 000 000 000"
                                value={phone}
                                onChange={e => setPhone(e.target.value)}
                            />
                            <p className="text-xs text-gray-400 mt-1">Format international recommandé (+243...)</p>
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-blue-600 text-white py-3 rounded font-bold hover:bg-blue-700 transition-colors disabled:opacity-50"
                        >
                            {loading ? 'Envoi en cours...' : 'Recevoir mon code'}
                        </button>
                    </form>
                ) : (
                    <form onSubmit={handleVerifyOtp} className="space-y-6">
                        <div>
                            <div className="flex justify-between items-center mb-1">
                                <label className="block text-sm font-medium text-gray-700">Code de vérification</label>
                                <button type="button" onClick={() => setStep(1)} className="text-xs text-blue-600 hover:underline">Modifier numéro</button>
                            </div>
                            <input
                                type="text"
                                required
                                maxLength={6}
                                className="w-full border p-3 rounded focus:ring-2 focus:ring-blue-500 outline-none text-center text-2xl tracking-widest"
                                placeholder="000000"
                                value={otpCode}
                                onChange={e => setOtpCode(e.target.value)}
                            />
                            <p className="text-xs text-gray-500 mt-2 text-center">
                                Code envoyé au {phone}
                            </p>
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-green-600 text-white py-3 rounded font-bold hover:bg-green-700 transition-colors disabled:opacity-50"
                        >
                            {loading ? 'Vérification...' : 'Se connecter'}
                        </button>
                    </form>
                )}

                <div className="mt-8 text-center text-xs text-gray-400 border-t pt-4">
                    Utilisez le numéro associé à votre compte Oli App.<br />
                    En cas de problème, contactez le support.
                </div>
            </div>
        </div>
    );
}
