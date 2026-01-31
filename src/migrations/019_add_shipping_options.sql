-- Migration: Add shipping_options to products table

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS shipping_options JSONB DEFAULT '[]'::JSONB;

-- Optional: Migrate existing data based on delivery_price and delivery_time
UPDATE products 
SET shipping_options = jsonb_build_array(
    jsonb_build_object(
        'methodId', 'oli_standard',
        'label', 'Oli Standard',
        'cost', delivery_price,
        'time', COALESCE(delivery_time, '5-7 jours')
    )
)
WHERE shipping_options IS NULL OR jsonb_array_length(shipping_options) = 0;
