-- Migration 031: Fix orders status check constraint
-- Add 'ready' to the allowed status values

-- Drop the existing constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Recreate with all valid statuses including 'ready'
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
  CHECK (status IN ('pending', 'paid', 'processing', 'ready', 'shipped', 'delivered', 'cancelled', 'refunded'));

SELECT 'Migration 031 orders_status_check updated with ready status' AS status;
