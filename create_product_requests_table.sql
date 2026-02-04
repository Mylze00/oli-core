-- Migration: Création des tables pour les demandes de produit
-- À exécuter via psql $DATABASE_URL

-- Table des demandes de produit
CREATE TABLE IF NOT EXISTS product_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(255) DEFAULT 'Anonyme',
    user_phone VARCHAR(50),
    description TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(50) DEFAULT 'pending', -- pending, reviewed, responded, closed
    admin_response TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Table des notifications admin
CREATE TABLE IF NOT EXISTS admin_notifications (
    id SERIAL PRIMARY KEY,
    type VARCHAR(100) NOT NULL, -- product_request, new_seller, report, etc.
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_product_requests_status ON product_requests(status);
CREATE INDEX IF NOT EXISTS idx_product_requests_created_at ON product_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_type ON admin_notifications(type);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_is_read ON admin_notifications(is_read);

-- Vérification
SELECT 'Tables product_requests et admin_notifications créées avec succès!' AS result;
