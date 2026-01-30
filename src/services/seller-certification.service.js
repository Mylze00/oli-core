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
        try {
            // Requête simplifiée qui ne dépend que de la table users
            const result = await db.query(`
                SELECT 
                    u.account_type,
                    u.has_certified_shop,
                    COALESCE(u.total_sales, 0) as total_sales,
                    COALESCE(u.rating, 0) as rating,
                    u.created_at,
                    EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as active_days,
                    0 as trust_score,
                    FALSE as identity_verified,
                    NULL as progression
                FROM users u
                WHERE u.id = $1
            `, [userId]);

            if (!result.rows[0]) {
                return null;
            }

            const data = result.rows[0];

            // Calculer la progression côté application
            let progression = null;
            const sales = data.total_sales || 0;
            const days = data.active_days || 0;

            if (data.account_type === 'ordinaire') {
                progression = {
                    next_level: 'certifie',
                    requirements: {
                        sales_needed: Math.max(0, 10 - sales),
                        trust_score_needed: 60,
                        identity_verification_needed: true
                    }
                };
            } else if (data.account_type === 'certifie') {
                progression = {
                    next_level_option_1: {
                        level: 'entreprise',
                        requirements: {
                            sales_needed: Math.max(0, 50 - sales),
                            business_docs_needed: true,
                            active_days_needed: Math.max(0, 30 - days)
                        }
                    },
                    next_level_option_2: {
                        level: 'premium',
                        requirements: {
                            sales_needed: Math.max(0, 100 - sales),
                            trust_score_needed: 80,
                            rating_needed: Math.max(0, 4.5 - (data.rating || 0)),
                            active_days_needed: Math.max(0, 60 - days)
                        }
                    }
                };
            } else if (data.account_type === 'entreprise') {
                progression = {
                    next_level: 'premium',
                    requirements: {
                        sales_needed: Math.max(0, 100 - sales),
                        trust_score_needed: 80,
                        rating_needed: Math.max(0, 4.5 - (data.rating || 0)),
                        active_days_needed: Math.max(0, 60 - days)
                    }
                };
            }

            return {
                ...data,
                progression
            };
        } catch (error) {
            console.error('Error in getCertificationDetails:', error);
            // Retourner des données par défaut en cas d'erreur
            return {
                account_type: 'ordinaire',
                has_certified_shop: false,
                total_sales: 0,
                rating: 0,
                active_days: 0,
                trust_score: 0,
                identity_verified: false,
                progression: null
            };
        }
    }

    /**
     * Forcer le recalcul de la certification
     * @param {string} userId - UUID de l'utilisateur
     * @returns {Promise<string>} Nouveau type de compte
     */
    async recalculateCertification(userId) {
        try {
            const result = await db.query(
                'SELECT calculate_seller_account_type($1) as new_type',
                [userId]
            );
            return result.rows[0].new_type;
        } catch (error) {
            console.error('Error recalculating certification:', error);
            // Si la fonction n'existe pas, retourner le type actuel
            const user = await db.query('SELECT account_type FROM users WHERE id = $1', [userId]);
            return user.rows[0]?.account_type || 'ordinaire';
        }
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
