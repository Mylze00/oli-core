/**
 * OLI Bank Service — Portail Cryptographique Central
 *
 * Ce service est le nœud central de toute la logique financière et
 * utilisateur de la plateforme OLI. Chaque utilisateur possède une
 * identité cryptographique (keypair RSA) et toutes ses transactions
 * sont enregistrées dans un Grand Livre signé et chaîné.
 *
 * Architecture :
 *  - Keypairs RSA générées à l'inscription (privée chiffrée AES-256)
 *  - Ledger chaîné (chaque TX contient le hash de la précédente)
 *  - Moteur d'Escrow pour les commandes
 *  - Portail utilisateur consolidant toutes ses données
 *  - Bus d'événements (oli_bank_events)
 */

const crypto        = require('crypto');
const { v4: uuidv4} = require('uuid');
const pool          = require('../config/db');
const walletRepository = require('../repositories/wallet.repository');

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES
// ─────────────────────────────────────────────────────────────────────────────

const OLI_BANK_SECRET  = process.env.OLI_BANK_SECRET || 'oli_bank_fallback_secret_key_256bit!!';
const AES_ALGORITHM    = 'aes-256-cbc';
const KEY_LENGTH       = 32; // AES-256
const IV_LENGTH        = 16;
const OLI_FEE_RATE     = 0.05; // 5%

// ─────────────────────────────────────────────────────────────────────────────
// CRYPTO HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Dérive une clé AES-256 depuis le secret serveur.
 */
function _deriveAesKey() {
    return crypto.scryptSync(OLI_BANK_SECRET, 'oli_salt_v1', KEY_LENGTH);
}

/**
 * Chiffre un texte en AES-256-CBC.
 * Retourne { encrypted, iv }
 */
