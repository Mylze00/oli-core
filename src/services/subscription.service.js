const pool = require('../config/db');

class SubscriptionService {

    constructor() {
        this._tableReady = null;
    }

    /**
     * Auto-create certification_requests table if not exists
     * Lazy init — will be awaited before every DB operation
     */
    async _ensureTable() {
        if (this._tableReady) return this._tableReady;

        this._tableReady = (async () => {
            try {
                await pool.query(`
                    CREATE TABLE IF NOT EXISTS certification_requests (
                        id SERIAL PRIMARY KEY,
                        user_id INTEGER NOT NULL,
                        plan VARCHAR(20) NOT NULL,
                        document_type VARCHAR(30) NOT NULL DEFAULT 'carte_identite',
                        id_card_url TEXT NOT NULL,
                        payment_method VARCHAR(30),
                        payment_reference VARCHAR(100),
                        status VARCHAR(20) DEFAULT 'pending',
                        rejection_reason TEXT,
                        reviewed_by INTEGER,
                        created_at TIMESTAMP DEFAULT NOW(),
                        reviewed_at TIMESTAMP
                    )
                `);
                console.log('✅ certification_requests table ready');
            } catch (err) {
                console.error('⚠️ certification_requests table init:', err.message);
                this._tableReady = null; // Retry on next call
                throw err;
            }
        })();

        return this._tableReady;
    }

    /**
     * Créer une demande de certification (status = pending)
     * L'utilisateur paie + upload sa carte → demande envoyée à l'admin
     */
    async createCertificationRequest(userId, plan, documentType, idCardUrl, paymentMethod = null, paymentReference = null) {
        await this._ensureTable();
        const VALID_PLANS = ['certified', 'enterprise'];
        if (!VALID_PLANS.includes(plan)) {
            throw new Error("Plan invalide. Choix: certified, enterprise");
        }

        const VALID_DOC_TYPES = ['carte_identite', 'passeport'];
        if (!VALID_DOC_TYPES.includes(documentType)) {
            throw new Error("Type de document invalide. Choix: carte_identite, passeport");
        }

        // Vérifier s'il y a déjà une demande en cours
        const existing = await pool.query(
            `SELECT id, status FROM certification_requests 
             WHERE user_id = $1 AND status = 'pending' 
             ORDER BY created_at DESC LIMIT 1`,
            [userId]
        );

        if (existing.rows.length > 0) {
            throw new Error("Vous avez déjà une demande en cours. Veuillez attendre la validation.");
        }

        // Créer la demande
        const result = await pool.query(`
            INSERT INTO certification_requests (user_id, plan, document_type, id_card_url, payment_method, payment_reference, status)
            VALUES ($1, $2, $3, $4, $5, $6, 'pending')
            RETURNING *
        `, [userId, plan, documentType, idCardUrl, paymentMethod, paymentReference]);

        console.log(`📋 Demande certification #${result.rows[0].id}: user=${userId}, plan=${plan}, doc=${documentType}, payment=${paymentMethod}`);

        return result.rows[0];
    }

    /**
     * Vérifier l'état de la demande de l'utilisateur
     */
    async getRequestStatus(userId) {
        await this._ensureTable();
        const result = await pool.query(`
            SELECT id, plan, document_type, status, rejection_reason, created_at, reviewed_at
            FROM certification_requests
            WHERE user_id = $1
            ORDER BY created_at DESC LIMIT 1
        `, [userId]);

        return result.rows[0] || null;
    }

    /**
     * [ADMIN] Lister les demandes en attente
     */
    async getPendingRequests() {
        await this._ensureTable();
        const result = await pool.query(`
            SELECT cr.*, 
                   u.name as user_name, u.phone as user_phone, u.avatar_url,
                   u.account_type as current_type
            FROM certification_requests cr
            JOIN users u ON cr.user_id = u.id
            WHERE cr.status = 'pending'
            ORDER BY cr.created_at ASC
        `);
        return result.rows;
    }

    /**
     * [ADMIN] Lister toutes les demandes (avec filtre optionnel)
     */
    async getAllRequests(status = null) {
        await this._ensureTable();
        let query = `
            SELECT cr.*, 
                   u.name as user_name, u.phone as user_phone, u.avatar_url,
                   u.account_type as current_type
            FROM certification_requests cr
            JOIN users u ON cr.user_id = u.id
        `;
        const params = [];

        if (status) {
            query += ` WHERE cr.status = $1`;
            params.push(status);
        }

        query += ` ORDER BY cr.created_at DESC`;

        const result = await pool.query(query, params);
        return result.rows;
    }

