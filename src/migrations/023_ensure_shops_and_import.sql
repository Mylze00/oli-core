-- Migration 023: Ensure Shops and Import Tables Exist (Corrected for UUID)

-- Drop shops if exists (to fix ID type mismatch if created int)
DROP TABLE IF EXISTS shops CASCADE;

-- 1. Create Shops Table (with UUID)
CREATE TABLE IF NOT EXISTS shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    logo_url TEXT,
    banner_url TEXT,
    category VARCHAR(50),
    location VARCHAR(100),
    is_verified BOOLEAN DEFAULT FALSE,
    rating DECIMAL(2,1) DEFAULT 5.0,
    total_products INTEGER DEFAULT 0,
    total_sales INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for shops
CREATE INDEX IF NOT EXISTS idx_shops_owner ON shops(owner_id);

-- 2. Add FK to products if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'products_shop_id_fkey'
    ) THEN
        ALTER TABLE products ADD CONSTRAINT products_shop_id_fkey
        FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Create Import History Table (from 020)
CREATE TABLE IF NOT EXISTS import_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    total_rows INTEGER DEFAULT 0,
    imported_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    errors JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_import_history_seller ON import_history(seller_id);

-- 4. Create Product Variants and Stock Alerts (from 020)
CREATE TABLE IF NOT EXISTS product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    variant_type VARCHAR(50) NOT NULL,
    variant_value VARCHAR(100) NOT NULL,
    sku VARCHAR(100),
    price_adjustment DECIMAL(10,2) DEFAULT 0,
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, variant_type, variant_value)
);

CREATE TABLE IF NOT EXISTS stock_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    threshold INTEGER DEFAULT 5,
    is_active BOOLEAN DEFAULT true,
    last_triggered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices from 020
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_active ON product_variants(product_id, is_active);
CREATE INDEX IF NOT EXISTS idx_stock_alerts_product ON stock_alerts(product_id);

-- Trigger for variants
CREATE OR REPLACE FUNCTION update_variant_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_variant_timestamp ON product_variants;
CREATE TRIGGER trigger_update_variant_timestamp
BEFORE UPDATE ON product_variants
FOR EACH ROW EXECUTE FUNCTION update_variant_timestamp();
