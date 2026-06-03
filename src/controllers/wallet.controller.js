/**
 * Wallet Controller OLI
 *
 * Routes exposées (montées sous /api/wallet) :
 *   GET  /balance              — Solde actuel (FC + équivalent USD)
 *   GET  /transactions         — Historique des transactions
 *   POST /deposit              — Recharge via Mobile Money (C2B → Unipesa)
 *   POST /deposit-card         — Recharge via Carte bancaire
 *   POST /withdraw             — Retrait vers Mobile Money (B2C → Unipesa)
 *   POST /transfer             — Transfert P2P entre utilisateurs OLI
 *   GET  /status/:orderId      — Polling statut d'un paiement Mobile Money
 */
const walletService  = require('../services/wallet.service');
const unipesaService = require('../services/unipesa.service');
const walletRepo     = require('../repositories/wallet.repository');
const { FC_TO_USD_FALLBACK } = require('../config/index');

const FC_TO_USD = FC_TO_USD_FALLBACK; // taux de change de secours (config centralisée)

// ─── Lecture ────────────────────────────────────────────────────────────────

exports.getBalance = async (req, res) => {
    try {
        const wallet = await walletRepo.getWallet(req.user.id);
        const balanceFC  = parseFloat(wallet.balance);
        const balanceUSD = +(balanceFC / FC_TO_USD).toFixed(4);

        res.json({
            success:          true,
            balanceFC,                                          // Devise officielle OLI (Francs Congolais)
            balanceUSD,                                         // Informatif — calculé côté serveur
            currency:         wallet.currency || 'FC',          // ✅ Correct (plus 'USD' mensonger)
            formattedBalanceFC: `${balanceFC.toLocaleString('fr-CD')} FC`,
            is_frozen:        wallet.is_frozen,
            updated_at:       wallet.updated_at,
        });
    } catch (err) {
        console.error('Erreur solde wallet:', err.message);
        res.status(500).json({ success: false, error: 'Impossible de récupérer le solde' });
    }
};

exports.getHistory = async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit)  || 30, 100);
        const offset = Math.max(parseInt(req.query.offset) || 0,  0);
        const history = await walletService.getHistory(req.user.id, limit, offset);
        res.json({
            success:      true,
            transactions: history,
            count:        history.length,
            limit,
            offset,
        });
    } catch (err) {
        console.error('Erreur historique wallet:', err.message);
        res.status(500).json({ success: false, error: "Impossible de récupérer l'historique" });
    }
};

exports.getSummary = async (req, res) => {
    try {
        const pool = require('../config/db');
        const wallet = await walletRepo.getWallet(req.user.id);
        const balanceFC = parseFloat(wallet.balance);
        const balanceUSD = +(balanceFC / FC_TO_USD).toFixed(4);

        const statsQuery = await pool.query(`
            SELECT 
                SUM(amount) FILTER (WHERE type = 'deposit') as total_deposited,
                SUM(ABS(amount)) FILTER (WHERE type = 'withdrawal') as total_withdrawn,
                SUM(ABS(amount)) FILTER (WHERE type = 'transfer' AND amount < 0) as total_sent,
                SUM(amount) FILTER (WHERE type = 'transfer' AND amount > 0) as total_received,
                SUM(ABS(amount)) FILTER (WHERE type = 'payment') as total_purchases,
                SUM(amount) FILTER (WHERE type = 'credit') as total_earned
            FROM wallet_transactions 
            WHERE user_id = $1 AND status = 'completed'
        `, [req.user.id]);
        
        const row = statsQuery.rows[0] || {};
        
        const history = await walletService.getHistory(req.user.id, 5, 0);

        res.json({
            success: true,
            balanceFC,
            balanceUSD,
            currency: wallet.currency || 'FC',
            stats: {
                totalDeposited: parseFloat(row.total_deposited || 0),
                totalWithdrawn: parseFloat(row.total_withdrawn || 0),
                totalSent: parseFloat(row.total_sent || 0),
                totalReceived: parseFloat(row.total_received || 0),
                totalPurchases: parseFloat(row.total_purchases || 0),
                totalEarned: parseFloat(row.total_earned || 0)
            },
            recentTransactions: history
        });
    } catch (err) {
        console.error('Erreur summary wallet:', err.message);
        res.status(500).json({ success: false, error: "Impossible de récupérer le résumé" });
    }
};

