import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Smartphone, Package, ChevronRight } from 'lucide-react';

export default function ProductModeSelector() {
    const navigate = useNavigate();

    const modes = [
        {
            id: 'detail',
            icon: <Smartphone size={36} className="text-blue-400" />,
            title: 'Mode Détail',
            subtitle: 'Comme sur l\'app mobile',
            description: 'Publie ton article avec tous les détails : photos guidées, état du produit, conditions de vente, badge Oli Trust.',
            tags: ['Photos guidées', 'État produit', 'Trust Shield', 'Catégories'],
            color: 'blue',
            route: '/products/new/detail'
        },
        {
            id: 'batch',
            icon: <Package size={36} className="text-amber-500" />,
            title: 'Mode Lot',
            subtitle: 'Jusqu\'à 20 produits d\'un coup',
            description: 'Ajoutez plusieurs produits en une seule session. Idéal pour publier rapidement un stock de produits avec photos, prix et catégorie.',
            tags: ['1-20 produits', 'Publication groupée', 'Gain de temps'],
            color: 'amber',
            route: '/products/new/batch'
        },
        {
            id: 'wholesale',
            icon: <Package size={36} className="text-emerald-400" />,
            title: 'Mode Grossiste',
            subtitle: 'Pour les professionnels B2B',
            description: 'Formulaire optimisé pour la vente en gros : prix dégressifs, unités de vente, MOQ, promotions avec dates.',
            tags: ['Prix dégressifs', 'B2B', 'Promotions', 'Unités'],
            color: 'emerald',
            route: '/products/new/wholesale'
        }
    ];

    return (
        <div className="p-8 max-w-4xl mx-auto">
            <button
                onClick={() => navigate('/products')}
                className="text-gray-500 flex items-center gap-2 mb-6 hover:text-gray-900 transition-colors"
            >
                <ArrowLeft size={16} /> Retour aux produits
            </button>

            <div className="text-center mb-10">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">
                    Ajouter un produit
                </h1>
                <p className="text-gray-500 text-lg">
                    Choisissez le mode de publication adapté à votre besoin
                </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {modes.map((mode) => (
                    <button
                        key={mode.id}
                        onClick={() => navigate(mode.route)}
                        className={`group relative bg-white rounded-2xl border-2 border-gray-200 hover:border-${mode.color}-400 p-8 text-left transition-all duration-300 hover:shadow-xl hover:-translate-y-1`}
                    >
                        {/* Icon */}
                        <div className={`w-16 h-16 rounded-xl bg-${mode.color}-50 flex items-center justify-center mb-5`}>
                            {mode.icon}
                        </div>

                        {/* Title */}
                        <h2 className="text-xl font-bold text-gray-900 mb-1 flex items-center gap-2">
                            {mode.title}
                            <ChevronRight size={18} className="text-gray-300 group-hover:text-gray-600 transition-colors" />
                        </h2>
                        <p className={`text-sm font-medium text-${mode.color}-600 mb-3`}>
                            {mode.subtitle}
                        </p>

                        {/* Description */}
                        <p className="text-gray-500 text-sm mb-5 leading-relaxed">
                            {mode.description}
                        </p>

                        {/* Tags */}
                        <div className="flex flex-wrap gap-2">
                            {mode.tags.map((tag) => (
                                <span
                                    key={tag}
                                    className={`text-xs px-3 py-1 rounded-full bg-${mode.color}-50 text-${mode.color}-700 font-medium`}
                                >
                                    {tag}
                                </span>
                            ))}
                        </div>

                        {/* Hover glow */}
                        <div className={`absolute inset-0 rounded-2xl bg-${mode.color}-500 opacity-0 group-hover:opacity-5 transition-opacity pointer-events-none`} />
                    </button>
                ))}
            </div>

            {/* Help text */}
            <p className="text-center text-gray-400 text-sm mt-8">
                💡 Le <strong>Mode Détail</strong> est recommandé pour les articles individuels.
                Le <strong>Mode Grossiste</strong> est idéal pour les vendeurs professionnels.
            </p>
        </div>
    );
}
