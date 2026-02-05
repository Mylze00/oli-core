-- Migration 025: Add delivery verification code
-- Ajout du code unique de livraison pour sécuriser la remise du colis

-- 1. Ajouter la colonne delivery_code à la table delivery_orders
ALTER TABLE delivery_orders 
ADD COLUMN IF NOT EXISTS delivery_code VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;

-- 2. Index pour recherche rapide lors du scan
CREATE INDEX IF NOT EXISTS idx_delivery_code ON delivery_orders(delivery_code);

-- 3. Fonction pour générer un code aléatoire (si besoin côté DB, sinon fait côté API)
-- On laisse l'API gérer la génération pour l'instant

COMMENT ON COLUMN delivery_orders.delivery_code IS 'Code unique à 6 caractères pour validation QR';
