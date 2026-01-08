-- Phase 3: Enhance Products Table for Advanced Marketplace Features

-- 1. Add Condition & Quantity
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS condition VARCHAR(50) DEFAULT 'Neuf',
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;

-- 2. Add Delivery info
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS delivery_price DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS delivery_time VARCHAR(100) DEFAULT '';

-- 3. Add Color
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS color VARCHAR(50) DEFAULT '';

-- 4. Add Views/Likes counters for "Popular" logic
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;
