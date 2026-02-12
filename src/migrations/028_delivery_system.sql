-- =====================================================
-- Migration 028: Delivery System - Unified Delivery Methods
-- Date: 2026-02-12
-- Purpose: Create delivery_methods reference table and
--          add delivery_method_id to orders
-- =====================================================

-- 1. Table de référence des méthodes de livraison
CREATE TABLE IF NOT EXISTS delivery_methods (
    id VARCHAR(30) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    requires_deliverer BOOLEAN DEFAULT false,
    requires_address BOOLEAN DEFAULT true,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Seed des 6 méthodes de livraison
INSERT INTO delivery_methods (id, label, description, requires_deliverer, requires_address, icon, sort_order)
VALUES
    ('oli_express', 'Oli Express', 'Livraison rapide gérée par Oli', true, true, 'local_shipping', 1),
    ('oli_standard', 'Oli Standard', 'Livraison standard gérée par Oli', true, true, 'inventory_2', 2),
    ('partner', 'Livreur Partenaire', 'Livraison par un livreur via Oli Delivery', true, true, 'delivery_dining', 3),
    ('hand_delivery', 'Remise en Main Propre', 'Le vendeur et l''acheteur s''arrangent entre eux', false, false, 'handshake', 4),
    ('pick_go', 'Pick & Go', 'L''acheteur récupère sa commande au guérite du magasin', false, false, 'store', 5),
    ('free', 'Livraison Gratuite', 'Offerte par le vendeur', false, true, 'card_giftcard', 6)
ON CONFLICT (id) DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    requires_deliverer = EXCLUDED.requires_deliverer,
    requires_address = EXCLUDED.requires_address,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order;

-- 3. Ajouter delivery_method_id et pickup info à orders
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS delivery_method_id VARCHAR(30) REFERENCES delivery_methods(id),
ADD COLUMN IF NOT EXISTS pickup_address TEXT,
ADD COLUMN IF NOT EXISTS pickup_lat DECIMAL(10,8),
ADD COLUMN IF NOT EXISTS pickup_lng DECIMAL(11,8);

-- 4. Index pour performance
CREATE INDEX IF NOT EXISTS idx_orders_delivery_method ON orders(delivery_method_id);

-- 5. Commentaires
COMMENT ON TABLE delivery_methods IS 'Table de référence des 6 méthodes de livraison disponibles';
COMMENT ON COLUMN orders.delivery_method_id IS 'Méthode de livraison choisie: oli_express, oli_standard, partner, hand_delivery, pick_go, free';
COMMENT ON COLUMN orders.pickup_address IS 'Adresse de retrait pour pick_go (guérite du magasin)';
COMMENT ON COLUMN products.shipping_options IS 'Array JSON des méthodes de livraison activées par le vendeur. Format: [{"methodId": "oli_express", "cost": 5.00, "time": "1-2h"}, ...]';

-- 6. Vérification
DO $$
DECLARE
    method_count INTEGER;
    col_exists BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO method_count FROM delivery_methods;
    SELECT EXISTS(
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'delivery_method_id'
    ) INTO col_exists;
    
    IF method_count >= 6 AND col_exists THEN
        RAISE NOTICE '✅ Système de livraison initialisé avec succès!';
        RAISE NOTICE '📦 % méthodes de livraison créées', method_count;
        RAISE NOTICE '🔗 Colonne delivery_method_id ajoutée à orders';
    ELSE
        RAISE WARNING '⚠️ Installation incomplète: % méthodes, colonne=%', method_count, col_exists;
    END IF;
END $$;
