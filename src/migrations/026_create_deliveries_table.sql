-- =====================================================
-- Migration 026: Delivery System - Deliveries Table
-- Date: 2026-02-05
-- Purpose: Create deliveries tracking table for oli_delivery app
-- =====================================================

-- Table deliveries pour tracker le statut des livraisons
CREATE TABLE IF NOT EXISTS deliveries (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    deliverer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Statut de la livraison
    status VARCHAR(50) DEFAULT 'pending', -- pending, assigned, accepted, picked_up, in_transit, delivered, cancelled
    
    -- Timestamps du workflow
    assigned_at TIMESTAMP,
    accepted_at TIMESTAMP,
    picked_up_at TIMESTAMP,
    in_transit_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    
    -- Localisation en temps réel du livreur
    current_lat DECIMAL(10, 8),
    current_lng DECIMAL(11, 8),
    last_location_update TIMESTAMP,
    
    -- Vérification livraison
    verification_code VARCHAR(10),
    verification_method VARCHAR(20), -- qr_code, pin, signature
    customer_signature_url TEXT,
    delivery_photo_url TEXT,
    
    -- Notes et raisons
    delivery_notes TEXT,
    cancellation_reason TEXT,
    
    -- Metadata
    estimated_delivery_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    delivery_duration_minutes INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes pour performance
CREATE INDEX IF NOT EXISTS idx_deliveries_order ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_deliverer ON deliveries(deliverer_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_deliveries_created ON deliveries(created_at DESC);

-- Constraint: Une commande = une livraison
CREATE UNIQUE INDEX IF NOT EXISTS idx_deliveries_unique_order ON deliveries(order_id);

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_deliveries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_deliveries_updated_at ON deliveries;
CREATE TRIGGER trigger_deliveries_updated_at
    BEFORE UPDATE ON deliveries
    FOR EACH ROW
    EXECUTE FUNCTION update_deliveries_updated_at();

-- Vérification
DO $$
BEGIN
    RAISE NOTICE '✅ Table deliveries créée avec succès!';
    RAISE NOTICE '📦 Colonnes: order_id, deliverer_id, status, timestamps, location, verification';
    RAISE NOTICE '🔗 Contraintes: UNIQUE sur order_id, FK vers orders et users';
END $$;
