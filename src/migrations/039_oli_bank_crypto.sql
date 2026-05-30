-- ======================================================================
-- Migration 039 : OLI Bank — Portail Cryptographique Utilisateur
-- Date: 2026-05-24
-- Objet:
--   1. oli_bank_keypairs    — Paires de clés RSA/AES par utilisateur
--   2. oli_bank_ledger      — Grand Livre signé + chaîné (hash SHA-256)
--   3. oli_bank_escrow      — Fonds séquestres (commandes)
--   4. user_sessions_ext    — Sessions enrichies (device, IP, durée)
--   5. oli_bank_events      — Bus d'événements financiers (audit)
--   6. Vues & Triggers      — Automatisation et cohérence
-- ======================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1. OLI BANK KEYPAIRS — Identité cryptographique par utilisateur
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS oli_bank_keypairs (
    id                SERIAL PRIMARY KEY,
    user_id           INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    oli_address       VARCHAR(64) NOT NULL UNIQUE,     -- ex: OLI-XXXX-XXXX-XXXX (adresse publique)
    public_key        TEXT NOT NULL,                   -- Clé publique RSA (PEM)
    private_key_enc   TEXT NOT NULL,                   -- Clé privée RSA chiffrée AES-256
    key_iv            VARCHAR(64) NOT NULL,            -- IV d'initialisation AES
    key_version       INTEGER NOT NULL DEFAULT 1,      -- Permet rotation des clés
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at      TIMESTAMPTZ,
    metadata          JSONB DEFAULT '{}'::JSONB
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_keypairs_address ON oli_bank_keypairs(oli_address);
CREATE INDEX IF NOT EXISTS idx_keypairs_user ON oli_bank_keypairs(user_id);

-- ─────────────────────────────────────────────────────────────────────
-- 2. OLI BANK LEDGER — Grand Livre cryptographiquement chaîné
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS oli_bank_ledger (
    id              BIGSERIAL PRIMARY KEY,
    tx_id           VARCHAR(64) NOT NULL UNIQUE,       -- UUID de la transaction
    tx_hash         VARCHAR(128) NOT NULL UNIQUE,      -- SHA-256(prev_hash|user_id|amount|timestamp|nonce)
    prev_tx_hash    VARCHAR(128),                      -- Hash de la TX précédente (chaîne)
    user_id         INTEGER NOT NULL REFERENCES users(id),
    oli_address     VARCHAR(64) NOT NULL,              -- Adresse OLI de l'émetteur/récepteur
    tx_type         VARCHAR(32) NOT NULL,              -- deposit | withdrawal | payment | p2p | escrow | fee | refund | reward
    amount          DECIMAL(18,8) NOT NULL,            -- Montant en USD (précision crypto)
    fee_amount      DECIMAL(18,8) NOT NULL DEFAULT 0,  -- Frais OLI prélevés
    balance_before  DECIMAL(18,8) NOT NULL,
    balance_after   DECIMAL(18,8) NOT NULL,
    counterpart_id  INTEGER REFERENCES users(id),      -- Autre partie (vendeur, destinataire P2P…)
    order_id        INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    escrow_id       INTEGER,                           -- FK ajoutée après création escrow
    signature       TEXT NOT NULL,                     -- Signature RSA du tx_hash (clé privée user)
    payload_enc     TEXT,                              -- Données sensibles chiffrées AES (détails provider, numéro…)
    status          VARCHAR(16) NOT NULL DEFAULT 'confirmed', -- confirmed | pending | failed | reversed
    confirmed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata        JSONB DEFAULT '{}'::JSONB,

    CONSTRAINT chk_ledger_type CHECK (
        tx_type IN ('deposit','withdrawal','payment','p2p_send','p2p_receive','escrow_lock',
                    'escrow_release','escrow_refund','fee','refund','reward','system_credit')
    ),
    CONSTRAINT chk_ledger_status CHECK (status IN ('confirmed','pending','failed','reversed'))
);

CREATE INDEX IF NOT EXISTS idx_ledger_user     ON oli_bank_ledger(user_id, confirmed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_address  ON oli_bank_ledger(oli_address);
CREATE INDEX IF NOT EXISTS idx_ledger_order    ON oli_bank_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_ledger_status   ON oli_bank_ledger(status);
CREATE INDEX IF NOT EXISTS idx_ledger_type     ON oli_bank_ledger(tx_type);

-- ─────────────────────────────────────────────────────────────────────
-- 3. OLI BANK ESCROW — Fonds séquestres (commandes)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS oli_bank_escrow (
    id              SERIAL PRIMARY KEY,
    escrow_ref      VARCHAR(64) NOT NULL UNIQUE,       -- ex: ESC-orderId-timestamp
    order_id        INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    buyer_id        INTEGER NOT NULL REFERENCES users(id),
    seller_id       INTEGER NOT NULL REFERENCES users(id),
    deliverer_id    INTEGER REFERENCES users(id),
    amount_locked   DECIMAL(18,8) NOT NULL,            -- Montant total bloqué (inclut frais OLI)
    seller_amount   DECIMAL(18,8) NOT NULL,            -- Part revenant au vendeur
    deliverer_amount DECIMAL(18,8) NOT NULL DEFAULT 0, -- Part revenant au livreur
    oli_fee         DECIMAL(18,8) NOT NULL DEFAULT 0,  -- Commission OLI
    status          VARCHAR(16) NOT NULL DEFAULT 'locked',
    locked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at     TIMESTAMPTZ,
    refunded_at     TIMESTAMPTZ,
    release_trigger VARCHAR(32),                       -- 'delivery_confirmed' | 'pickup_confirmed' | 'admin_override'
    ledger_lock_id  BIGINT REFERENCES oli_bank_ledger(id),   -- TX de blocage
    ledger_release_id BIGINT REFERENCES oli_bank_ledger(id), -- TX de libération
    metadata        JSONB DEFAULT '{}'::JSONB,

    CONSTRAINT chk_escrow_status CHECK (status IN ('locked','released','refunded','disputed'))
);

CREATE INDEX IF NOT EXISTS idx_escrow_order    ON oli_bank_escrow(order_id);
CREATE INDEX IF NOT EXISTS idx_escrow_buyer    ON oli_bank_escrow(buyer_id);
CREATE INDEX IF NOT EXISTS idx_escrow_seller   ON oli_bank_escrow(seller_id);
CREATE INDEX IF NOT EXISTS idx_escrow_status   ON oli_bank_escrow(status);

-- Ajouter FK ledger → escrow (maintenant que la table existe)
ALTER TABLE oli_bank_ledger
    ADD COLUMN IF NOT EXISTS escrow_ref VARCHAR(64) REFERENCES oli_bank_escrow(escrow_ref) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────────────
-- 4. USER SESSIONS EXT — Sessions enrichies (gouvernance utilisateur)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_sessions_ext (
    id              BIGSERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token   VARCHAR(128) NOT NULL UNIQUE,      -- Jeton de session JWT (hash uniquement)
    device_id       VARCHAR(128),                      -- ID unique du device
    device_type     VARCHAR(32),                       -- android | ios | web
    device_model    VARCHAR(64),
    platform        VARCHAR(16),
    app_version     VARCHAR(16),
    ip_address      INET,
    city            VARCHAR(64),
    country         VARCHAR(64),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (COALESCE(ended_at, last_seen_at) - started_at))::INTEGER
    ) STORED,
    action_count    INTEGER NOT NULL DEFAULT 0,
    financial_actions INTEGER NOT NULL DEFAULT 0,      -- Nb d'actions financières dans la session
    risk_flags      JSONB DEFAULT '[]'::JSONB,         -- Flags de risque détectés
    is_suspicious   BOOLEAN NOT NULL DEFAULT FALSE,
    oli_address     VARCHAR(64)                        -- Lien vers l'identité OLI
);

