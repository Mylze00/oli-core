/**
 * Repository pour la gestion des taux de change
 * Gère les opérations CRUD sur la table exchange_rates
 */
const db = require('../config/db');

class ExchangeRateRepository {
    /**
     * Sauvegarder un nouveau taux de change
     */
    async saveRate(baseCurrency, targetCurrency, rate, source = 'exchangerate-api') {
        const query = `
            INSERT INTO exchange_rates (base_currency, target_currency, rate, source)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (base_currency, target_currency, DATE(fetched_at))
            DO UPDATE SET 
                rate = EXCLUDED.rate,
                fetched_at = CURRENT_TIMESTAMP,
                source = EXCLUDED.source
            RETURNING *
        `;

        const result = await db.query(query, [baseCurrency, targetCurrency, rate, source]);
        return result.rows[0];
    }

    /**
     * Récupérer le taux le plus récent
     */
    async getLatestRate(baseCurrency = 'USD', targetCurrency = 'CDF') {
        const query = `
            SELECT * FROM exchange_rates
            WHERE base_currency = $1 AND target_currency = $2
            ORDER BY fetched_at DESC
            LIMIT 1
        `;

        const result = await db.query(query, [baseCurrency, targetCurrency]);
        return result.rows[0] || null;
    }

    /**
     * Récupérer l'historique des taux sur N jours
     */
    async getRateHistory(baseCurrency = 'USD', targetCurrency = 'CDF', days = 30) {
        const query = `
            SELECT 
                id,
                base_currency,
                target_currency,
                rate,
                fetched_at,
                source
            FROM exchange_rates
            WHERE base_currency = $1 
                AND target_currency = $2
                AND fetched_at >= NOW() - INTERVAL '${days} days'
            ORDER BY fetched_at DESC
        `;

        const result = await db.query(query, [baseCurrency, targetCurrency]);
        return result.rows;
    }

    /**
     * Supprimer les anciens taux (plus de 90 jours)
     */
    async cleanOldRates(daysToKeep = 90) {
        const query = `
            DELETE FROM exchange_rates
            WHERE fetched_at < NOW() - INTERVAL '${daysToKeep} days'
            RETURNING COUNT(*) as deleted_count
        `;

        const result = await db.query(query);
        return result.rows[0]?.deleted_count || 0;
    }

    /**
     * Obtenir les statistiques des taux
     */
    async getRateStatistics(baseCurrency = 'USD', targetCurrency = 'CDF', days = 30) {
        const query = `
            SELECT 
                COUNT(*) as total_records,
                MIN(rate) as min_rate,
                MAX(rate) as max_rate,
                AVG(rate) as avg_rate,
                MIN(fetched_at) as oldest_date,
                MAX(fetched_at) as latest_date
            FROM exchange_rates
            WHERE base_currency = $1 
                AND target_currency = $2
                AND fetched_at >= NOW() - INTERVAL '${days} days'
        `;

        const result = await db.query(query, [baseCurrency, targetCurrency]);
        return result.rows[0];
    }
}

module.exports = new ExchangeRateRepository();
