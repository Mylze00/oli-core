-- Migration 032: Add seller_id to orders table
-- Stores the primary seller directly on the order for faster queries
-- and resilience against product deletions.

-- Add seller_id column
ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_id INTEGER REFERENCES users(id);

-- Index for seller queries
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders(seller_id);

-- Populate existing orders from order_items → products
UPDATE orders o SET seller_id = sub.seller_id
FROM (
    SELECT DISTINCT ON (oi.order_id) oi.order_id, p.seller_id
    FROM order_items oi
    JOIN products p ON oi.product_id::integer = p.id
    WHERE p.seller_id IS NOT NULL
    ORDER BY oi.order_id
) sub
WHERE o.id = sub.order_id AND o.seller_id IS NULL;

COMMENT ON COLUMN orders.seller_id IS 'Vendeur principal de la commande (résolu à la création)';

SELECT 'Migration 032 seller_id added to orders' AS status;
