-- Migration: Add category column to products table
-- Date: 2026-02-09
-- Description: Adds category field for product classification

-- Step 1: Add category column (nullable initially)
ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(50);

-- Step 2: Create index for performance
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Step 3: Add comment
COMMENT ON COLUMN products.category IS 'Product category: industry, home, vehicles, fashion, electronics, beauty, kids';

-- Verification
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'products' 
AND column_name = 'category';
