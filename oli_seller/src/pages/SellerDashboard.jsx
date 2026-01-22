export default function SellerDashboard() {
    return (
        <div className="p-8">
            <h1 className="text-2xl font-bold mb-6">Tableau de bord</h1>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h3 className="text-gray-500 text-sm">Chiffre d'Affaires (Mois)</h3>
                    <p className="text-3xl font-bold text-gray-900">$12,450</p>
                    <span className="text-green-500 text-sm">▲ +12%</span>
                </div>
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h3 className="text-gray-500 text-sm">Commandes en cours</h3>
                    <p className="text-3xl font-bold text-gray-900">42</p>
                    <span className="text-orange-500 text-sm">8 à expédier</span>
                </div>
                <div className="bg-white p-6 rounded shadow-sm border border-gray-200">
                    <h3 className="text-gray-500 text-sm">Santé du Compte</h3>
                    <p className="text-3xl font-bold text-green-600">98%</p>
                    <span className="text-gray-400 text-sm">Très bon</span>
                </div>
            </div>
        </div>
    );
}
