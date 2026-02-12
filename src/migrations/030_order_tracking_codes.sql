-- Migration 030: Order Tracking Codes & Enhanced Status
-- Ajouter codes de vérification pickup/delivery + nouveaux statuts

-- Codes de vérification sur la table orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_code VARCHAR(6);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_code VARCHAR(6);

-- Nouveaux timestamps pour le tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS processing_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS ready_at TIMESTAMPTZ;

-- Index pour recherche de codes
CREATE INDEX IF NOT EXISTS idx_orders_pickup_code ON orders(pickup_code) WHERE pickup_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_delivery_code ON orders(delivery_code) WHERE delivery_code IS NOT NULL;

-- Commentaires
COMMENT ON COLUMN orders.pickup_code IS 'Code 6 chars pour validation récupération par livreur';
COMMENT ON COLUMN orders.delivery_code IS 'Code 6 chars pour validation livraison par acheteur';
COMMENT ON COLUMN orders.processing_at IS 'Timestamp quand le vendeur commence la préparation';
COMMENT ON COLUMN orders.ready_at IS 'Timestamp quand le vendeur marque la commande comme prête';

SELECT 'Migration 030 order tracking codes applied' AS status;
