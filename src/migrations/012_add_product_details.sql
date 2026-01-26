-- Migration: Add detailed fields to products table
-- Description: Adds unit, brand, weight, and b2b_pricing columns to support advanced product details.

ALTER TABLE products
ADD COLUMN IF NOT EXISTS unit VARCHAR(50) DEFAULT 'Pièce',
ADD COLUMN IF NOT EXISTS brand VARCHAR(100),
ADD COLUMN IF NOT EXISTS weight VARCHAR(50),
ADD COLUMN IF NOT EXISTS b2b_pricing JSONB DEFAULT '[]';

-- Add comments for documentation
COMMENT ON COLUMN products.unit IS 'Unit of measurement for the product (e.g., Pièce, Kg, Litre)';
COMMENT ON COLUMN products.brand IS 'Brand name of the product';
COMMENT ON COLUMN products.weight IS 'Weight or volume of the product';
COMMENT ON COLUMN products.b2b_pricing IS 'JSON array of B2B pricing tiers (e.g., [{qty: 10, price: 90}, {qty: 50, price: 85}])';
