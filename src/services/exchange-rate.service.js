/**
 * Service de gestion des taux de change
 * Récupère les taux depuis une API externe et gère la conversion
 */
const axios = require('axios');
const exchangeRateRepository = require('../repositories/exchange-rate.repository');

const EXCHANGE_RATE_API_URL = 'https://api.exchangerate-api.com/v4/latest';
const CACHE_DURATION_MS = 3600000; // 1 heure
const MAX_ORDER_RATE_AGE_MS = 24 * 3600000; // 24 heures
const API_SOURCE = 'exchangerate-api';

class ExchangeRateService {
    constructor() {
        this.cache = {
            rate: null,
            timestamp: null
        };
    }

    _isCacheFresh() {
        return Boolean(this.cache.rate && this.cache.timestamp
            && (Date.now() - this.cache.timestamp) < CACHE_DURATION_MS);
    }

    /**
     * Interroge l'API externe, enregistre le taux et met à jour le cache.
     * @throws {Error} si l'API ou l'enregistrement échoue
     */
    async _fetchAndStoreRate(baseCurrency = 'USD') {
        console.log(`[EXCHANGE] Récupération du taux depuis l'API pour ${baseCurrency}...`);
        const response = await axios.get(`${EXCHANGE_RATE_API_URL}/${baseCurrency}`, {
            timeout: 5000
        });

        if (!response.data || !response.data.rates) {
            throw new Error('Réponse API invalide');
        }

        const cdfRate = response.data.rates.CDF;
        if (!cdfRate) {
            throw new Error('Taux CDF non disponible dans la réponse API');
        }

        await exchangeRateRepository.saveRate(baseCurrency, 'CDF', cdfRate, API_SOURCE);

        this.cache = {
            rate: cdfRate,
            timestamp: Date.now()
        };

        console.log(`✅ [EXCHANGE] Taux mis à jour: 1 ${baseCurrency} = ${cdfRate} CDF`);
        return cdfRate;
    }

    /**
     * Taux USD → FC à figer sur une commande.
     * Contrairement à fetchLiveRate, n'utilise jamais un taux ancien ni un taux par défaut :
     * un taux erroné ferait débiter ou créditer un montant faux.
     *
     * @returns {Promise<number>} 1 USD = X FC
     * @throws {Error} RATE_UNAVAILABLE si aucun taux de moins de 24 h n'est disponible
     */
    async getRateForOrder() {
        if (this._isCacheFresh()) {
            return this.cache.rate;
        }

        try {
            return await this._fetchAndStoreRate('USD');
        } catch (error) {
            console.error('❌ [EXCHANGE] Taux en direct indisponible pour la commande:', error.message);
        }

        const latest = await exchangeRateRepository.getLatestRate('USD', 'CDF');
        const isRecent = latest
            && latest.source === API_SOURCE
            && (Date.now() - new Date(latest.fetched_at).getTime()) <= MAX_ORDER_RATE_AGE_MS;
        if (isRecent) {
            return parseFloat(latest.rate);
        }

        throw new Error('RATE_UNAVAILABLE');
    }

    /**
     * Récupérer le taux en temps réel depuis l'API externe
     */
    async fetchLiveRate(baseCurrency = 'USD') {
        try {
            return await this._fetchAndStoreRate(baseCurrency);
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
        const isUsdToCdf = fromCurrency === 'USD' && toCurrency === 'CDF';
        const isCdfToUsd = fromCurrency === 'CDF' && toCurrency === 'USD';
        if (!isUsdToCdf && !isCdfToUsd) {
            throw new Error(`Conversion ${fromCurrency} → ${toCurrency} non supportée`);
        }

        // Le cache contient toujours le taux USD → CDF
        const usdToCdf = this._isCacheFresh() ? this.cache.rate : await this.fetchLiveRate('USD');
        return isCdfToUsd ? 1 / usdToCdf : usdToCdf;
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