    /**
     * [ADMIN] Approuver une demande → upgrade l'utilisateur
     */
    async approveRequest(requestId, adminId) {
        await this._ensureTable();
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Récupérer la demande
            const request = await client.query(
                'SELECT * FROM certification_requests WHERE id = $1 AND status = $2',
                [requestId, 'pending']
            );

            if (request.rows.length === 0) {
                throw new Error("Demande introuvable ou déjà traitée");
            }

            const { user_id, plan } = request.rows[0];

            // Marquer la demande comme approuvée
            await client.query(`
                UPDATE certification_requests 
                SET status = 'approved', reviewed_by = $1, reviewed_at = NOW()
                WHERE id = $2
            `, [Number(adminId), Number(requestId)]);

            // Upgrade l'utilisateur
            const endDate = new Date();
            endDate.setDate(endDate.getDate() + 30);

            // Use separate variables to avoid PostgreSQL type inference issues
            const accountType = plan === 'enterprise' ? 'entreprise' : 'certifie';

            await client.query(`
                UPDATE users 
                SET subscription_plan = $1, 
                    subscription_status = 'active', 
                    subscription_end_date = $2,
                    account_type = $3,
                    is_verified = TRUE,
                    updated_at = NOW()
                WHERE id = $4
            `, [plan, endDate, accountType, user_id]);

            await client.query('COMMIT');

            console.log(`✅ Certification #${requestId} approuvée pour user ${user_id} → plan ${plan}`);

            return { success: true, user_id, plan };
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * [ADMIN] Rejeter une demande
     */
    async rejectRequest(requestId, adminId, reason) {
        await this._ensureTable();
        const result = await pool.query(`
            UPDATE certification_requests 
            SET status = 'rejected', reviewed_by = $1, reviewed_at = NOW(), rejection_reason = $2
            WHERE id = $3 AND status = 'pending'
            RETURNING *
        `, [Number(adminId), reason || 'Document non conforme', Number(requestId)]);

        if (result.rows.length === 0) {
            throw new Error("Demande introuvable ou déjà traitée");
        }

        console.log(`❌ Certification #${requestId} rejetée: ${reason}`);

        return { success: true, request: result.rows[0] };
    }

    /**
     * Upgrade user subscription plan (legacy — kept for admin direct upgrade)
     */
    async upgradeSubscription(userId, plan, paymentMethod) {
        const VALID_PLANS = ['certified', 'enterprise'];
        if (!VALID_PLANS.includes(plan)) {
            throw new Error("Plan invalide. Choix: certified, enterprise");
        }

        const isPaymentSuccessful = await this._mockPaymentProcess(plan, paymentMethod);
        if (!isPaymentSuccessful) {
            throw new Error("Échec du paiement");
        }

        const endDate = new Date();
        endDate.setDate(endDate.getDate() + 30);

        const query = `
            UPDATE users 
            SET subscription_plan = $1, 
                subscription_status = 'active', 
                subscription_end_date = $2,
                account_type = CASE 
                    WHEN $1 = 'enterprise' THEN 'entreprise'
                    WHEN $1 = 'certified' THEN 'certifie'
                    ELSE account_type 
                END,
                updated_at = NOW()
            WHERE id = $3
            RETURNING id, subscription_plan, subscription_status, subscription_end_date
        `;

        const { rows } = await pool.query(query, [plan, endDate, userId]);
        return rows[0];
    }

    /**
     * Check if subscription is active
     */
    async checkSubscriptionStatus(userId) {
        const query = `
            SELECT subscription_plan, subscription_status, subscription_end_date 
            FROM users 
            WHERE id = $1
        `;
        const { rows } = await pool.query(query, [userId]);
        if (rows.length === 0) return null;

        const user = rows[0];

        if (user.subscription_status === 'active' && new Date(user.subscription_end_date) < new Date()) {
            await pool.query("UPDATE users SET subscription_status = 'expired' WHERE id = $1", [userId]);
            user.subscription_status = 'expired';
        }

        return user;
    }

    // --- Private ---
    async _mockPaymentProcess(plan, method) {
        console.log(`[PAIEMENT] $${plan === 'enterprise' ? 39 : 4.99} via ${method} - SUCCÈS`);
        return true;
    }
}

module.exports = new SubscriptionService();
