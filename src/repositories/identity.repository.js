const pool = require("../config/db");

/**
 * Repository pour la gestion des documents d'identité
 */

/**
 * Créer un nouveau document d'identité
 */
async function createIdentityDocument(data) {
    const query = `
        INSERT INTO user_identity_documents (
            user_id, document_type, document_number, issuing_country,
            issue_date, expiry_date, front_image_url, back_image_url,
            selfie_url, verification_status, submitted_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending', NOW())
        RETURNING *
    `;
    
    const { rows } = await pool.query(query, [
        data.userId,
        data.documentType,
        data.documentNumber,
        data.issuingCountry,
        data.issueDate,
        data.expiryDate,
        data.frontImageUrl,
        data.backImageUrl,
        data.selfieUrl
    ]);
    
    return rows[0];
}

/**
 * Récupérer tous les documents d'un utilisateur
 */
async function findByUserId(userId) {
    const query = `
        SELECT * FROM user_identity_documents
        WHERE user_id = $1
        ORDER BY created_at DESC
    `;
    
    const { rows } = await pool.query(query, [userId]);
    return rows;
}

/**
 * Récupérer un document par ID
 */
async function findById(documentId) {
    const query = `
        SELECT * FROM user_identity_documents
        WHERE id = $1
    `;
    
    const { rows } = await pool.query(query, [documentId]);
    return rows[0];
}

/**
 * Mettre à jour le statut de vérification d'un document
 */
async function updateVerificationStatus(documentId, status, verifiedBy, rejectionReason = null) {
    const query = `
        UPDATE user_identity_documents
        SET 
            verification_status = $1,
            verified_by = $2,
            verified_at = NOW(),
            rejection_reason = $3,
            updated_at = NOW()
        WHERE id = $4
        RETURNING *
    `;
    
    const { rows } = await pool.query(query, [status, verifiedBy, rejectionReason, documentId]);
    return rows[0];
}

/**
 * Récupérer tous les documents en attente de vérification
 */
async function findPendingDocuments(limit = 50) {
    const query = `
        SELECT 
            d.*,
            u.name as user_name,
            u.phone as user_phone,
            u.id_oli as user_id_oli
        FROM user_identity_documents d
        JOIN users u ON d.user_id = u.id
        WHERE d.verification_status = 'pending'
        ORDER BY d.submitted_at ASC
        LIMIT $1
    `;
    
    const { rows } = await pool.query(query, [limit]);
    return rows;
}

/**
 * Vérifier si un utilisateur a un document vérifié d'un certain type
 */
async function hasVerifiedDocument(userId, documentType) {
    const query = `
        SELECT EXISTS(
            SELECT 1 FROM user_identity_documents
            WHERE user_id = $1 
            AND document_type = $2
            AND verification_status = 'approved'
        ) as has_verified
    `;
    
    const { rows } = await pool.query(query, [userId, documentType]);
    return rows[0].has_verified;
}

module.exports = {
    createIdentityDocument,
    findByUserId,
    findById,
    updateVerificationStatus,
    findPendingDocuments,
    hasVerifiedDocument
};
