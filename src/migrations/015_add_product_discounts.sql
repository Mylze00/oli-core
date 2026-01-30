-- Migration: Ajout des champs pour les promotions
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS discount_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS discount_start_date TIMESTAMP,
ADD COLUMN IF NOT EXISTS discount_end_date TIMESTAMP;

-- Index pour optimiser les requêtes sur les promos en cours
CREATE INDEX IF NOT EXISTS idx_products_discount_dates ON products(discount_start_date, discount_end_date);