// ─── Recharge Mobile Money ───────────────────────────────────────────────────
//
// Body attendu : { amountFC: number, phone: string, provider?: string }
//   - amountFC  : montant en Francs Congolais (ex: 5000)
//   - phone     : numéro Mobile Money (ex: "+243810000001")
//   - provider  : optionnel — détecté automatiquement depuis le préfixe du numéro
//
// Flux : Controller → walletService.deposit() → unipesaService.initiateDeposit()
//        → push USSD sur téléphone → status "pending"
//        → webhook Unipesa → crédit wallet

exports.deposit = async (req, res) => {
    // Accepter amountFC (nouveau) ou amount (rétro-compat)
    const amountFC    = parseFloat(req.body.amountFC || req.body.amount);
    const phone       = req.body.phone || req.body.phoneNumber;
    const provider    = req.body.provider; // optionnel — détecté auto depuis le numéro

    // ── Validations ──────────────────────────────────────────────────────────
    if (!amountFC || isNaN(amountFC) || amountFC <= 0) {
        return res.status(400).json({
            success: false,
            error:   'Montant invalide. Fournissez amountFC (Francs Congolais, ex: 5000).',
        });
    }
    if (amountFC < 500) {
        return res.status(400).json({
            success: false,
            error:   'Montant minimum de recharge : 500 FC',
        });
    }
    if (amountFC > 10_000_000) {
        return res.status(400).json({
            success: false,
            error:   'Montant maximum de recharge : 10 000 000 FC',
        });
    }
    if (!phone) {
        return res.status(400).json({
            success: false,
            error:   'Numéro de téléphone Mobile Money requis (ex: "+243810000001")',
        });
    }

    try {
        const result = await walletService.deposit(
            req.user.id,
            amountFC,
            provider || null, // provider optionnel — détecté automatiquement
            phone
        );

        console.log(`📲 Dépôt initié: user #${req.user.id} — ${amountFC} FC via ${phone}`);

        return res.status(200).json({
            success:         true,
            message:         result.message,
            status:          'pending',
            oliOrderId:      result.oliOrderId,
            // ── Détail frais (affiché dans l'app Flutter) ──────────────────
            amountFC:        result.amountFC,         // Montant brut envoyé (FC)
            aggregatorFeeFC: result.aggregatorFeeFC,  // 3% frais Unipesa (FC)
            oliFeeFC:        result.oliFeeFC,          // 3% commission OLI (FC)
            totalFeeFC:      result.totalFeeFC,        // 6% total (FC)
            netAmountFC:     result.netAmountFC,       // Montant crédité sur wallet (FC)
            // ── Infos Mobile Money ─────────────────────────────────────────
            provider:        result.provider,          // Vodacom | Airtel | Orange | Africell
            phone:           result.phone || phone,
        });

    } catch (err) {
        console.error('❌ Erreur dépôt Mobile Money:', err.message);
        return res.status(400).json({ success: false, error: err.message });
    }
};

// ─── Polling statut paiement Mobile Money ────────────────────────────────────
//
// Appelé par Flutter toutes les ~5 secondes après POST /deposit.
// Retourne le statut courant de l'opération Unipesa.
//
// Statuts possibles : pending | success | failed | timeout

