const identityRepository = require('../repositories/identity.repository');
const verificationRepository = require('../repositories/verification.repository');
const trustScoreRepository = require('../repositories/trust-score.repository');
const behaviorRepository = require('../repositories/behavior.repository');

/**
 * Service pour la gestion des documents d'identité
 */

/**
 * Soumettre un document d'identité
 */
async function submitDocument(userId, documentData) {
    // Validation
    if (!documentData.documentType || !documentData.frontImageUrl) {
        throw new Error('Type de document et image recto requis');
    }

    const validTypes = ['passport', 'national_id', 'driver_license', 'proof_of_address'];
    if (!validTypes.includes(documentData.documentType)) {
        throw new Error('Type de document invalide');
    }

    // Vérifier si un document de ce type existe déjà
    const existingDocs = await identityRepository.findByUserId(userId);
    const hasType = existingDocs.some(doc => doc.document_type === documentData.documentType);

    if (hasType) {
        throw new Error('Un document de ce type a déjà été soumis');
    }

    // Créer le document
    const document = await identityRepository.createIdentityDocument({
        userId,
        ...documentData
    });

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'document_submitted',
        eventCategory: 'security',
        eventData: { documentType: documentData.documentType, documentId: document.id }
    });

    return document;
}

/**
 * Approuver un document d'identité (Admin)
 */
async function approveDocument(documentId, adminId) {
    const document = await identityRepository.findById(documentId);

    if (!document) {
        throw new Error('Document non trouvé');
    }

    if (document.verification_status !== 'pending') {
        throw new Error('Ce document a déjà été traité');
    }

    // Mettre à jour le statut
    const updatedDoc = await identityRepository.updateVerificationStatus(
        documentId,
        'approved',
        adminId
    );

    // Mettre à jour la vérification d'identité
    await verificationRepository.updateIdentityVerification(document.user_id, true);

    // Mettre à jour le trust score
    await trustScoreRepository.updateIdentityScore(document.user_id, 100);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId: document.user_id,
        eventType: 'document_approved',
        eventCategory: 'security',
        eventData: { documentType: document.document_type, documentId }
    });

    return updatedDoc;
}

/**
 * Rejeter un document d'identité (Admin)
 */
async function rejectDocument(documentId, adminId, reason) {
    const document = await identityRepository.findById(documentId);

    if (!document) {
        throw new Error('Document non trouvé');
    }

    if (document.verification_status !== 'pending') {
        throw new Error('Ce document a déjà été traité');
    }

    // Mettre à jour le statut
    const updatedDoc = await identityRepository.updateVerificationStatus(
        documentId,
        'rejected',
        adminId,
        reason
    );

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId: document.user_id,
        eventType: 'document_rejected',
        eventCategory: 'security',
        eventData: { documentType: document.document_type, documentId, reason }
    });

    return updatedDoc;
}

/**
 * Récupérer les documents d'un utilisateur
 */
async function getUserDocuments(userId) {
    return await identityRepository.findByUserId(userId);
}

/**
 * Récupérer les documents en attente (Admin)
 */
async function getPendingDocuments(limit = 50) {
    return await identityRepository.findPendingDocuments(limit);
}

/**
 * Vérifier si l'utilisateur a un document vérifié
 */
async function hasVerifiedIdentity(userId) {
    return await identityRepository.hasVerifiedDocument(userId, 'national_id') ||
        await identityRepository.hasVerifiedDocument(userId, 'passport') ||
        await identityRepository.hasVerifiedDocument(userId, 'driver_license');
}

module.exports = {
    submitDocument,
    approveDocument,
    rejectDocument,
    getUserDocuments,
    getPendingDocuments,
    hasVerifiedIdentity
};
