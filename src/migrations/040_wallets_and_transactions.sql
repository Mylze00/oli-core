-- ======================================================================
-- Migration 040 : Wallets & Transactions
-- Date: 2026-05-26
-- Objet:
--   1. wallets               — Portefeuilles utilisateur (solde en FC)
--   2. wallet_transactions   — Historique de toutes les opérations
--   3. unipesa_operations    — Suivi des opérations Unipesa (C2B/B2C)
-- ======================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1. TABLE WALLETS — Portefeuille principal de chaque utilisateur
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallets (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    balance     DECIMAL(18,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    currency    VARCHAR(10)  NOT NULL DEFAULT 'FC',
    is_frozen   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id);

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_wallet_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_wallet_updated_at ON wallets;
CREATE TRIGGER trg_wallet_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW EXECUTE FUNCTION update_wallet_timestamp();

-- ─────────────────────────────────────────────────────────────────────
-- 2. TABLE WALLET_TRANSACTIONS — Historique complet des opérations
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id              BIGSERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            VARCHAR(32) NOT NULL,
    amount          DECIMAL(18,2) NOT NULL,
    balance_before  DECIMAL(18,2) NOT NULL DEFAULT 0,
    balance_after   DECIMAL(18,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(10)  NOT NULL DEFAULT 'FC',
    provider        VARCHAR(64),                     -- UNIPESA, OLI_BANK, etc.
    reference       VARCHAR(128),                    -- order_id Unipesa ou ref interne
    description     TEXT,
    order_id        INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'completed',
    ledger_tx_id    VARCHAR(64),                     -- Lien vers oli_bank_ledger
    metadata        JSONB DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_wt_type CHECK (type IN (
        'deposit', 'deposit_pending', 'withdrawal', 'withdrawal_pending',
        'payment', 'refund', 'reward', 'transfer', 'credit', 'system_credit',
        'escrow_lock', 'escrow_release', 'escrow_refund', 'fee'
    )),
    CONSTRAINT chk_wt_status CHECK (status IN (
        'pending', 'completed', 'failed', 'cancelled', 'reversed'
    ))
);

CREATE INDEX IF NOT EXISTS idx_wt_user       ON wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_reference  ON wallet_transactions(reference);
CREATE INDEX IF NOT EXISTS idx_wt_status     ON wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wt_type       ON wallet_transactions(type);

-- ─────────────────────────────────────────────────────────────────────
-- 3. TABLE UNIPESA_OPERATIONS — Suivi des opérations avec l'agrégateur
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS unipesa_operations (
    id              BIGSERIAL PRIMARY KEY,
    oli_order_id    VARCHAR(128) NOT NULL UNIQUE, -- ID interne OLI (ex: DEP-1748259-1234)
    unipesa_order_id VARCHAR(128),                -- order_id retourné par Unipesa
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone           VARCHAR(32) NOT NULL,         -- Numéro Mobile Money de l'utilisateur
    amount_fc       DECIMAL(18,2) NOT NULL,       -- Montant en FC demandé
    amount_usd      DECIMAL(18,4),                -- Équivalent USD (pour le ledger)
    provider        VARCHAR(64),                  -- Orange, Airtel, Vodacom, etc.
    operation_type  VARCHAR(16) NOT NULL DEFAULT 'deposit', -- deposit | withdrawal
    status          VARCHAR(16) NOT NULL DEFAULT 'pending', -- pending | success | failed | cancelled | timeout
    wallet_tx_id    BIGINT REFERENCES wallet_transactions(id) ON DELETE SET NULL,
    webhook_payload JSONB,                        -- Payload brut reçu d'Unipesa
    error_message   TEXT,
    initiated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),

    CONSTRAINT chk_uniop_status CHECK (status IN (
        'pending', 'success', 'failed', 'cancelled', 'timeout'
    )),
    CONSTRAINT chk_uniop_type CHECK (operation_type IN ('deposit', 'withdrawal'))
);

CREATE INDEX IF NOT EXISTS idx_uniop_user     ON unipesa_operations(user_id, initiated_at DESC);
CREATE INDEX IF NOT EXISTS idx_uniop_status   ON unipesa_operations(status);
CREATE INDEX IF NOT EXISTS idx_uniop_expires  ON unipesa_operations(expires_at) WHERE status = 'pending';

-- ─────────────────────────────────────────────────────────────────────
-- 4. Initialiser le wallet pour chaque utilisateur existant
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO wallets (user_id, balance, currency)
SELECT id, COALESCE(wallet, 0), 'FC'
FROM   users
WHERE  id NOT IN (SELECT user_id FROM wallets)
ON CONFLICT (user_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 5. Vérification finale
-- ─────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 040 terminée: Wallets & Transactions';
    RAISE NOTICE '   Tables créées: wallets, wallet_transactions, unipesa_operations';
END $$;
