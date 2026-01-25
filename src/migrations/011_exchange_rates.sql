-- Migration 011: Système de taux de change
-- Permet la conversion USD ↔ CDF avec historique des taux

-- Table pour stocker l'historique des taux de change
CREATE TABLE IF NOT EXISTS exchange_rates (
    id SERIAL PRIMARY KEY,
    base_currency VARCHAR(3) DEFAULT 'USD',
    target_currency VARCHAR(3) NOT NULL,
    rate NUMERIC(12, 6) NOT NULL,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50) DEFAULT 'exchangerate-api',
    CONSTRAINT unique_rate_per_day UNIQUE (base_currency, target_currency, DATE(fetched_at))
);

-- Index pour améliorer les performances de recherche
CREATE INDEX IF NOT EXISTS idx_exchange_rates_currencies 
    ON exchange_rates(base_currency, target_currency);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_fetched_at 
    ON exchange_rates(fetched_at DESC);

-- Commentaires
COMMENT ON TABLE exchange_rates IS 'Historique des taux de change pour conversion USD ↔ CDF';
COMMENT ON COLUMN exchange_rates.rate IS 'Taux de change (ex: 1 USD = 2800 CDF)';
COMMENT ON COLUMN exchange_rates.source IS 'Source de l''API (exchangerate-api, fixer.io, etc.)';

-- Insérer un taux par défaut (sera mis à jour par l'API)
INSERT INTO exchange_rates (base_currency, target_currency, rate, source)
VALUES ('USD', 'CDF', 2800.00, 'default')
ON CONFLICT (base_currency, target_currency, DATE(fetched_at)) 
DO NOTHING;

-- Log
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 011: Table exchange_rates créée avec succès';
END $$;