CREATE INDEX IF NOT EXISTS idx_sessions_user     ON user_sessions_ext(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_device   ON user_sessions_ext(device_id);
CREATE INDEX IF NOT EXISTS idx_sessions_ip       ON user_sessions_ext(ip_address);
CREATE INDEX IF NOT EXISTS idx_sessions_suspect  ON user_sessions_ext(is_suspicious) WHERE is_suspicious = TRUE;

-- ─────────────────────────────────────────────────────────────────────
-- 5. OLI BANK EVENTS — Bus d'audit de tous les événements financiers
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS oli_bank_events (
    id              BIGSERIAL PRIMARY KEY,
    event_id        VARCHAR(64) NOT NULL UNIQUE,
    event_type      VARCHAR(64) NOT NULL,              -- wallet.deposit | escrow.created | user.kyc…
    source          VARCHAR(32) NOT NULL DEFAULT 'system', -- system | user | webhook | admin
    user_id         INTEGER REFERENCES users(id),
    ledger_tx_id    VARCHAR(64) REFERENCES oli_bank_ledger(tx_id) ON DELETE SET NULL,
    escrow_ref      VARCHAR(64) REFERENCES oli_bank_escrow(escrow_ref) ON DELETE SET NULL,
    session_id      BIGINT REFERENCES user_sessions_ext(id),
    payload         JSONB NOT NULL DEFAULT '{}'::JSONB, -- Données de l'événement
    severity        VARCHAR(10) NOT NULL DEFAULT 'info', -- info | warning | critical
    processed       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_user     ON oli_bank_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_type     ON oli_bank_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_severity ON oli_bank_events(severity) WHERE severity != 'info';
CREATE INDEX IF NOT EXISTS idx_events_unprocessed ON oli_bank_events(processed) WHERE processed = FALSE;

-- ─────────────────────────────────────────────────────────────────────
-- 6. OLI BANK USER PORTAL — Vue consolidée (lecture rapide)
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW oli_bank_user_portal AS
SELECT
    u.id                                AS user_id,
    u.name,
    u.phone,
    NULL AS email,
    u.account_type AS role,
    u.is_verified,
    u.id_oli                            AS oli_id,
    kp.oli_address,
    kp.is_active                        AS bank_active,
    kp.created_at                       AS bank_joined_at,
    w.balance                           AS wallet_balance,
    w.currency,
    w.is_frozen,
    ts.overall_score                    AS trust_score,
    ts.fraud_risk_level,
    -- Statistiques du ledger
    (SELECT COUNT(*) FROM oli_bank_ledger ol WHERE ol.user_id = u.id)
                                        AS total_transactions,
    (SELECT COALESCE(SUM(ol.amount), 0) FROM oli_bank_ledger ol
     WHERE ol.user_id = u.id AND ol.tx_type = 'deposit')
                                        AS total_deposited,
    (SELECT COALESCE(SUM(ABS(ol.amount)), 0) FROM oli_bank_ledger ol
     WHERE ol.user_id = u.id AND ol.tx_type = 'withdrawal')
                                        AS total_withdrawn,
    -- Escrows actifs
    (SELECT COUNT(*) FROM oli_bank_escrow e
     WHERE (e.buyer_id = u.id OR e.seller_id = u.id) AND e.status = 'locked')
                                        AS active_escrows,
    (SELECT COALESCE(SUM(e.amount_locked), 0) FROM oli_bank_escrow e
     WHERE e.buyer_id = u.id AND e.status = 'locked')
                                        AS funds_in_escrow,
    -- Dernière session
    (SELECT s.started_at FROM user_sessions_ext s WHERE s.user_id = u.id
     ORDER BY s.started_at DESC LIMIT 1)
                                        AS last_session_at,
    (SELECT s.device_type FROM user_sessions_ext s WHERE s.user_id = u.id
     ORDER BY s.started_at DESC LIMIT 1)
                                        AS last_device,
    (SELECT COALESCE(SUM(s.duration_seconds), 0) FROM user_sessions_ext s
     WHERE s.user_id = u.id)           AS total_usage_seconds
FROM  users u
LEFT JOIN wallets w                 ON w.user_id = u.id
LEFT JOIN oli_bank_keypairs kp      ON kp.user_id = u.id
LEFT JOIN user_trust_scores ts           ON ts.user_id = u.id;

-- ─────────────────────────────────────────────────────────────────────
-- 7. Triggers d'automatisation
-- ─────────────────────────────────────────────────────────────────────

-- Trigger : Émission d'un événement à chaque transaction du ledger
CREATE OR REPLACE FUNCTION oli_ledger_emit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO oli_bank_events (event_id, event_type, source, user_id, ledger_tx_id, payload)
    VALUES (
        'EVT-' || NEW.tx_id,
        'ledger.' || NEW.tx_type,
        'system',
        NEW.user_id,
        NEW.tx_id,
        jsonb_build_object(
            'amount', NEW.amount,
            'fee', NEW.fee_amount,
            'balance_after', NEW.balance_after,
            'oli_address', NEW.oli_address,
            'status', NEW.status
        )
    )
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ledger_emit_event ON oli_bank_ledger;
CREATE TRIGGER trg_ledger_emit_event
    AFTER INSERT ON oli_bank_ledger
    FOR EACH ROW EXECUTE FUNCTION oli_ledger_emit_event();

-- Trigger : Alerter si escrow créé
CREATE OR REPLACE FUNCTION oli_escrow_emit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO oli_bank_events (event_id, event_type, source, user_id, escrow_ref, payload)
    VALUES (
        'EVT-ESC-' || NEW.id,
        'escrow.' || NEW.status,
        'system',
        NEW.buyer_id,
        NEW.escrow_ref,
        jsonb_build_object(
            'order_id', NEW.order_id,
            'amount_locked', NEW.amount_locked,
            'seller_id', NEW.seller_id,
            'status', NEW.status
        )
    )
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_escrow_emit_event ON oli_bank_escrow;
CREATE TRIGGER trg_escrow_emit_event
    AFTER INSERT OR UPDATE ON oli_bank_escrow
    FOR EACH ROW EXECUTE FUNCTION oli_escrow_emit_event();

-- ─────────────────────────────────────────────────────────────────────
-- 8. Type de transaction étendu pour wallet_transactions (compatibilité)
-- ─────────────────────────────────────────────────────────────────────
DO $$
BEGIN
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
    CHECK (type IN (
        'deposit', 'deposit_pending', 'withdrawal', 'withdrawal_pending',
        'payment', 'refund', 'reward', 'transfer', 'credit', 'system_credit',
        'escrow_lock', 'escrow_release', 'escrow_refund', 'fee'
    ));

-- Ajouter colonne ledger_tx_id pour relier wallet_transactions au grand livre
ALTER TABLE wallet_transactions
    ADD COLUMN IF NOT EXISTS ledger_tx_id VARCHAR(64) REFERENCES oli_bank_ledger(tx_id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────────────
-- 9. Vérification finale
-- ─────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 039 terminée: OLI Bank — Portail Cryptographique Utilisateur';
    RAISE NOTICE '   Tables créées: oli_bank_keypairs, oli_bank_ledger, oli_bank_escrow, user_sessions_ext, oli_bank_events';
    RAISE NOTICE '   Vue créée: oli_bank_user_portal';
    RAISE NOTICE '   Triggers: trg_ledger_emit_event, trg_escrow_emit_event';
END $$;
