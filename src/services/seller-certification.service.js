const db = require('../config/db');

/**
 * Service de gestion de la certification vendeur
 */
class SellerCertificationService {

    /**
     * Récupérer les détails de certification d'un vendeur
     * @param {string} userId - UUID de l'utilisateur
     * @returns {Promise<Object>} Détails de certification
     */
    async getCertificationDetails(userId) {
        const result = await db.query(`
            SELECT 
                u.account_type,
                u.has_certified_shop,
                u.total_sales,
                u.rating,
                u.created_at,
                EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as active_days,
                COALESCE(uts.overall_score, 0) as trust_score,
                COALESCE(uvl.identity_verified, FALSE) as identity_verified,
                
                -- Critères pour niveau suivant
                CASE 
                    WHEN u.account_type = 'ordinaire' THEN 
                        jsonb_build_object(
                            'next_level', 'certifie',
                            'requirements', jsonb_build_object(
                                'sales_needed', GREATEST(0, 10 - COALESCE(u.total_sales, 0)),
                                'trust_score_needed', GREATEST(0, 60 - COALESCE(uts.overall_score, 0)),
                                'identity_verification_needed', NOT COALESCE(uvl.identity_verified, FALSE)
                            )
                        )
                    WHEN u.account_type = 'certifie' THEN 
                        jsonb_build_object(
                            'next_level_option_1', jsonb_build_object(
                                'level', 'entreprise',
                                'requirements', jsonb_build_object(
                                    'sales_needed', GREATEST(0, 50 - COALESCE(u.total_sales, 0)),
                                    'business_docs_needed', TRUE,
                                    'active_days_needed', GREATEST(0, 30 - EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER)
                                )
                            ),
                            'next_level_option_2', jsonb_build_object(
                                'level', 'premium',
                                'requirements', jsonb_build_object(
                                    'sales_needed', GREATEST(0, 100 - COALESCE(u.total_sales, 0)),
                                    'trust_score_needed', GREATEST(0, 80 - COALESCE(uts.overall_score, 0)),
                                    'rating_needed', GREATEST(0, 4.5 - COALESCE(u.rating, 0)),
                                    'active_days_needed', GREATEST(0, 60 - EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER)
                                )
                            )
                        )
                    WHEN u.account_type = 'entreprise' THEN 
                        jsonb_build_object(
                            'next_level', 'premium',
                            'requirements', jsonb_build_object(
                                'sales_needed', GREATEST(0, 100 - COALESCE(u.total_sales, 0)),
                                'trust_score_needed', GREATEST(0, 80 - COALESCE(uts.overall_score, 0)),
                                'rating_needed', GREATEST(0, 4.5 - COALESCE(u.rating, 0)),
                                'active_days_needed', GREATEST(0, 60 - EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER)
                            )
                        )
                    ELSE NULL
                END as progression
                
            FROM users u
            LEFT JOIN user_trust_scores uts ON uts.user_id = u.id
            LEFT JOIN user_verification_levels uvl ON uvl.user_id = u.id
            WHERE u.id = $1
        `, [userId]);

        return result.rows[0] || null;
    }

    /**
     * Forcer le recalcul de la certification
     * @param {string} userId - UUID de l'utilisateur
     * @returns {Promise<string>} Nouveau type de compte
     */
    async recalculateCertification(userId) {
        const result = await db.query(
            'SELECT calculate_seller_account_type($1) as new_type',
            [userId]
        );
        return result.rows[0].new_type;
    }

    /**
     * Soumettre documents entreprise pour vérification
     * @param {string} userId - UUID de l'utilisateur
     * @param {Object} documents - Documents à soumettre
     * @returns {Promise<Object>} Résultat de la soumission
     */
    async submitBusinessDocuments(userId, documents) {
        const { registrationNumber, taxId, documentUrls } = documents;

        // Insérer dans user_identity_documents
        await db.query(`
            INSERT INTO user_identity_documents (
                user_id, document_type, document_number, 
                front_image_url, verification_status, submitted_at
            )
            VALUES ($1, 'business_registration', $2, $3, 'pending', NOW())
            ON CONFLICT (user_id, document_type) 
            DO UPDATE SET 
                document_number = $2,
                front_image_url = $3,
                verification_status = 'pending',
                submitted_at = NOW()
        `, [userId, registrationNumber, documentUrls.front]);

        // TODO: Notifier admin pour vérification
        console.log(`📄 Documents entreprise soumis pour user ${userId}`);

        return {
            success: true,
            message: 'Documents soumis pour vérification. Vous serez notifié sous 48h.'
        };
    }

    /**
     * Obtenir les avantages du niveau actuel
     * @param {string} accountType - Type de compte
     * @returns {Array<string>} Liste des avantages
     */
    getBenefits(accountType) {
        const benefits = {
            ordinaire: [
                'Accès à la plateforme de vente',
                'Publication de produits',
                'Chat avec acheteurs',
                'Gestion des commandes'
            ],
            certifie: [
                'Badge de certification bleu ✓',
                'Priorité dans les résultats de recherche (+10%)',
                'Profil mis en avant',
                'Statistiques de ventes basiques',
                'Confiance accrue des acheteurs'
            ],
            premium: [
                'Badge Premium vert ⭐',
                'Priorité maximale dans les résultats (+30%)',
                'Commission réduite (-0.5%)',
                'Analytics avancés et rapports détaillés',
                'Accès au live shopping',
                'Rapport de ventes hebdomadaire',
                'Support client prioritaire'
            ],
            entreprise: [
                'Badge Entreprise or 🏆',
                'Priorité élevée dans les résultats (+20%)',
                'Support client prioritaire 24/7',
                'Boutique officielle automatique',
                'Gestion multi-utilisateurs',
                'API pour intégrations tierces',
                'Compte manager dédié'
            ]
        };

        return benefits[accountType] || benefits.ordinaire;
    }

    /**
     * Obtenir le label du niveau
     * @param {string} accountType - Type de compte
     * @returns {string} Label du niveau
     */
    getLevelLabel(accountType) {
        const labels = {
            ordinaire: 'Vendeur Standard',
            certifie: 'Vendeur Certifié',
            premium: 'Vendeur Premium',
            entreprise: 'Entreprise Certifiée'
        };
        return labels[accountType] || labels.ordinaire;
    }
}

module.exports = new SellerCertificationService();
