-- ============================================
-- OLI - Migration 022: Coupons & Fidélité
-- Système de codes promo et points de fidélité
-- ============================================

-- 1. Table des coupons vendeur
CREATE TABLE IF NOT EXISTS coupons (
    id SERIAL PRIMARY KEY,
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'percentage', -- percentage, fixed_amount, free_shipping
    value DECIMAL(10, 2) NOT NULL, -- % ou montant
    min_order_amount DECIMAL(10, 2) DEFAULT 0, -- Minimum de commande
    max_discount_amount DECIMAL(10, 2), -- Plafond remise (pour %)
    max_uses INTEGER, -- Limite totale d'utilisations
    max_uses_per_user INTEGER DEFAULT 1, -- Limite par client
    current_uses INTEGER DEFAULT 0,
    valid_from TIMESTAMP NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMP,
    applies_to VARCHAR(20) DEFAULT 'all', -- all, specific_products, category
    product_ids INTEGER[], -- Si applies_to = specific_products
    category_ids INTEGER[], -- Si applies_to = category
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(seller_id, code)
);

-- 2. Historique d'utilisation des coupons
CREATE TABLE IF NOT EXISTS coupon_usages (
    id SERIAL PRIMARY KEY,
    coupon_id INTEGER NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    discount_applied DECIMAL(10, 2) NOT NULL,
    used_at TIMESTAMP DEFAULT NOW()
);

-- 3. Points de fidélité par vendeur-client
CREATE TABLE IF NOT EXISTS loyalty_points (
    id SERIAL PRIMARY KEY,
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    points_balance INTEGER DEFAULT 0,
    total_points_earned INTEGER DEFAULT 0,
    total_points_spent INTEGER DEFAULT 0,
    tier VARCHAR(20) DEFAULT 'bronze', -- bronze, silver, gold, platinum
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(seller_id, user_id)
);

-- 4. Transactions de points fidélité
CREATE TABLE IF NOT EXISTS loyalty_transactions (
    id SERIAL PRIMARY KEY,
    loyalty_id INTEGER NOT NULL REFERENCES loyalty_points(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL, -- earn, spend, expire, bonus, adjustment
    points INTEGER NOT NULL, -- positif pour gain, négatif pour dépense
    description TEXT,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 5. Configuration fidélité par vendeur
CREATE TABLE IF NOT EXISTS loyalty_settings (
    id SERIAL PRIMARY KEY,
    seller_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    points_per_dollar DECIMAL(5, 2) DEFAULT 1.00, -- Points gagnés par $ dépensé
    points_value DECIMAL(5, 4) DEFAULT 0.01, -- Valeur $ d'un point
    min_points_redeem INTEGER DEFAULT 100, -- Minimum pour utiliser
    welcome_bonus INTEGER DEFAULT 0, -- Points offerts à l'inscription
    expiry_months INTEGER, -- Expiration des points (NULL = jamais)
    tier_thresholds JSONB DEFAULT '{"silver": 500, "gold": 2000, "platinum": 5000}'::jsonb,
    tier_multipliers JSONB DEFAULT '{"bronze": 1, "silver": 1.25, "gold": 1.5, "platinum": 2}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 6. Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_coupons_seller ON coupons(seller_id);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_coupon_usages_user ON coupon_usages(user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_user ON loyalty_points(user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_seller ON loyalty_points(seller_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_loyalty ON loyalty_transactions(loyalty_id);

-- 7. Commentaires
COMMENT ON TABLE coupons IS 'Codes promo créés par les vendeurs';
COMMENT ON TABLE coupon_usages IS 'Historique d''utilisation des coupons';
COMMENT ON TABLE loyalty_points IS 'Solde points fidélité par couple vendeur-client';
COMMENT ON TABLE loyalty_transactions IS 'Historique des mouvements de points';
COMMENT ON TABLE loyalty_settings IS 'Configuration du programme fidélité par vendeur';
