import { useState, useEffect, useRef } from 'react';
import { ArrowLeft, Upload, Download, FileText, CheckCircle, XCircle, Clock, RefreshCw } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { sellerAPI } from '../services/api';

export default function ImportExportPage() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);

    const [importing, setImporting] = useState(false);
    const [importResult, setImportResult] = useState(null);
    const [history, setHistory] = useState([]);
    const [loadingHistory, setLoadingHistory] = useState(true);

    useEffect(() => {
        loadHistory();
    }, []);

    const loadHistory = async () => {
        try {
            setLoadingHistory(true);
            const data = await sellerAPI.getImportHistory();
            setHistory(data);
        } catch (err) {
            console.error('Erreur chargement historique:', err);
        } finally {
            setLoadingHistory(false);
        }
    };

    const handleFileSelect = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setImporting(true);
        setImportResult(null);

        try {
            const result = await sellerAPI.importProducts(file);
            setImportResult(result);
            loadHistory(); // Refresh history
        } catch (err) {
            console.error('Erreur import:', err);
            setImportResult({
                success: false,
                error: err.response?.data?.error || 'Erreur lors de l\'import'
            });
        } finally {
            setImporting(false);
            // Reset file input
            if (fileInputRef.current) {
                fileInputRef.current.value = '';
            }
        }
    };

    const handleDownloadTemplate = () => {
        const token = localStorage.getItem('token');
        const url = sellerAPI.getImportTemplate();

        // Create temporary link with auth
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'oli_products_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };

    const handleExport = () => {
        const token = localStorage.getItem('token');
        const baseUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';

        // Open export URL in new window (will download automatically)
        window.open(`${baseUrl}/api/import-export/export`, '_blank');
    };

    const getStatusIcon = (status) => {
        switch (status) {
            case 'completed':
                return <CheckCircle className="text-green-500" size={18} />;
            case 'failed':
                return <XCircle className="text-red-500" size={18} />;
            case 'processing':
                return <RefreshCw className="text-blue-500 animate-spin" size={18} />;
            default:
                return <Clock className="text-yellow-500" size={18} />;
        }
    };

    const getStatusLabel = (status) => {
        const labels = {
            pending: 'En attente',
            processing: 'En cours',
            completed: 'Terminé',
            failed: 'Échoué'
        };
        return labels[status] || status;
    };

    return (
        <div className="p-8 max-w-5xl mx-auto">
            <button
                onClick={() => navigate('/products')}
                className="text-gray-500 flex items-center gap-2 mb-4 hover:text-gray-900"
            >
                <ArrowLeft size={16} /> Retour aux produits
            </button>

            <h1 className="text-2xl font-bold text-gray-900 mb-2">Import / Export de Produits</h1>
            <p className="text-gray-500 mb-8">Gérez vos produits en masse avec des fichiers CSV</p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                {/* Import Section */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-3 bg-blue-100 rounded-lg">
                            <Upload className="text-blue-600" size={24} />
                        </div>
                        <div>
                            <h2 className="text-lg font-semibold text-gray-900">Importer des produits</h2>
                            <p className="text-sm text-gray-500">Fichier CSV jusqu'à 5MB</p>
                        </div>
                    </div>

                    <p className="text-sm text-gray-600 mb-4">
                        Téléchargez d'abord le template, remplissez-le avec vos produits, puis importez-le.
                    </p>

                    <div className="space-y-3">
                        <button
                            onClick={handleDownloadTemplate}
                            className="w-full flex items-center justify-center gap-2 px-4 py-2 border border-blue-300 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors"
                        >
                            <FileText size={18} />
                            Télécharger le template CSV
                        </button>

                        <div className="relative">
                            <input
                                ref={fileInputRef}
                                type="file"
                                accept=".csv"
                                onChange={handleFileSelect}
                                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                disabled={importing}
                            />
                            <button
                                className={`w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium transition-colors ${importing
                                        ? 'bg-gray-100 text-gray-400 cursor-wait'
                                        : 'bg-blue-600 text-white hover:bg-blue-700'
                                    }`}
                                disabled={importing}
                            >
                                {importing ? (
                                    <>
                                        <RefreshCw className="animate-spin" size={18} />
                                        Import en cours...
                                    </>
                                ) : (
                                    <>
                                        <Upload size={18} />
                                        Choisir un fichier à importer
                                    </>
                                )}
                            </button>
                        </div>
                    </div>

                    {/* Import Result */}
                    {importResult && (
                        <div className={`mt-4 p-4 rounded-lg ${importResult.success
                                ? 'bg-green-50 border border-green-200'
                                : 'bg-red-50 border border-red-200'
                            }`}>
                            {importResult.success ? (
                                <>
                                    <div className="flex items-center gap-2 text-green-700 font-medium mb-2">
                                        <CheckCircle size={18} />
                                        Import réussi
                                    </div>
                                    <div className="text-sm text-green-600 space-y-1">
                                        <p>✓ {importResult.imported} produits importés</p>
                                        {importResult.errors > 0 && (
                                            <p className="text-yellow-600">
                                                ⚠ {importResult.errors} erreurs
                                            </p>
                                        )}
                                    </div>
                                    {importResult.error_details?.length > 0 && (
                                        <div className="mt-3 pt-3 border-t border-green-200">
                                            <p className="text-xs font-medium text-gray-600 mb-1">Erreurs:</p>
                                            <ul className="text-xs text-red-600 space-y-1">
                                                {importResult.error_details.slice(0, 5).map((err, i) => (
                                                    <li key={i}>Ligne {err.row}: {err.error}</li>
                                                ))}
                                            </ul>
                                        </div>
                                    )}
                                </>
                            ) : (
                                <div className="flex items-center gap-2 text-red-700">
                                    <XCircle size={18} />
                                    {importResult.error}
                                </div>
                            )}
                        </div>
                    )}
                </div>

                {/* Export Section */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-3 bg-green-100 rounded-lg">
                            <Download className="text-green-600" size={24} />
                        </div>
                        <div>
                            <h2 className="text-lg font-semibold text-gray-900">Exporter mes produits</h2>
                            <p className="text-sm text-gray-500">Télécharger tous vos produits</p>
                        </div>
                    </div>

                    <p className="text-sm text-gray-600 mb-4">
                        Exportez l'ensemble de votre catalogue au format CSV. Vous pourrez ensuite le modifier et le ré-importer.
                    </p>

                    <button
                        onClick={handleExport}
                        className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
                    >
                        <Download size={18} />
                        Exporter mon catalogue
                    </button>

                    <div className="mt-4 p-3 bg-gray-50 rounded-lg">
                        <p className="text-xs text-gray-500">
                            <strong>Colonnes exportées:</strong><br />
                            ID, Nom, Description, Prix, Stock, Catégorie, Marque, Unité, Poids, Images, Actif
                        </p>
                    </div>
                </div>
            </div>

            {/* Import History */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                <div className="flex justify-between items-center mb-4">
                    <h2 className="text-lg font-semibold text-gray-900">Historique des imports</h2>
                    <button
                        onClick={loadHistory}
                        className="p-2 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                        <RefreshCw size={18} />
                    </button>
                </div>

                {loadingHistory ? (
                    <div className="flex items-center justify-center py-8">
                        <RefreshCw className="animate-spin text-gray-400" size={24} />
                    </div>
                ) : history.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                        <FileText size={40} className="mx-auto mb-2 opacity-50" />
                        <p>Aucun import effectué</p>
                    </div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead className="bg-gray-50">
                                <tr>
                                    <th className="text-left p-3 font-medium text-gray-600">Date</th>
                                    <th className="text-left p-3 font-medium text-gray-600">Fichier</th>
                                    <th className="text-center p-3 font-medium text-gray-600">Total</th>
                                    <th className="text-center p-3 font-medium text-gray-600">Importés</th>
                                    <th className="text-center p-3 font-medium text-gray-600">Erreurs</th>
                                    <th className="text-center p-3 font-medium text-gray-600">Statut</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {history.map((item) => (
                                    <tr key={item.id} className="hover:bg-gray-50">
                                        <td className="p-3 text-gray-600">
                                            {new Date(item.created_at).toLocaleDateString('fr-FR', {
                                                day: 'numeric',
                                                month: 'short',
                                                year: 'numeric',
                                                hour: '2-digit',
                                                minute: '2-digit'
                                            })}
                                        </td>
                                        <td className="p-3 font-medium text-gray-900 truncate max-w-[200px]">
                                            {item.filename}
                                        </td>
                                        <td className="p-3 text-center text-gray-600">{item.total_rows}</td>
                                        <td className="p-3 text-center text-green-600 font-medium">{item.imported_count}</td>
                                        <td className="p-3 text-center text-red-600">{item.error_count}</td>
                                        <td className="p-3">
                                            <div className="flex items-center justify-center gap-1">
                                                {getStatusIcon(item.status)}
                                                <span className="text-xs">{getStatusLabel(item.status)}</span>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Help Section */}
            <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h3 className="font-medium text-blue-900 mb-2">💡 Conseils pour l'import</h3>
                <ul className="text-sm text-blue-800 space-y-1">
                    <li>• Utilisez le template fourni pour éviter les erreurs de format</li>
                    <li>• Les images doivent être des URLs (hébergées sur Cloudinary ou autre)</li>
                    <li>• Séparez plusieurs images par un point-virgule (;)</li>
                    <li>• Les champs obligatoires sont : <strong>nom</strong> et <strong>prix</strong></li>
                </ul>
            </div>
        </div>
    );
}
