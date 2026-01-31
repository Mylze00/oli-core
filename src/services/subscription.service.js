const pool = require('../config/db');

class SubscriptionService {

    /**
     * Upgrade user subscription plan
     * @param {string} userId 
     * @param {string} plan 'certified' or 'enterprise'
     * @param {string} paymentMethod 'orange_money', 'mtn', 'card'
     */
    async upgradeSubscription(userId, plan, paymentMethod) {
        // Validation des plans
        const VALID_PLANS = ['certified', 'enterprise'];
        if (!VALID_PLANS.includes(plan)) {
            throw new Error("Plan invalide. Choix: certified, enterprise");
        }

        // Simulation Paiement (TODO: Intégrer Stripe/Mobile Money API ici)
        const isPaymentSuccessful = await this._mockPaymentProcess(plan, paymentMethod);
        if (!isPaymentSuccessful) {
            throw new Error("Échec du paiement");
        }

        // Calcul expiration (30 jours)
        const endDate = new Date();
        endDate.setDate(endDate.getDate() + 30);

        // Update DB
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

        // Check expiration
        if (user.subscription_status === 'active' && new Date(user.subscription_end_date) < new Date()) {
            await pool.query("UPDATE users SET subscription_status = 'expired' WHERE id = $1", [userId]);
            user.subscription_status = 'expired';
        }

        return user;
    }

    // --- Private ---
    async _mockPaymentProcess(plan, method) {
        // En vrai: Appeler l'API de paiement
        console.log(`[PAIEMENT] $${plan === 'enterprise' ? 39 : 4.99} via ${method} - SUCCÈS`);
        return true;
    }
}

module.exports = new SubscriptionService();
