-- ============================================
-- Migration 020: Product Variants & Import History
-- PRODUCTION - À exécuter sur Render.com
-- ============================================

-- Table pour l'historique des imports CSV
CREATE TABLE IF NOT EXISTS import_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    total_rows INTEGER DEFAULT 0,
    imported_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    errors JSONB DEFAULT '[]', -- Liste des erreurs détaillées
    status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Table des variantes de produits
CREATE TABLE IF NOT EXISTS product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    variant_type VARCHAR(50) NOT NULL, -- 'size', 'color', 'material', 'style'
    variant_value VARCHAR(100) NOT NULL, -- 'XL', 'Rouge', 'Coton', 'Classique'
    sku VARCHAR(100), -- Code SKU unique optionnel
    price_adjustment DECIMAL(10,2) DEFAULT 0, -- +/- par rapport au prix de base
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, variant_type, variant_value)
);

-- Table des alertes de stock
CREATE TABLE IF NOT EXISTS stock_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    threshold INTEGER DEFAULT 5, -- Seuil d'alerte (ex: alerter quand stock < 5)
    is_active BOOLEAN DEFAULT true,
    last_triggered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_active ON product_variants(product_id, is_active);
CREATE INDEX IF NOT EXISTS idx_stock_alerts_product ON stock_alerts(product_id);
CREATE INDEX IF NOT EXISTS idx_import_history_seller ON import_history(seller_id);

-- Trigger pour updated_at sur product_variants
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

-- Commentaires pour documentation
COMMENT ON TABLE product_variants IS 'Variantes de produits (taille, couleur, etc.)';
COMMENT ON TABLE stock_alerts IS 'Alertes de stock bas pour les produits';
COMMENT ON TABLE import_history IS 'Historique des imports CSV de produits';

-- Vérification finale
SELECT 'Migration 020 completed!' as status;
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('import_history', 'product_variants', 'stock_alerts');
