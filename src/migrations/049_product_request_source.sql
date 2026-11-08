-- ======================================================================
-- Migration 049 : Origine des demandes de produit
-- Objet : distinguer les besoins d'achat B2B (formulaire « Place de marché
-- B2B ») des autres demandes, pour les recevoir dans une rubrique dédiée.
-- ======================================================================

CREATE TABLE IF NOT EXISTS product_requests (
    id           SERIAL PRIMARY KEY,
    user_id      INTEGER REFERENCES users(id) ON DELETE SET NULL,
    user_name    VARCHAR(255) DEFAULT 'Anonyme',
    user_phone   VARCHAR(50),
    description  TEXT NOT NULL,
    image_url    TEXT,
    status       VARCHAR(50) DEFAULT 'pending',
    admin_response TEXT,
    created_at   TIMESTAMP DEFAULT NOW(),
    updated_at   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_notifications (
    id         SERIAL PRIMARY KEY,
    type       VARCHAR(100) NOT NULL,
    title      VARCHAR(255) NOT NULL,
    message    TEXT,
    data       JSONB,
    is_read    BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE product_requests ADD COLUMN IF NOT EXISTS source VARCHAR(20);
CREATE INDEX IF NOT EXISTS idx_product_requests_source ON product_requests(source);
