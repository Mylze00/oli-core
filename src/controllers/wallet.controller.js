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
const { normalizePhone, maskPhone } = require('../utils/phone');
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
    // Recharge par carte désactivée : aucune donnée de carte (numéro, CVV) n'est lue ni transmise.
    return res.status(410).json({
        success: false,
        error: 'La recharge par carte n\'est pas disponible. Utilisez Mobile Money.',
    });
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

const ID_OLI = /^OLI-\d{4}-\d{4}$/;
const IDEMPOTENCY_KEY = /^[A-Za-z0-9_.:-]{8,80}$/;
const MAX_NOTE_LENGTH = 140;

/**
 * GET /api/wallet/resolve-recipient?identifier=…
 *
 * Trouve un compte Oli par numéro de téléphone (0812…, +243…, 243…) ou par
 * ID Oli (OLI-1234-5678). Exclut les comptes supprimés et son propre compte.
 * Le numéro n'est renvoyé en entier que si la personne est déjà dans
 * « Mes contacts » ; sinon il est masqué (+243 81•• ••• 678).
 */
exports.resolveRecipient = async (req, res) => {
    try {
        const raw = String(req.query.identifier || '');
        if (!raw.trim()) {
            return res.status(400).json({ success: false, error: 'Identifiant requis', code: 'missing_identifier' });
        }

        const pool = require('../config/db');
        const idOli = raw.trim().toUpperCase();
        let condition;
        let value;
        if (ID_OLI.test(idOli)) {
            condition = 'UPPER(u.id_oli) = $1';
            value = idOli;
        } else {
            // Un « + » mal encodé dans l'URL arrive comme un espace : normalizePhone le gère.
            const phone = normalizePhone(raw);
            if (!phone) {
                return res.status(400).json({
                    success: false,
                    error: 'Numéro ou ID Oli invalide',
                    code: 'invalid_identifier',
                });
            }
            condition = 'u.phone = $1';
            value = phone;
        }

        const { rows } = await pool.query(
            `SELECT u.id, u.name, u.avatar_url, u.id_oli, u.phone,
                    EXISTS (SELECT 1 FROM user_contacts c
                            WHERE c.owner_id = $2 AND c.contact_id = u.id) AS is_contact
             FROM users u
             WHERE ${condition} AND u.deleted_at IS NULL
             LIMIT 1`,
            [value, req.user.id]
        );

        const user = rows[0];
        if (!user) {
            return res.status(404).json({ success: false, error: 'Aucun compte Oli trouvé', code: 'not_found' });
        }
        if (String(user.id) === String(req.user.id)) {
            return res.status(400).json({ success: false, error: "C'est votre propre compte", code: 'own_account' });
        }

        res.json({
            success: true,
            user: {
                id: user.id,
                name: user.name,
                avatar_url: user.avatar_url,
                id_oli: user.id_oli,
                is_contact: user.is_contact,
                phone_masked: maskPhone(user.phone),
                // Numéro complet seulement pour un contact déjà enregistré
                ...(user.is_contact ? { phone: user.phone } : {}),
            },
        });
    } catch (err) {
        console.error('Erreur resolveRecipient:', err.message);
        res.status(500).json({ success: false, error: 'Erreur serveur' });
    }
};

/**
 * POST /api/wallet/transfer
 *
 * Body : { receiverId, amount, currency?: 'FC'|'USD', note? }
 *        (recipient_phone accepté pour les anciennes versions de l'app)
 * En-tête facultatif : Idempotency-Key — une même clé n'est débitée qu'une fois.
 */
exports.transfer = async (req, res) => {
    const { receiverId, recipient_phone, amount, currency, note } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ success: false, error: 'Montant invalide' });
    }
    if (!receiverId && !recipient_phone) {
        return res.status(400).json({ success: false, error: 'Destinataire requis' });
    }

    const idempotencyKey = req.get('Idempotency-Key') || req.body.idempotency_key || null;
    if (idempotencyKey && !IDEMPOTENCY_KEY.test(idempotencyKey)) {
        return res.status(400).json({ success: false, error: 'Clé de transfert invalide' });
    }

    const cleanNote = typeof note === 'string' && note.trim()
        ? note.trim().slice(0, MAX_NOTE_LENGTH)
        : null;

    try {
        let finalReceiverId = receiverId ? parseInt(receiverId) : null;

        // Anciennes versions : destinataire désigné par son numéro
        if (!finalReceiverId && recipient_phone) {
            const phone = normalizePhone(String(recipient_phone));
            const pool = require('../config/db');
            const { rows } = phone
                ? await pool.query('SELECT id FROM users WHERE phone = $1 AND deleted_at IS NULL', [phone])
                : { rows: [] };
            if (!rows.length) {
                return res.status(404).json({ success: false, error: 'Aucun compte Oli avec ce numéro' });
            }
            finalReceiverId = rows[0].id;
        }

        const result = await walletService.transferToUser(
            req.user.id,
            finalReceiverId,
            parseFloat(amount),
            currency || 'FC',
            req.app.get('io'),
            { note: cleanNote, idempotencyKey }
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

