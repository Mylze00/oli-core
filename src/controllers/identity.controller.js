const identityService = require('../services/identity.service');

/**
 * Controller pour la gestion des documents d'identité
 */

/**
 * Soumettre un document d'identité
 * POST /api/identity/submit
 */
exports.submitDocument = async (req, res) => {
    try {
        const userId = req.user.id;
        const { documentType, documentNumber, issuingCountry, issueDate, expiryDate, frontImageUrl, backImageUrl, selfieUrl } = req.body;

        const document = await identityService.submitDocument(userId, {
            documentType,
            documentNumber,
            issuingCountry,
            issueDate,
            expiryDate,
            frontImageUrl,
            backImageUrl,
            selfieUrl
        });

        res.status(201).json({
            success: true,
            message: 'Document soumis avec succès',
            data: document
        });
    } catch (error) {
        console.error('Error submitting document:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Erreur lors de la soumission du document'
        });
    }
};

/**
 * Récupérer les documents de l'utilisateur
 * GET /api/identity/my-documents
 */
exports.getMyDocuments = async (req, res) => {
    try {
        const userId = req.user.id;
        const documents = await identityService.getUserDocuments(userId);

        res.json({
            success: true,
            data: documents
        });
    } catch (error) {
        console.error('Error getting documents:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des documents'
        });
    }
};

/**
 * Vérifier si l'utilisateur a une identité vérifiée
 * GET /api/identity/verified-status
 */
exports.getVerifiedStatus = async (req, res) => {
    try {
        const userId = req.user.id;
        const hasVerified = await identityService.hasVerifiedIdentity(userId);

        res.json({
            success: true,
            data: { hasVerifiedIdentity: hasVerified }
        });
    } catch (error) {
        console.error('Error checking verified status:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la vérification du statut'
        });
    }
};

/**
 * Récupérer les documents en attente (Admin)
 * GET /api/identity/pending
 */
exports.getPendingDocuments = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 50;
        const documents = await identityService.getPendingDocuments(limit);

        res.json({
            success: true,
            data: documents
        });
    } catch (error) {
        console.error('Error getting pending documents:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des documents en attente'
        });
    }
};

/**
 * Approuver un document (Admin)
 * POST /api/identity/:documentId/approve
 */
exports.approveDocument = async (req, res) => {
    try {
        const { documentId } = req.params;
        const adminId = req.user.id;

        const document = await identityService.approveDocument(parseInt(documentId), adminId);

        res.json({
            success: true,
            message: 'Document approuvé avec succès',
            data: document
        });
    } catch (error) {
        console.error('Error approving document:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Erreur lors de l\'approbation du document'
        });
    }
};

/**
 * Rejeter un document (Admin)
 * POST /api/identity/:documentId/reject
 */
exports.rejectDocument = async (req, res) => {
    try {
        const { documentId } = req.params;
        const adminId = req.user.id;
        const { reason } = req.body;

        if (!reason) {
            return res.status(400).json({
                success: false,
                message: 'La raison du rejet est requise'
            });
        }

        const document = await identityService.rejectDocument(parseInt(documentId), adminId, reason);

        res.json({
            success: true,
            message: 'Document rejeté',
            data: document
        });
    } catch (error) {
        console.error('Error rejecting document:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Erreur lors du rejet du document'
        });
    }
};
