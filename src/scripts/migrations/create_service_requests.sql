-- ============================================
-- Table: service_requests
-- Centralise les demandes de sponsorisation, 
-- vérification utilisateur et certification boutique
-- ============================================

CREATE TABLE IF NOT EXISTS service_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Type de demande
    request_type VARCHAR(50) NOT NULL CHECK (request_type IN (
        'product_sponsorship',    -- Sponsoriser un produit
        'user_verification',      -- Devenir vendeur vérifié
        'shop_certification'      -- Certifier une boutique
    )),
    
    -- ID cible (product_id ou shop_id selon le type)
    target_id INTEGER,
    
    -- Informations de paiement
    amount DECIMAL(10,2) DEFAULT 0,
    payment_status VARCHAR(30) DEFAULT 'pending' CHECK (payment_status IN (
        'pending',    -- En attente de paiement
        'paid',       -- Payé
        'failed',     -- Échec
        'refunded'    -- Remboursé
    )),
    payment_reference VARCHAR(100),
    payment_method VARCHAR(50), -- 'mobile_money', 'wallet', 'card'
    
    -- Statut admin
    admin_status VARCHAR(30) DEFAULT 'pending' CHECK (admin_status IN (
        'pending',    -- En attente de validation
        'approved',   -- Approuvé
        'rejected'    -- Rejeté
    )),
    admin_id INTEGER REFERENCES users(id), -- Admin qui a traité
    admin_notes TEXT,
    processed_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_service_requests_user ON service_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_type ON service_requests(request_type);
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON service_requests(admin_status);

-- Commentaire
COMMENT ON TABLE service_requests IS 'Demandes de services payants: sponsorisation produit, vérification utilisateur, certification boutique';
