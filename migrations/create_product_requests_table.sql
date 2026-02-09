-- Migration: Create product_requests table
-- Date: 2026-02-09
-- Description: Table pour stocker les demandes de produits des utilisateurs

CREATE TABLE IF NOT EXISTS product_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Product information requested
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    quantity INTEGER DEFAULT 1,
    
    -- Contact info (optional)
    contact_phone VARCHAR(20),
    contact_email VARCHAR(100),
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes TEXT,
    reviewed_by INTEGER REFERENCES users(id),
    reviewed_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    CONSTRAINT valid_quantity CHECK (quantity > 0)
);

-- Indexes for performance
CREATE INDEX idx_product_requests_user_id ON product_requests(user_id);
CREATE INDEX idx_product_requests_status ON product_requests(status);
CREATE INDEX idx_product_requests_category ON product_requests(category);
CREATE INDEX idx_product_requests_created_at ON product_requests(created_at DESC);

-- Comments
COMMENT ON TABLE product_requests IS 'Demandes de produits soumises par les utilisateurs';
COMMENT ON COLUMN product_requests.status IS 'pending: en attente, approved: approuvée, rejected: rejetée';

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_product_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_requests_updated_at
    BEFORE UPDATE ON product_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_product_requests_updated_at();

-- Verification query
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'product_requests'
ORDER BY ordinal_position;
