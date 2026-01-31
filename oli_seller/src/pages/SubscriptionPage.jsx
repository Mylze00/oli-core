import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { sellerAPI } from '../services/api';
import { CheckBadgeIcon } from '@heroicons/react/24/solid';

const PlanCard = ({ title, price, features, badgeColor, onSelect, isPremium }) => (
    <div className={`border rounded-xl p-6 flex flex-col items-center ${isPremium ? 'border-amber-400 bg-amber-50' : 'border-gray-200'}`}>
        <CheckBadgeIcon className={`h-16 w-16 mb-4 ${badgeColor}`} />
        <h3 className="text-xl font-bold text-gray-900">{title}</h3>
        <p className="text-2xl font-bold text-gray-900 mt-2">{price}</p>
        <div className="mt-6 w-full space-y-3">
            {features.map((feature, idx) => (
                <div key={idx} className="flex items-center text-sm text-gray-600">
                    <span className="mr-2 text-green-500">✓</span> {feature}
                </div>
            ))}
        </div>
        <button
            onClick={onSelect}
            className={`mt-8 w-full py-2 px-4 rounded-lg font-semibold transition-colors ${isPremium
                    ? 'bg-amber-400 text-black hover:bg-amber-500'
                    : 'bg-blue-500 text-white hover:bg-blue-600'
                }`}
        >
            Choisir ce plan
        </button>
    </div>
);

export default function SubscriptionPage() {
    const navigate = useNavigate();
    const [loading, setLoading] = useState(false);

    const handleUpgrade = async (plan) => {
        if (!window.confirm(`Confirmer l'abonnement au plan ${plan} ? (Mock Paiement)`)) return;

        setLoading(true);
        try {
            await sellerAPI.upgradeSubscription(plan, 'card');
            alert("Félicitations ! Vous êtes maintenant certifié.");
            navigate('/dashboard');
        } catch (error) {
            console.error(error);
            alert("Erreur lors de l'abonnement : " + (error.response?.data?.message || 'Inconnue'));
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="flex justify-center items-center h-screen">Traitement en cours...</div>;

    return (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
            <div className="text-center mb-12">
                <h1 className="text-3xl font-extrabold text-gray-900">Certifiez votre entreprise</h1>
                <p className="mt-4 text-xl text-gray-500 max-w-2xl mx-auto">
                    Obtenez un badge de vérification et débloquez des fonctionnalités exclusives pour propulser vos ventes.
                </p>
            </div>

            <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
                <PlanCard
                    title="Vendeur Certifié"
                    price="$4.99 / mois"
                    features={[
                        "Badge bleu sur votre profil",
                        "Priorité dans les recherches",
                        "Support prioritaire 24/7",
                        "Analytics de base"
                    ]}
                    badgeColor="text-blue-500"
                    onSelect={() => handleUpgrade('certified')}
                />

                <PlanCard
                    title="Entreprise Vérifiée"
                    price="$39 / mois"
                    features={[
                        "Badge doré exclusif",
                        "Certification légale (RCCM)",
                        "Outils d'analyses avancés",
                        "Gestion multi-utilisateurs",
                        "Campagnes publicitaires incluses"
                    ]}
                    badgeColor="text-amber-500"
                    isPremium={true}
                    onSelect={() => handleUpgrade('enterprise')}
                />
            </div>
        </div>
    );
}
