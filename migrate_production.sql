-- ====================================
-- OLI - Migration Phase 1 (PRODUCTION RENDER)
-- Version INTEGER pour users.id
-- ====================================

-- 1. Enrichir la table users
ALTER TABLE users ADD COLUMN IF NOT EXISTS country_code VARCHAR(5) DEFAULT '+243';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_seller BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_deliverer BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS rating DECIMAL(2,1) DEFAULT 5.0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_sales INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_points INTEGER DEFAULT 0;

-- 2. Table des boutiques virtuelles
DROP TABLE IF EXISTS shops CASCADE;
CREATE TABLE IF NOT EXISTS shops (
    id SERIAL PRIMARY KEY,
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
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shops_owner ON shops(owner_id);
CREATE INDEX IF NOT EXISTS idx_shops_category ON shops(category);

-- 3. Enrichir la table products
ALTER TABLE products ADD COLUMN IF NOT EXISTS shop_id INTEGER REFERENCES shops(id) ON DELETE SET NULL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_negotiable BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_location ON products(location);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- 4. Table des livraisons
DROP TABLE IF EXISTS delivery_orders CASCADE;
CREATE TABLE IF NOT EXISTS delivery_orders (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    deliverer_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
    
    pickup_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    
    pickup_lat DECIMAL(10,8),
    pickup_lng DECIMAL(11,8),
    delivery_lat DECIMAL(10,8),
    delivery_lng DECIMAL(11,8),
    current_lat DECIMAL(10,8),
    current_lng DECIMAL(11,8),
    
    estimated_time VARCHAR(50),
    actual_pickup_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    deliverer_earnings DECIMAL(10,2) DEFAULT 0,
    
    deliverer_rating INTEGER CHECK (deliverer_rating >= 1 AND deliverer_rating <= 5),
    customer_notes TEXT,
    deliverer_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_orders_deliverer ON delivery_orders(deliverer_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_status ON delivery_orders(status);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_order ON delivery_orders(order_id);

-- 5. Historique des transactions wallet
DROP TABLE IF EXISTS wallet_transactions CASCADE;
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'payment', 'refund', 'reward', 'transfer')),
    amount DECIMAL(10,2) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    reference VARCHAR(100),
    provider VARCHAR(50), 
    description TEXT,
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);

-- 6. Enrichir la table conversations
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS product_id INTEGER REFERENCES products(id) ON DELETE SET NULL;

-- 7. Enrichir la table messages
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id INTEGER REFERENCES messages(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'text';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB;

CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(type);

-- 8. Table des favoris/suivis
DROP TABLE IF EXISTS favorites CASCADE;
CREATE TABLE IF NOT EXISTS favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);

-- 9. Table des notifications
DROP TABLE IF EXISTS notifications CASCADE;
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);

-- ====================================
-- Commentaires
-- ====================================
COMMENT ON TABLE shops IS 'Boutiques virtuelles des vendeurs';
COMMENT ON TABLE delivery_orders IS 'Commandes de livraison pour la mini-app livreur';
COMMENT ON TABLE wallet_transactions IS 'Historique des transactions du wallet';
COMMENT ON TABLE favorites IS 'Produits suivis/favoris par les utilisateurs';
COMMENT ON TABLE notifications IS 'Notifications push et in-app';
