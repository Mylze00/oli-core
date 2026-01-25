/**
 * Controller pour les taux de change
 * Gère les requêtes HTTP pour la conversion de devises
 */
const exchangeRateService = require('../services/exchange-rate.service');

class ExchangeRateController {
    /**
     * GET /api/exchange-rate/current?from=USD&to=CDF
     * Récupérer le taux de change actuel
     */
    async getCurrentRate(req, res) {
        try {
            const { from = 'USD', to = 'CDF' } = req.query;

            const rate = await exchangeRateService.getCurrentRate(from, to);

            res.json({
                success: true,
                data: {
                    from,
                    to,
                    rate,
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            console.error('[EXCHANGE CONTROLLER] Erreur getCurrentRate:', error);
            res.status(500).json({
                success: false,
                error: 'Erreur lors de la récupération du taux de change',
                message: error.message
            });
        }
    }

    /**
     * GET /api/exchange-rate/convert?amount=100&from=USD&to=CDF
     * Convertir un montant d'une devise à une autre
     */
    async convertAmount(req, res) {
        try {
            const { amount, from = 'USD', to = 'CDF' } = req.query;

            if (!amount || isNaN(amount)) {
                return res.status(400).json({
                    success: false,
                    error: 'Le paramètre "amount" est requis et doit être un nombre'
                });
            }

            const rate = await exchangeRateService.getCurrentRate(from, to);
            const converted = await exchangeRateService.convertAmount(amount, from, to);

            res.json({
                success: true,
                data: {
                    original: {
                        amount: parseFloat(amount),
                        currency: from
                    },
                    converted: {
                        amount: converted,
                        currency: to
                    },
                    rate,
                    timestamp: new Date().toISOString()
                }
            });
        } catch (error) {
            console.error('[EXCHANGE CONTROLLER] Erreur convertAmount:', error);
            res.status(500).json({
                success: false,
                error: 'Erreur lors de la conversion',
                message: error.message
            });
        }
    }

    /**
     * GET /api/exchange-rate/history?from=USD&to=CDF&days=30
     * Récupérer l'historique des taux
     */
    async getRateHistory(req, res) {
        try {
            const { from = 'USD', to = 'CDF', days = 30 } = req.query;

            const history = await exchangeRateService.getRateHistory(from, to, parseInt(days));

            res.json({
                success: true,
                data: {
                    from,
                    to,
                    days: parseInt(days),
                    history: history.map(record => ({
                        rate: parseFloat(record.rate),
                        date: record.fetched_at,
                        source: record.source
                    }))
                }
            });
        } catch (error) {
            console.error('[EXCHANGE CONTROLLER] Erreur getRateHistory:', error);
            res.status(500).json({
                success: false,
                error: 'Erreur lors de la récupération de l\'historique',
                message: error.message
            });
        }
    }

    /**
     * GET /api/exchange-rate/statistics?from=USD&to=CDF&days=30
     * Récupérer les statistiques des taux
     */
    async getStatistics(req, res) {
        try {
            const { from = 'USD', to = 'CDF', days = 30 } = req.query;

            const stats = await exchangeRateService.getRateStatistics(from, to, parseInt(days));

            res.json({
                success: true,
                data: {
                    from,
                    to,
                    period: `${days} jours`,
                    statistics: stats
                }
            });
        } catch (error) {
            console.error('[EXCHANGE CONTROLLER] Erreur getStatistics:', error);
            res.status(500).json({
                success: false,
                error: 'Erreur lors de la récupération des statistiques',
                message: error.message
            });
        }
    }

    /**
     * POST /api/exchange-rate/refresh (Admin uniquement)
     * Forcer la mise à jour des taux
     */
    async refreshRates(req, res) {
        try {
            await exchangeRateService.fetchLiveRate('USD');

            res.json({
                success: true,
                message: 'Taux de change mis à jour avec succès',
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            console.error('[EXCHANGE CONTROLLER] Erreur refreshRates:', error);
            res.status(500).json({
                success: false,
                error: 'Erreur lors de la mise à jour des taux',
                message: error.message
            });
        }
    }
}

module.exports = new ExchangeRateController();
