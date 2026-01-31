-- Add express_delivery_price column to products table
ALTER TABLE products
ADD COLUMN express_delivery_price DECIMAL(10, 2) DEFAULT NULL;