function _encryptAES(plaintext) {
    const key = _deriveAesKey();
    const iv  = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(AES_ALGORITHM, key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    return {
        encrypted: encrypted.toString('base64'),
        iv: iv.toString('hex'),
    };
}

/**
 * Déchiffre un texte en AES-256-CBC.
 */
function _decryptAES(encryptedBase64, ivHex) {
    const key = _deriveAesKey();
    const iv  = Buffer.from(ivHex, 'hex');
    const decipher = crypto.createDecipheriv(AES_ALGORITHM, key, iv);
    const decrypted = Buffer.concat([
        decipher.update(Buffer.from(encryptedBase64, 'base64')),
        decipher.final(),
    ]);
    return decrypted.toString('utf8');
}

/**
 * Génère une paire de clés RSA-2048.
 * La clé privée est immédiatement chiffrée avec AES-256.
 */
function _generateKeypair() {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding:  { type: 'spki',  format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    const { encrypted: privateKeyEnc, iv } = _encryptAES(privateKey);
    return { publicKey, privateKeyEnc, keyIv: iv };
}

/**
 * Génère une adresse OLI unique.
 * Format : OLI-XXXX-XXXX-XXXX (16 caractères hex aléatoires)
 */
function _generateOliAddress() {
    const hex = crypto.randomBytes(6).toString('hex').toUpperCase();
    return `OLI-${hex.slice(0,4)}-${hex.slice(4,8)}-${hex.slice(8,12)}`;
}

/**
 * Signe un message avec la clé privée RSA d'un utilisateur.
 */
function _signWithPrivateKey(privateKeyPem, message) {
    const sign = crypto.createSign('SHA256');
    sign.update(message);
    sign.end();
    return sign.sign(privateKeyPem, 'base64');
}

/**
 * Calcule le hash SHA-256 d'une transaction.
 * tx_hash = SHA-256(prevHash|userId|amount|timestamp|nonce)
 */
function _computeTxHash({ prevHash, userId, amount, txType, timestamp, nonce }) {
    const data = `${prevHash || 'GENESIS'}|${userId}|${amount}|${txType}|${timestamp}|${nonce}`;
    return crypto.createHash('sha256').update(data).digest('hex');
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────

class OliBankService {

    // ─────────────────────────────────────────────────────────────
    // 0. Initialisation du portail utilisateur
    // ─────────────────────────────────────────────────────────────

    /**
     * Crée le portail bancaire d'un nouvel utilisateur.
     * Génère sa paire de clés RSA et enregistre son entrée dans le Grand Livre (GENESIS TX).
     * Idempotent — ne fera rien si le portail existe déjà.
     */
    async initializeUserPortal(userId) {
        const existing = await pool.query(
            'SELECT id FROM oli_bank_keypairs WHERE user_id = $1',
            [parseInt(userId)]
        );
        if (existing.rows.length > 0) return { alreadyExists: true };

        const { publicKey, privateKeyEnc, keyIv } = _generateKeypair();
        let   oliAddress;

        // Générer une adresse OLI unique
        let unique = false;
        while (!unique) {
            oliAddress = _generateOliAddress();
            const check = await pool.query(
                'SELECT 1 FROM oli_bank_keypairs WHERE oli_address = $1', [oliAddress]
            );
            unique = check.rows.length === 0;
        }

        // Persister la keypair
        await pool.query(`
            INSERT INTO oli_bank_keypairs (user_id, oli_address, public_key, private_key_enc, key_iv)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (user_id) DO NOTHING
        `, [parseInt(userId), oliAddress, publicKey, privateKeyEnc, keyIv]);

        // Enregistrer la TX GENESIS dans le Grand Livre
        await this._writeLedger({
            userId: parseInt(userId),
            oliAddress,
            txType: 'system_credit',
            amount: 0,
            feeAmount: 0,
            balanceBefore: 0,
            balanceAfter: 0,
            status: 'confirmed',
            metadata: { note: 'GENESIS — Portail OLI Bank initialisé' },
        });

        console.log(`🏦 OLI Bank: Portail initialisé pour user #${userId} → ${oliAddress}`);
        return { oliAddress, publicKey };
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Grand Livre — Écriture
    // ─────────────────────────────────────────────────────────────

    /**
     * Écrit une ligne dans le Grand Livre (oli_bank_ledger).
     * Calcule le hash chaîné et signe avec la clé privée du user.
     */
    async _writeLedger({
        userId, oliAddress, txType, amount, feeAmount = 0,
        balanceBefore, balanceAfter, counterpartId = null,
        orderId = null, escrowRef = null, status = 'confirmed',
        sensitivePayload = null, metadata = {},
    }) {
        // 1. Récupérer la clé privée du user
        const kpRow = await pool.query(
            'SELECT private_key_enc, key_iv FROM oli_bank_keypairs WHERE user_id = $1',
            [parseInt(userId)]
        );
        let signature = 'SYSTEM';
        let privateKeyPem = null;

        if (kpRow.rows.length > 0) {
            try {
                privateKeyPem = _decryptAES(kpRow.rows[0].private_key_enc, kpRow.rows[0].key_iv);
            } catch (e) {
                console.warn(`⚠️ Impossible de déchiffrer la clé privée de user #${userId}`);
            }
        }

        // 2. Récupérer le hash de la dernière TX de cet utilisateur
        const lastTxRow = await pool.query(
            'SELECT tx_hash FROM oli_bank_ledger WHERE user_id = $1 ORDER BY id DESC LIMIT 1',
            [parseInt(userId)]
        );
        const prevHash = lastTxRow.rows[0]?.tx_hash || null;

        // 3. Calculer le hash de cette TX
        const txId      = uuidv4();
        const nonce     = crypto.randomBytes(8).toString('hex');
        const timestamp = Date.now();
        const txHash    = _computeTxHash({ prevHash, userId, amount, txType, timestamp, nonce });

        // 4. Signer le hash
        if (privateKeyPem) {
            try {
                signature = _signWithPrivateKey(privateKeyPem, txHash);
            } catch (e) {
                console.warn('⚠️ Erreur signature RSA:', e.message);
            }
        }

        // 5. Chiffrer les données sensibles si fournies
        let payloadEnc = null;
        if (sensitivePayload) {
            try {
                const { encrypted, iv } = _encryptAES(JSON.stringify(sensitivePayload));
                payloadEnc = JSON.stringify({ data: encrypted, iv });
            } catch (e) {
                console.warn('⚠️ Erreur chiffrement payload:', e.message);
            }
        }

        // 6. Insérer dans le Grand Livre
        const res = await pool.query(`
            INSERT INTO oli_bank_ledger
                (tx_id, tx_hash, prev_tx_hash, user_id, oli_address, tx_type,
                 amount, fee_amount, balance_before, balance_after, counterpart_id,
                 order_id, escrow_ref, signature, payload_enc, status, metadata)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
            RETURNING id, tx_id, tx_hash
        `, [
            txId, txHash, prevHash,
            parseInt(userId), oliAddress, txType,
            amount, feeAmount,
            balanceBefore, balanceAfter,
            counterpartId ? parseInt(counterpartId) : null,
            orderId ? parseInt(orderId) : null,
            escrowRef || null,
            signature,
            payloadEnc,
            status,
            JSON.stringify(metadata),
        ]);

        // 7. Mettre à jour last_used_at de la keypair
        if (kpRow.rows.length > 0) {
            await pool.query(
                'UPDATE oli_bank_keypairs SET last_used_at = NOW() WHERE user_id = $1',
                [parseInt(userId)]
            );
        }

        return res.rows[0];
    }

    // ─────────────────────────────────────────────────────────────
    // 2. Vérification d'une transaction
    // ─────────────────────────────────────────────────────────────

    /**
     * Vérifie l'intégrité cryptographique d'une transaction du Grand Livre.
     * Retourne { valid, details }
     */
    async verifyTransaction(txHashOrId) {
        const res = await pool.query(
            `SELECT l.*, kp.public_key
             FROM oli_bank_ledger l
             LEFT JOIN oli_bank_keypairs kp ON kp.user_id = l.user_id
             WHERE l.tx_hash = $1 OR l.tx_id = $1`,
            [txHashOrId]
        );

        if (!res.rows.length) {
            return { valid: false, reason: 'Transaction introuvable' };
        }

        const tx = res.rows[0];

        // Vérifier la chaîne (prev_hash de la TX suivante pointe vers cette TX)
        const nextTx = await pool.query(
            'SELECT tx_hash FROM oli_bank_ledger WHERE prev_tx_hash = $1',
            [tx.tx_hash]
        );

        // Vérifier la signature RSA (si pas SYSTEM)
        let signatureValid = tx.signature === 'SYSTEM';
        if (!signatureValid && tx.public_key) {
            try {
                const verify = crypto.createVerify('SHA256');
                verify.update(tx.tx_hash);
                signatureValid = verify.verify(tx.public_key, tx.signature, 'base64');
            } catch (e) {
                signatureValid = false;
            }
        }

        return {
            valid: signatureValid,
            txId: tx.tx_id,
            txHash: tx.tx_hash,
            prevTxHash: tx.prev_tx_hash,
            txType: tx.tx_type,
            amount: parseFloat(tx.amount),
            feeAmount: parseFloat(tx.fee_amount),
            balanceBefore: parseFloat(tx.balance_before),
            balanceAfter: parseFloat(tx.balance_after),
            status: tx.status,
            confirmedAt: tx.confirmed_at,
            signatureValid,
            chainLinked: nextTx.rows.length > 0,
        };
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Flux Financiers — Wrapper unifié
    // ─────────────────────────────────────────────────────────────

    /**
     * Enregistre un dépôt dans le Grand Livre + crédite le wallet.
     * Appeler APRÈS confirmation Unipesa (webhook C2B).
     */
    async processDeposit(userId, netAmount, sensitiveData = null) {
        const uid = parseInt(userId);
        const feeAmount = netAmount * (OLI_FEE_RATE / (1 - OLI_FEE_RATE)); // frais déjà collectés

        // Récupérer solde avant
        const balanceBefore = await walletRepository.getBalance(uid);
        const balanceAfter  = balanceBefore + netAmount;

        // Créditer le wallet
        const wResult = await walletRepository.performDeposit(uid, netAmount, {
            type: 'deposit',
            provider: 'UNIPESA',
            description: `Recharge confirmée via Banque OLI`,
        });

        // Adresse OLI
        const oliAddress = await this._getOliAddress(uid);

        // Écrire dans le Grand Livre
        const ledgerTx = await this._writeLedger({
            userId: uid, oliAddress, txType: 'deposit',
            amount: netAmount, feeAmount,
            balanceBefore, balanceAfter,
            sensitivePayload: sensitiveData,
            metadata: { wallet_tx_id: wResult.transactionId },
        });

        // Lier le wallet_transaction au ledger
        if (wResult.transactionId) {
            await pool.query(
                'UPDATE wallet_transactions SET ledger_tx_id = $1 WHERE id = $2',
                [ledgerTx.tx_id, wResult.transactionId]
            );
        }

        return { ...wResult, ledgerTxId: ledgerTx.tx_id, txHash: ledgerTx.tx_hash };
    }

    /**
     * Enregistre un retrait dans le Grand Livre.
     * Appelé APRÈS confirmation Unipesa B2C.
     */
    async processWithdrawal(userId, netAmount, sensitiveData = null) {
        const uid = parseInt(userId);
        const feeAmount = netAmount * OLI_FEE_RATE;

        const balanceBefore = await walletRepository.getBalance(uid);
        const balanceAfter  = balanceBefore; // débit déjà effectué par wallet.service.js

        const oliAddress = await this._getOliAddress(uid);

        const ledgerTx = await this._writeLedger({
            userId: uid, oliAddress, txType: 'withdrawal',
            amount: -(netAmount + feeAmount), feeAmount,
            balanceBefore: balanceBefore + netAmount + feeAmount,
            balanceAfter,
            sensitivePayload: sensitiveData,
        });

        // Enregistrer 5% de frais pour la Banque OLI
        await this._creditSystemWalletLedger(feeAmount, `WD_FEE_${ledgerTx.tx_id}`);

        return { ledgerTxId: ledgerTx.tx_id, txHash: ledgerTx.tx_hash };
    }

    /**
     * Transfert P2P enregistré dans le Grand Livre (double entrée).
     */
    async processP2P(senderId, receiverId, amount) {
        const sId = parseInt(senderId);
        const rId = parseInt(receiverId);

        const senderBalance  = await walletRepository.getBalance(sId);
        const receiverBalance = await walletRepository.getBalance(rId);

        const senderOli   = await this._getOliAddress(sId);
        const receiverOli = await this._getOliAddress(rId);

        // TX DÉBIT (expéditeur)
        const sendTx = await this._writeLedger({
            userId: sId, oliAddress: senderOli, txType: 'p2p_send',
            amount: -amount, feeAmount: 0,
            balanceBefore: senderBalance + amount,
            balanceAfter: senderBalance,
            counterpartId: rId,
        });

        // TX CRÉDIT (destinataire)
        const recvTx = await this._writeLedger({
            userId: rId, oliAddress: receiverOli, txType: 'p2p_receive',
            amount,  feeAmount: 0,
            balanceBefore: receiverBalance - amount,
            balanceAfter: receiverBalance,
            counterpartId: sId,
        });

        return { sendTxId: sendTx.tx_id, recvTxId: recvTx.tx_id };
    }

    // ─────────────────────────────────────────────────────────────
    // 4. Escrow Engine — Séquestre des fonds de commande
    // ─────────────────────────────────────────────────────────────

    /**
     * Crée un séquestre pour une commande.
     * Les fonds de l'acheteur sont déjà dans son Wallet OLI.
     * On les marque comme "bloqués" dans le Grand Livre.
     *
     * @param {Object} params
     *   buyerId, sellerId, delivererId, orderId,
     *   totalAmount, sellerAmount, delivererAmount, oliFee
     */
    async createEscrow({ buyerId, sellerId, delivererId, orderId, totalAmount, sellerAmount, delivererAmount = 0, oliFee = 0 }) {
        const uid = parseInt(buyerId);
        const escrowRef = `ESC-${orderId}-${Date.now()}`;

        const balanceBefore = await walletRepository.getBalance(uid);

        // Écrire la TX d'escrow dans le Grand Livre
        const oliAddress = await this._getOliAddress(uid);
        const lockTx = await this._writeLedger({
            userId: uid, oliAddress, txType: 'escrow_lock',
            amount: -totalAmount, feeAmount: oliFee,
            balanceBefore,
            balanceAfter: balanceBefore - totalAmount,
            counterpartId: parseInt(sellerId),
            orderId: parseInt(orderId),
            escrowRef,
            metadata: { escrow_ref: escrowRef, seller_id: sellerId, deliverer_id: delivererId },
        });

        // Créer l'enregistrement d'escrow
        await pool.query(`
            INSERT INTO oli_bank_escrow
                (escrow_ref, order_id, buyer_id, seller_id, deliverer_id,
                 amount_locked, seller_amount, deliverer_amount, oli_fee,
                 status, ledger_lock_id)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'locked',$10)
            ON CONFLICT (order_id) DO NOTHING
        `, [
            escrowRef,
            parseInt(orderId),
            uid,
            parseInt(sellerId),
            delivererId ? parseInt(delivererId) : null,
            totalAmount, sellerAmount, delivererAmount, oliFee,
            lockTx.id,
        ]);

        console.log(`🔒 Escrow créé: ${escrowRef} — $${totalAmount} bloqués (commande #${orderId})`);
        return { escrowRef, lockTxId: lockTx.tx_id };
    }

    /**
     * Libère l'escrow : crédite vendeur + livreur.
     */
    async releaseEscrow(orderId, trigger = 'delivery_confirmed') {
        const escrow = await this._getEscrow(parseInt(orderId));
        if (!escrow) throw new Error(`Escrow introuvable pour commande #${orderId}`);
        if (escrow.status !== 'locked') throw new Error(`Escrow déjà ${escrow.status}`);

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            const sellerBalance = await walletRepository.getBalance(escrow.seller_id);
            const sellerOli     = await this._getOliAddress(escrow.seller_id);

            // Créditer le vendeur
            await walletRepository.performDeposit(escrow.seller_id, parseFloat(escrow.seller_amount), {
                type: 'escrow_release',
                provider: 'OLI_BANK',
                reference: `${escrow.escrow_ref}_SELLER`,
                description: `Paiement vendeur — commande #${orderId}`,
                orderId: parseInt(orderId),
            });

            const sellerReleaseTx = await this._writeLedger({
                userId: escrow.seller_id, oliAddress: sellerOli,
                txType: 'escrow_release', amount: parseFloat(escrow.seller_amount), feeAmount: 0,
                balanceBefore: sellerBalance,
                balanceAfter: sellerBalance + parseFloat(escrow.seller_amount),
                counterpartId: escrow.buyer_id,
                orderId: parseInt(orderId), escrowRef: escrow.escrow_ref,
            });

            // Créditer le livreur si applicable
            if (escrow.deliverer_id && parseFloat(escrow.deliverer_amount) > 0) {
                const delivBalance = await walletRepository.getBalance(escrow.deliverer_id);
                const delivOli     = await this._getOliAddress(escrow.deliverer_id);

                await walletRepository.performDeposit(escrow.deliverer_id, parseFloat(escrow.deliverer_amount), {
                    type: 'escrow_release',
                    provider: 'OLI_BANK',
                    reference: `${escrow.escrow_ref}_DELIVERER`,
                    description: `Commission livreur — commande #${orderId}`,
                    orderId: parseInt(orderId),
                });

                await this._writeLedger({
                    userId: escrow.deliverer_id, oliAddress: delivOli,
                    txType: 'escrow_release', amount: parseFloat(escrow.deliverer_amount), feeAmount: 0,
                    balanceBefore: delivBalance,
                    balanceAfter: delivBalance + parseFloat(escrow.deliverer_amount),
                    counterpartId: escrow.buyer_id,
                    orderId: parseInt(orderId), escrowRef: escrow.escrow_ref,
                });
            }

            // Créditer les frais OLI vers la banque système
            if (parseFloat(escrow.oli_fee) > 0) {
                await this._creditSystemWalletLedger(parseFloat(escrow.oli_fee), `${escrow.escrow_ref}_FEE`);
            }

            // Marquer l'escrow comme libéré
            await client.query(`
                UPDATE oli_bank_escrow
                SET status = 'released', released_at = NOW(),
                    release_trigger = $1, ledger_release_id = $2
                WHERE escrow_ref = $3
            `, [trigger, sellerReleaseTx.id, escrow.escrow_ref]);

            await client.query('COMMIT');
            console.log(`✅ Escrow libéré: ${escrow.escrow_ref} — Vendeur crédité $${escrow.seller_amount}`);
            return { success: true, escrowRef: escrow.escrow_ref };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * Rembourse l'escrow à l'acheteur.
     */
    async refundEscrow(orderId, reason = 'order_cancelled') {
        const escrow = await this._getEscrow(parseInt(orderId));
        if (!escrow) throw new Error(`Escrow introuvable pour commande #${orderId}`);
        if (escrow.status !== 'locked') throw new Error(`Escrow déjà ${escrow.status}`);

        const buyerBalance = await walletRepository.getBalance(escrow.buyer_id);
        const buyerOli     = await this._getOliAddress(escrow.buyer_id);
        const refundAmount = parseFloat(escrow.amount_locked);

        await walletRepository.performDeposit(escrow.buyer_id, refundAmount, {
            type: 'escrow_refund',
            provider: 'OLI_BANK',
            reference: `${escrow.escrow_ref}_REFUND`,
            description: `Remboursement escrow — commande #${orderId} (${reason})`,
            orderId: parseInt(orderId),
        });

        const refundTx = await this._writeLedger({
            userId: escrow.buyer_id, oliAddress: buyerOli,
            txType: 'escrow_refund', amount: refundAmount, feeAmount: 0,
            balanceBefore: buyerBalance,
            balanceAfter: buyerBalance + refundAmount,
            orderId: parseInt(orderId), escrowRef: escrow.escrow_ref,
            metadata: { reason },
        });

        await pool.query(`
            UPDATE oli_bank_escrow
            SET status = 'refunded', refunded_at = NOW(), ledger_release_id = $1
            WHERE escrow_ref = $2
        `, [refundTx.id, escrow.escrow_ref]);

        console.log(`↩️ Escrow remboursé: ${escrow.escrow_ref} — Acheteur remboursé $${refundAmount}`);
        return { success: true, refundTxId: refundTx.tx_id };
    }

    // ─────────────────────────────────────────────────────────────
    // 5. Portail Utilisateur
    // ─────────────────────────────────────────────────────────────

    /**
     * Retourne le portail complet d'un utilisateur.
     * Consolidation de toutes ses données financières et comportementales.
     */
    async getUserPortal(userId) {
        const uid = parseInt(userId);

        // Vue matérialisée
        const portalRes = await pool.query(
            'SELECT * FROM oli_bank_user_portal WHERE user_id = $1',
            [uid]
        );
        const portal = portalRes.rows[0] || {};

        // Dernières transactions du Grand Livre
        const ledgerRes = await pool.query(`
            SELECT tx_id, tx_hash, tx_type, amount, fee_amount,
                   balance_before, balance_after, status, confirmed_at, metadata
            FROM oli_bank_ledger
            WHERE user_id = $1
            ORDER BY id DESC
            LIMIT 20
        `, [uid]);

        // Escrows actifs
        const escrowRes = await pool.query(`
            SELECT escrow_ref, order_id, amount_locked, seller_amount,
                   deliverer_amount, oli_fee, status, locked_at
            FROM oli_bank_escrow
            WHERE (buyer_id = $1 OR seller_id = $1 OR deliverer_id = $1)
              AND status = 'locked'
            ORDER BY locked_at DESC
        `, [uid]);

        // Sessions récentes (5 dernières)
        const sessionsRes = await pool.query(`
            SELECT id, device_type, device_model, ip_address, city, country,
                   started_at, last_seen_at, duration_seconds, action_count,
                   financial_actions, is_suspicious
            FROM user_sessions_ext
            WHERE user_id = $1
            ORDER BY started_at DESC
            LIMIT 5
        `, [uid]);

        return {
            ...portal,
            wallet_balance: parseFloat(portal.wallet_balance) || 0,
            total_deposited: parseFloat(portal.total_deposited) || 0,
            total_withdrawn: parseFloat(portal.total_withdrawn) || 0,
            funds_in_escrow: parseFloat(portal.funds_in_escrow) || 0,
            ledger: ledgerRes.rows.map(tx => ({
                ...tx,
                amount: parseFloat(tx.amount),
                fee_amount: parseFloat(tx.fee_amount),
            })),
            active_escrows_detail: escrowRes.rows,
            recent_sessions: sessionsRes.rows,
        };
    }

    /**
     * Retourne l'historique complet du Grand Livre d'un utilisateur.
     */
    async getLedger(userId, limit = 50, offset = 0) {
        const uid = parseInt(userId);
        const res = await pool.query(`
            SELECT l.tx_id, l.tx_hash, l.prev_tx_hash, l.tx_type,
                   l.amount, l.fee_amount, l.balance_before, l.balance_after,
                   l.status, l.confirmed_at, l.signature, l.metadata,
                   u2.name AS counterpart_name
            FROM   oli_bank_ledger l
            LEFT JOIN users u2 ON u2.id = l.counterpart_id
            WHERE  l.user_id = $1
            ORDER BY l.id DESC
            LIMIT $2 OFFSET $3
        `, [uid, limit, offset]);

        return res.rows.map(tx => ({
            ...tx,
            amount: parseFloat(tx.amount),
            fee_amount: parseFloat(tx.fee_amount),
        }));
    }

    // ─────────────────────────────────────────────────────────────
    // 6. Sessions Utilisateur
    // ─────────────────────────────────────────────────────────────

    async trackSession(userId, sessionData) {
        const uid = parseInt(userId);
        const oliAddress = await this._getOliAddress(uid);

        const res = await pool.query(`
            INSERT INTO user_sessions_ext
                (user_id, session_token, device_id, device_type, device_model,
                 platform, app_version, ip_address, city, country, oli_address)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
            ON CONFLICT (session_token) DO UPDATE
                SET last_seen_at = NOW(),
                    action_count = user_sessions_ext.action_count + 1
            RETURNING id
        `, [
            uid,
            sessionData.sessionToken,
            sessionData.deviceId || null,
            sessionData.deviceType || 'unknown',
            sessionData.deviceModel || null,
            sessionData.platform || null,
            sessionData.appVersion || null,
            sessionData.ipAddress || null,
            sessionData.city || null,
            sessionData.country || null,
            oliAddress,
        ]);
        return res.rows[0];
    }

    async endSession(sessionToken) {
        await pool.query(
            'UPDATE user_sessions_ext SET ended_at = NOW() WHERE session_token = $1',
            [sessionToken]
        );
    }

    async incrementSessionAction(sessionToken, isFinancial = false) {
        await pool.query(`
            UPDATE user_sessions_ext
            SET action_count = action_count + 1,
                financial_actions = financial_actions + $1,
                last_seen_at = NOW()
            WHERE session_token = $2
        `, [isFinancial ? 1 : 0, sessionToken]);
    }

    // ─────────────────────────────────────────────────────────────
    // 7. Décryptage de données sensibles (pour admin sécurisé)
    // ─────────────────────────────────────────────────────────────

    /**
     * Décrypte le payload sensible d'une transaction (accès admin uniquement).
     */
    decryptTxPayload(payloadEncJson) {
        if (!payloadEncJson) return null;
        try {
            const { data, iv } = JSON.parse(payloadEncJson);
            return JSON.parse(_decryptAES(data, iv));
        } catch (e) {
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers privés
    // ─────────────────────────────────────────────────────────────

    async _getOliAddress(userId) {
        const res = await pool.query(
            'SELECT oli_address FROM oli_bank_keypairs WHERE user_id = $1',
            [parseInt(userId)]
        );
        return res.rows[0]?.oli_address || 'OLI-UNKNOWN';
    }

    async _getEscrow(orderId) {
        const res = await pool.query(
            'SELECT * FROM oli_bank_escrow WHERE order_id = $1',
            [parseInt(orderId)]
        );
        return res.rows[0] || null;
    }

    async _creditSystemWalletLedger(amount, reference) {
        if (amount <= 0) return;

        const SYSTEM_USER_ID = 0;
        const systemOli = await this._getOliAddress(SYSTEM_USER_ID);

        const sysBalance = await pool.query('SELECT balance FROM wallets WHERE user_id = 0');
        const balBefore = parseFloat(sysBalance.rows[0]?.balance || 0);
        const balAfter  = balBefore + amount;

        await pool.query('UPDATE wallets SET balance = $1 WHERE user_id = 0', [balAfter]);
        await pool.query('UPDATE users SET wallet = $1 WHERE id = 0', [balAfter]);

        await this._writeLedger({
            userId: SYSTEM_USER_ID, oliAddress: systemOli,
            txType: 'fee', amount, feeAmount: 0,
            balanceBefore: balBefore, balanceAfter: balAfter,
            metadata: { reference },
        });
    }
}

module.exports = new OliBankService();
