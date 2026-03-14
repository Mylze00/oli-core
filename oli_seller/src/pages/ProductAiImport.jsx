import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Image as ImageIcon, Wand2, UploadCloud, CheckCircle2, AlertCircle } from 'lucide-react';
import { productAPI } from '../services/api';

export default function ProductAiImport() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);
    const [file, setFile] = useState(null);
    const [previewUrl, setPreviewUrl] = useState(null);
    const [isAnalyzing, setIsAnalyzing] = useState(false);
    const [error, setError] = useState(null);

    const handleFileChange = (e) => {
        const selectedFile = e.target.files[0];
        if (selectedFile && selectedFile.type.startsWith('image/')) {
            setFile(selectedFile);
            setPreviewUrl(URL.createObjectURL(selectedFile));
            setError(null);
        } else {
            setError("Veuillez sélectionner une image valide.");
        }
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        e.stopPropagation();
    };

    const handleDrop = (e) => {
        e.preventDefault();
        e.stopPropagation();
        const droppedFile = e.dataTransfer.files[0];
        if (droppedFile && droppedFile.type.startsWith('image/')) {
            setFile(droppedFile);
            setPreviewUrl(URL.createObjectURL(droppedFile));
            setError(null);
        } else {
            setError("Veuillez déposer une image valide.");
        }
    };

    const handleAnalyze = async () => {
        if (!file) return;
        
        try {
            setIsAnalyzing(true);
            setError(null);

            const result = await productAPI.analyzeScreenshot(file);

            if (result.success && result.data) {
                // Navigate to the detail mode form and pass the extracted data
                navigate('/products/new/detail', { state: { aiProductData: result.data, aiImageFile: file, aiImagePreview: previewUrl } });
            } else {
                setError("L'analyse a échoué. Veuillez réessayer.");
            }
        } catch (err) {
            console.error('Analysis error:', err);
            setError(err.response?.data?.error || "Une erreur s'est produite lors de la connexion à l'IA.");
        } finally {
            setIsAnalyzing(false);
        }
    };

    return (
        <div className="p-8 max-w-4xl mx-auto">
            <button
                onClick={() => navigate('/products/new')}
                className="text-gray-500 flex items-center gap-2 mb-6 hover:text-gray-900 transition-colors"
                disabled={isAnalyzing}
            >
                <ArrowLeft size={16} /> Retour aux modes
            </button>

            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-8">
                <div className="text-center mb-8">
                    <div className="w-16 h-16 bg-purple-100 text-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Wand2 size={32} />
                    </div>
                    <h1 className="text-2xl font-bold text-gray-900 mb-2">
                        Importation Magique par IA
                    </h1>
                    <p className="text-gray-500">
                        Téléchargez une capture d'écran de l'article (depuis Alibaba, Amazon, ou autre). Notre IA va lire l'image et pré-remplir votre fiche produit complète !
                    </p>
                </div>

                {error && (
                    <div className="mb-6 p-4 bg-red-50 text-red-600 rounded-xl flex items-center gap-3">
                        <AlertCircle size={20} />
                        <p className="font-medium text-sm">{error}</p>
                    </div>
                )}

                <div 
                    className={`border-2 border-dashed rounded-2xl p-8 text-center transition-all ${previewUrl ? 'border-purple-300 bg-purple-50' : 'border-gray-300 hover:border-purple-400 hover:bg-purple-50'}`}
                    onDragOver={handleDragOver}
                    onDrop={handleDrop}
                    onClick={() => !isAnalyzing && fileInputRef.current?.click()}
                >
                    <input 
                        type="file" 
                        ref={fileInputRef} 
                        className="hidden" 
                        accept="image/*" 
                        onChange={handleFileChange}
                    />

                    {previewUrl ? (
                        <div className="flex flex-col items-center">
                            <img 
                                src={previewUrl} 
                                alt="Aperçu" 
                                className="max-h-64 rounded-lg shadow-sm mb-4 object-contain"
                            />
                            <p className="text-sm text-gray-500">Cliquez ou glissez une autre image pour remplacer</p>
                        </div>
                    ) : (
                        <div className="flex flex-col items-center py-8">
                            <UploadCloud size={48} className="text-purple-400 mb-4" />
                            <h3 className="text-lg font-semibold text-gray-900 mb-1">
                                Déposez votre capture ici
                            </h3>
                            <p className="text-gray-500 text-sm mb-4">
                                PNG, JPG ou WEBP (Max. 5 MB)
                            </p>
                            <button className="px-6 py-2 bg-purple-100 text-purple-700 font-medium rounded-lg hover:bg-purple-200 transition-colors">
                                Parcourir les fichiers
                            </button>
                        </div>
                    )}
                </div>

                <div className="mt-8 flex justify-end">
                    <button
                        onClick={handleAnalyze}
                        disabled={!file || isAnalyzing}
                        className={`px-8 py-3 rounded-xl font-bold flex items-center gap-2 transition-all ${(!file || isAnalyzing) ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-purple-600 text-white hover:bg-purple-700 shadow-md hover:shadow-lg'}`}
                    >
                        {isAnalyzing ? (
                            <>
                                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                Analyse en cours...
                            </>
                        ) : (
                            <>
                                <Wand2 size={20} />
                                Analyser et Pré-remplir
                            </>
                        )}
                    </button>
                </div>
            </div>
            
            <div className="mt-6 flex items-start gap-4 p-4 bg-gray-50 rounded-xl">
                <CheckCircle2 className="text-emerald-500 shrink-0 mt-1" size={24} />
                <div>
                    <h4 className="font-semibold text-gray-900">Que gardez-vous à faire ?</h4>
                    <p className="text-sm text-gray-600 mt-1">Vous aurez l'occasion de vérifier et modifier toutes les informations déduites par l'IA dans l'écran suivant avant de valider la publication de l'article.</p>
                </div>
            </div>
        </div>
    );
}
