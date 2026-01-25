/**
 * Service de gestion des taux de change
 * Récupère les taux depuis une API externe et gère la conversion
 */
const axios = require('axios');
const exchangeRateRepository = require('../repositories/exchange-rate.repository');

const EXCHANGE_RATE_API_URL = 'https://api.exchangerate-api.com/v4/latest';
const CACHE_DURATION_MS = 3600000; // 1 heure

class ExchangeRateService {
    constructor() {
        this.cache = {
            rate: null,
            timestamp: null
        };
    }

    /**
     * Récupérer le taux en temps réel depuis l'API externe
     */
    async fetchLiveRate(baseCurrency = 'USD') {
        try {
            console.log(`[EXCHANGE] Récupération du taux depuis l'API pour ${baseCurrency}...`);
            const response = await axios.get(`${EXCHANGE_RATE_API_URL}/${baseCurrency}`, {
                timeout: 5000
            });

            if (response.data && response.data.rates) {
                const cdfRate = response.data.rates.CDF;

                if (!cdfRate) {
                    throw new Error('Taux CDF non disponible dans la réponse API');
                }

                // Sauvegarder en base de données
                await exchangeRateRepository.saveRate(baseCurrency, 'CDF', cdfRate, 'exchangerate-api');

                // Mettre à jour le cache
                this.cache = {
                    rate: cdfRate,
                    timestamp: Date.now()
                };

                console.log(`✅ [EXCHANGE] Taux mis à jour: 1 ${baseCurrency} = ${cdfRate} CDF`);
                return cdfRate;
            }

            throw new Error('Réponse API invalide');
        } catch (error) {
            console.error(`❌ [EXCHANGE] Erreur lors de la récupération du taux:`, error.message);

            // Fallback: utiliser le dernier taux en base de données
            const latestRate = await exchangeRateRepository.getLatestRate(baseCurrency, 'CDF');
            if (latestRate) {
                console.log(`⚠️ [EXCHANGE] Utilisation du taux en cache: ${latestRate.rate}`);
                return parseFloat(latestRate.rate);
            }

            // Dernier fallback: taux par défaut
            console.warn(`⚠️ [EXCHANGE] Utilisation du taux par défaut: 2800`);
            return 2800.00;
        }
    }

    /**
     * Obtenir le taux actuel (avec cache)
     */
    async getCurrentRate(fromCurrency = 'USD', toCurrency = 'CDF') {
        // Vérifier le cache
        const now = Date.now();
        if (this.cache.rate && this.cache.timestamp && (now - this.cache.timestamp) < CACHE_DURATION_MS) {
            console.log(`[EXCHANGE] Utilisation du cache (${Math.round((now - this.cache.timestamp) / 1000)}s)`);
            return this.cache.rate;
        }

        // Si le cache est expiré, récupérer un nouveau taux
        if (fromCurrency === 'USD' && toCurrency === 'CDF') {
            return await this.fetchLiveRate('USD');
        }

        // Pour CDF → USD, inverser le taux
        if (fromCurrency === 'CDF' && toCurrency === 'USD') {
            const usdToCdf = await this.fetchLiveRate('USD');
            return 1 / usdToCdf;
        }

        throw new Error(`Conversion ${fromCurrency} → ${toCurrency} non supportée`);
    }

    /**
     * Convertir un montant d'une devise à une autre
     */
    async convertAmount(amount, fromCurrency = 'USD', toCurrency = 'CDF') {
        if (fromCurrency === toCurrency) {
            return parseFloat(amount);
        }

        const rate = await this.getCurrentRate(fromCurrency, toCurrency);
        const converted = parseFloat(amount) * rate;

        return Math.round(converted * 100) / 100; // Arrondir à 2 décimales
    }

    /**
     * Obtenir l'historique des taux
     */
    async getRateHistory(fromCurrency = 'USD', toCurrency = 'CDF', days = 30) {
        return await exchangeRateRepository.getRateHistory(fromCurrency, toCurrency, days);
    }

    /**
     * Obtenir les statistiques des taux
     */
    async getRateStatistics(fromCurrency = 'USD', toCurrency = 'CDF', days = 30) {
        const stats = await exchangeRateRepository.getRateStatistics(fromCurrency, toCurrency, days);

        return {
            totalRecords: parseInt(stats.total_records) || 0,
            minRate: parseFloat(stats.min_rate) || 0,
            maxRate: parseFloat(stats.max_rate) || 0,
            avgRate: parseFloat(stats.avg_rate) || 0,
            oldestDate: stats.oldest_date,
            latestDate: stats.latest_date
        };
    }

    /**
     * Mise à jour quotidienne des taux (appelé par cron)
     */
    async updateRatesDaily() {
        try {
            console.log('[EXCHANGE] 🔄 Mise à jour quotidienne des taux...');
            await this.fetchLiveRate('USD');

            // Nettoyer les anciens taux (garder 90 jours)
            const deletedCount = await exchangeRateRepository.cleanOldRates(90);
            if (deletedCount > 0) {
                console.log(`[EXCHANGE] 🗑️ ${deletedCount} anciens taux supprimés`);
            }

            console.log('[EXCHANGE] ✅ Mise à jour quotidienne terminée');
        } catch (error) {
            console.error('[EXCHANGE] ❌ Erreur lors de la mise à jour quotidienne:', error.message);
        }
    }
}

module.exports = new ExchangeRateService();
