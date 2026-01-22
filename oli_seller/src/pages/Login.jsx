import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

export default function Login() {
    const [phone, setPhone] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');

        try {
            // 1. Authentification standard
            const { data } = await api.post('/auth/login', { phone, password });

            // 2. Vérification des droits "Entreprise"
            // (On suppose que le backend renvoie l'user info, sinon faut faire un /me)
            const user = data.user;

            /* TODO: Décommenter quand le backend renverra bien ces infos au login
               Pour l'instant on laisse passer si le login réussit pour la démo */

            // if (user.account_type !== 'entreprise' && !user.is_admin) {
            //     setError("Accès refusé. Ce portail est réservé aux comptes Entreprise.");
            //     setLoading(false);
            //     return;
            // }

            localStorage.setItem('seller_token', data.token);
            localStorage.setItem('seller_user', JSON.stringify(user));

            navigate('/dashboard');
        } catch (err) {
            console.error(err);
            setError("Identifiants incorrects ou erreur serveur");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-slate-900">
            <div className="bg-white p-8 rounded-lg shadow-xl w-full max-w-md">
                <div className="text-center mb-8">
                    <h1 className="text-3xl font-bold text-slate-900">Oli Seller Center</h1>
                    <p className="text-gray-500 mt-2">Portail Entreprises & Grossistes</p>
                </div>

                {error && (
                    <div className="bg-red-50 text-red-600 p-3 rounded mb-4 text-sm text-center">
                        {error}
                    </div>
                )}

                <form onSubmit={handleLogin} className="space-y-6">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Téléphone</label>
                        <input
                            type="text"
                            required
                            className="w-full border p-3 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="+243..."
                            value={phone}
                            onChange={e => setPhone(e.target.value)}
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Mot de passe</label>
                        <input
                            type="password"
                            required
                            className="w-full border p-3 rounded focus:ring-2 focus:ring-blue-500 outline-none"
                            placeholder="••••••••"
                            value={password}
                            onChange={e => setPassword(e.target.value)}
                        />
                    </div>

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-blue-600 text-white py-3 rounded font-bold hover:bg-blue-700 transition-colors disabled:opacity-50"
                    >
                        {loading ? 'Connexion...' : 'Accéder au portail'}
                    </button>
                </form>

                <div className="mt-6 text-center text-sm text-gray-400">
                    Pas encore de compte entreprise ? <br />
                    Contactez le support Oli pour devenir partenaire.
                </div>
            </div>
        </div>
    );
}
