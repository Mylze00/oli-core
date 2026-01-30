-- Migration: Add is_active column to products table
-- This column allows sellers to activate/deactivate products

-- Add is_active column with default true
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);

-- Comment
COMMENT ON COLUMN products.is_active IS 'Indicates if the product is active and visible to customers';