exports.getPaymentStatus = async (req, res) => {
    try {
        const { orderId } = req.params;
        const userId      = req.user.id;

        if (!orderId) {
            return res.status(400).json({ success: false, error: 'orderId requis' });
        }

        // Vérifier que l'opération appartient à cet utilisateur (sécurité)
        const { rows } = await require('../config/db').query(
            'SELECT user_id, status, amount_fc, provider FROM unipesa_operations WHERE oli_order_id = $1',
            [orderId]
        );

        if (!rows.length || parseInt(rows[0].user_id) !== parseInt(userId)) {
            return res.status(404).json({
                success: false,
                error:   'Opération introuvable ou non autorisée',
            });
        }

        // Si déjà finalisé localement, pas besoin d'appeler l'API externe
        const localStatus = rows[0].status;
        if (['success', 'failed', 'timeout', 'cancelled'].includes(localStatus)) {
            let wallet = null;
            if (localStatus === 'success') {
                wallet = await walletRepo.getWallet(userId);
            }
            return res.json({
                success:  true,
                orderId,
                status:   localStatus,
                amountFC: parseFloat(rows[0].amount_fc),
                provider: rows[0].provider,
                wallet:   wallet ? {
                    balanceFC:  parseFloat(wallet.balance),
                    balanceUSD: +(parseFloat(wallet.balance) / FC_TO_USD).toFixed(4),
                    currency:   wallet.currency || 'FC',
                } : null,
            });
        }

        // Sinon → vérifier le statut en temps réel via l'API Unipesa
        const result = await unipesaService.checkOperationStatus(orderId);

        let wallet = null;
        if (result.status === 'success') {
            wallet = await walletRepo.getWallet(userId);
        }

        return res.json({
            success:  true,
            orderId,
            status:   result.status,       // pending | success | failed | timeout
            amountFC: result.amountFC,
            provider: result.provider,
            wallet:   wallet ? {
                balanceFC:  parseFloat(wallet.balance),
                balanceUSD: +(parseFloat(wallet.balance) / FC_TO_USD).toFixed(4),
                currency:   wallet.currency || 'FC',
            } : null,
        });

    } catch (err) {
        console.error('❌ GET /wallet/status:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
};

// ─── Recharge Carte bancaire ─────────────────────────────────────────────────

exports.depositCard = async (req, res) => {
    const { amount, cardNumber, expiryDate, cvv, cardholderName } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ success: false, error: 'Montant invalide' });
    }

    try {
        const cardInfo = { cardNumber, expiryDate, cvv, cardholderName: cardholderName || 'Card Holder' };
        const result   = await walletService.depositByCard(req.user.id, parseFloat(amount), cardInfo);
        res.json({
            success:       true,
            message:       `Recharge de $${parseFloat(amount).toFixed(2)} par carte effectuée`,
            newBalance:    result.balanceAfter,
            transactionId: result.transactionId,
        });
    } catch (err) {
        console.error('Erreur dépôt carte:', err.message);
        res.status(400).json({ success: false, error: err.message });
    }
};

// ─── Retrait Mobile Money ────────────────────────────────────────────────────
//
// Body attendu : { amountFC: number, phone: string, provider?: string }

exports.withdraw = async (req, res) => {
    const amountFC   = parseFloat(req.body.amountFC || req.body.amount);
    const phone      = req.body.phone || req.body.phoneNumber;
    const provider   = req.body.provider;

    if (!amountFC || isNaN(amountFC) || amountFC <= 0) {
        return res.status(400).json({ success: false, error: 'Montant invalide' });
    }
    if (!phone) {
        return res.status(400).json({ success: false, error: 'Numéro de téléphone requis' });
    }

    try {
        const result = await walletService.withdraw(
            req.user.id,
            amountFC,
            provider || null,
            phone
        );
        return res.json({
            success:     true,
            message:     result.message || 'Retrait initié',
            status:      'pending',
            oliOrderId:  result.oliOrderId,
            amountFC,
            provider:    result.provider,
            ...result,
        });
    } catch (err) {
        console.error('Erreur retrait:', err.message);
        res.status(400).json({ success: false, error: err.message });
    }
};

// ─── Transfert P2P ───────────────────────────────────────────────────────────
//
// Body attendu : { receiverId: number, amount: number, currency?: 'USD'|'FC' }

exports.transfer = async (req, res) => {
    const { receiverId, recipient_phone, amount, currency, note } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ success: false, error: 'Montant invalide' });
    }
    if (!receiverId && !recipient_phone) {
        return res.status(400).json({ success: false, error: 'ID ou numéro de téléphone du destinataire requis' });
    }

    try {
        let finalReceiverId = receiverId ? parseInt(receiverId) : null;

        // Résolution par numéro de téléphone
        if (!finalReceiverId && recipient_phone) {
            const pool = require('../config/db');
            const { rows } = await pool.query(
                'SELECT id, name FROM users WHERE phone = $1', [recipient_phone]
            );
            if (!rows.length) {
                return res.status(404).json({
                    success: false,
                    error: `Aucun utilisateur OLI avec le numéro ${recipient_phone}`,
                });
            }
            finalReceiverId = rows[0].id;
        }

        const result = await walletService.transferToUser(
            req.user.id,
            finalReceiverId,
            parseFloat(amount),
            currency || 'FC',
            req.app.get('io')
        );
        res.json({
            success: true,
            message: `${result.amountFC} FC envoyés avec succès (frais: ${result.feeFC} FC)`,
            ...result,
        });
    } catch (err) {
        console.error('Erreur transfert P2P:', err.message);
        res.status(400).json({ success: false, error: err.message });
    }
};

