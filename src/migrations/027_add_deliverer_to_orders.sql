-- =====================================================
-- Migration 027: Add Deliverer to Orders Table
-- Date: 2026-02-05
-- Purpose: Link orders to deliverers and track delivery status
-- =====================================================

-- Ajouter colonnes delivery à la table orders
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS deliverer_id UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS delivery_status VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS assigned_to_deliverer_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS delivery_accepted_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS delivery_completed_at TIMESTAMP;

-- Indexes pour requêtes rapides
CREATE INDEX IF NOT EXISTS idx_orders_deliverer ON orders(deliverer_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_status ON orders(delivery_status);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_pending ON orders(status, delivery_status) 
WHERE status = 'paid' AND delivery_status IS NULL;

-- Commentaires pour documentation
COMMENT ON COLUMN orders.deliverer_id IS 'Livreur assigné à cette commande';
COMMENT ON COLUMN orders.delivery_status IS 'Statut de livraison: pending, assigned, in_transit, delivered';
COMMENT ON COLUMN orders.assigned_to_deliverer_at IS 'Timestamp d''assignation au livreur';
COMMENT ON COLUMN orders.delivery_accepted_at IS 'Timestamp d''acceptation par le livreur';
COMMENT ON COLUMN orders.delivery_completed_at IS 'Timestamp de livraison complétée';

-- Vérification
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'orders' 
    AND column_name IN ('deliverer_id', 'delivery_status');
    
    IF col_count >= 2 THEN
        RAISE NOTICE '✅ Colonnes delivery ajoutées à orders avec succès!';
        RAISE NOTICE '📦 Nouvelles colonnes: deliverer_id, delivery_status, timestamps';
        RAISE NOTICE '🔍 Index créés pour optimiser les requêtes livreurs';
    ELSE
        RAISE WARNING '⚠️ Certaines colonnes n''ont pas été ajoutées';
    END IF;
END $$;
