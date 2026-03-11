-- =====================================================
-- Migration 038: Système Wallet OLI — Version Robuste
-- Date: 2026-03-11
-- Purpose: Créer une table wallets dédiée, corriger les
--          contraintes du système de paiement
-- =====================================================

-- 1. Table wallets dédiée (une par user)
CREATE TABLE IF NOT EXISTS wallets (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL UNIQUE,
    balance     DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    currency    VARCHAR(5) NOT NULL DEFAULT 'USD',
    is_frozen   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);

-- 2. Créer un wallet pour chaque utilisateur existant
--    (migre le solde depuis users.wallet si > 0)
INSERT INTO wallets (user_id, balance)
SELECT  id,
        GREATEST(COALESCE(wallet::DECIMAL(12,2), 0.00), 0.00)
FROM    users
ON CONFLICT (user_id) DO UPDATE
    SET balance    = GREATEST(EXCLUDED.balance, 0.00),
        updated_at = NOW();

-- 3. Corriger la table wallet_transactions
--    Ajouter wallet_id si pas encore présent
ALTER TABLE wallet_transactions
    ADD COLUMN IF NOT EXISTS wallet_id INTEGER REFERENCES wallets(id),
    ADD COLUMN IF NOT EXISTS order_id  INTEGER REFERENCES orders(id) ON DELETE SET NULL;

-- Corriger le CHECK sur type pour inclure 'credit', 'reward'
-- PostgreSQL ne permet pas de modifier un CHECK existant → DROP + RECREATE
DO $$
BEGIN
    -- Supprimer l'ancienne contrainte si elle existe
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'wallet_transactions_type_check'
          AND table_name = 'wallet_transactions'
    ) THEN
        ALTER TABLE wallet_transactions DROP CONSTRAINT wallet_transactions_type_check;
    END IF;
END $$;

ALTER TABLE wallet_transactions
    ADD CONSTRAINT wallet_transactions_type_check
    CHECK (type IN ('deposit', 'withdrawal', 'payment', 'refund', 'reward', 'transfer', 'credit'));

-- 4. Corriger les CHECK sur orders
--    payment_status : doit accepter pending / completed / failed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'orders_payment_status_check'
          AND table_name = 'orders'
    ) THEN
        ALTER TABLE orders DROP CONSTRAINT orders_payment_status_check;
    END IF;
END $$;

ALTER TABLE orders
    ADD CONSTRAINT orders_payment_status_check
    CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded'));

-- 5. Index sur wallet_transactions pour l'historique
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet  ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_order   ON wallet_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_created ON wallet_transactions(created_at DESC);

-- 6. Trigger pour mettre à jour wallets.updated_at automatiquement
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

-- 7. Fonction helper pour auto-créer un wallet à la création d'un user
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO wallets (user_id, balance)
    VALUES (NEW.id, 0.00)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_create_wallet_on_signup ON users;
CREATE TRIGGER trg_create_wallet_on_signup
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- Vérification
DO $$
DECLARE
    wallet_count INTEGER;
    user_count   INTEGER;
BEGIN
    SELECT COUNT(*) INTO wallet_count FROM wallets;
    SELECT COUNT(*) INTO user_count   FROM users;
    RAISE NOTICE '✅ Migration 038 terminée: % wallets créés pour % utilisateurs', wallet_count, user_count;
END $$;
