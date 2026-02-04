-- Migration 021: Order Status History & Notifications
-- Historique des changements de statut et notifications vendeur

-- Table historique des changements de statut
CREATE TABLE IF NOT EXISTS order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    previous_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by INTEGER REFERENCES users(id), -- NULL si système
    changed_by_role VARCHAR(20) DEFAULT 'system', -- 'buyer', 'seller', 'admin', 'system'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table notifications vendeur (pour commandes)
CREATE TABLE IF NOT EXISTS seller_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'new_order', 'order_paid', 'order_cancelled', 'low_stock', etc.
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data JSONB DEFAULT '{}', -- order_id, product_id, etc.
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ajout numéro de suivi aux commandes
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number VARCHAR(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS carrier VARCHAR(100); -- DHL, FedEx, etc.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS estimated_delivery DATE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_seller_notifications_seller ON seller_notifications(seller_id);
CREATE INDEX IF NOT EXISTS idx_seller_notifications_unread ON seller_notifications(seller_id, is_read) WHERE is_read = false;

-- Commentaires
COMMENT ON TABLE order_status_history IS 'Historique des changements de statut des commandes';
COMMENT ON TABLE seller_notifications IS 'Notifications in-app pour les vendeurs';
