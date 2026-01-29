import { Shield, Award, TrendingUp, CheckCircle } from 'lucide-react';

export default function CertificationStatus({ certification }) {
    if (!certification) return null;

    const { account_type, level_label, benefits, total_sales, active_days } = certification;

    const getBadgeConfig = (type) => {
        const configs = {
            ordinaire: {
                color: 'gray',
                icon: Shield,
                gradient: 'from-gray-500 to-gray-600'
            },
            certifie: {
                color: 'blue',
                icon: Shield,
                gradient: 'from-blue-500 to-blue-600'
            },
            premium: {
                color: 'green',
                icon: TrendingUp,
                gradient: 'from-green-500 to-green-600'
            },
            entreprise: {
                color: 'yellow',
                icon: Award,
                gradient: 'from-yellow-500 to-yellow-600'
            }
        };
        return configs[type] || configs.ordinaire;
    };

    const config = getBadgeConfig(account_type);
    const Icon = config.icon;

    return (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">
                Ma Certification
            </h2>

            {/* Badge et niveau */}
            <div className={`bg-gradient-to-r ${config.gradient} rounded-lg p-6 mb-4`}>
                <div className="flex items-center gap-4">
                    <div className="bg-white/20 p-3 rounded-full">
                        <Icon className="text-white" size={32} />
                    </div>
                    <div className="flex-1">
                        <h3 className="text-white text-xl font-bold">
                            {level_label || 'Vendeur Standard'}
                        </h3>
                        <p className="text-white/80 text-sm mt-1">
                            {total_sales || 0} ventes • {active_days || 0} jours actif
                        </p>
                    </div>
                </div>
            </div>

            {/* Avantages */}
            {benefits && benefits.length > 0 && (
                <div>
                    <h4 className="text-sm font-semibold text-gray-700 mb-3">
                        Vos avantages
                    </h4>
                    <div className="space-y-2">
                        {benefits.slice(0, 4).map((benefit, index) => (
                            <div key={index} className="flex items-start gap-2">
                                <CheckCircle className="text-green-500 flex-shrink-0 mt-0.5" size={16} />
                                <span className="text-sm text-gray-600">{benefit}</span>
                            </div>
                        ))}
                        {benefits.length > 4 && (
                            <p className="text-sm text-gray-500 italic mt-2">
                                +{benefits.length - 4} autres avantages
                            </p>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
