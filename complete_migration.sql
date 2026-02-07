-- ============================================================
-- MIGRATION COMPLÈTE OLI - NOUVELLE BASE DE DONNÉES RENDER
-- Base: oli_db_hui8
-- Date: 2026-02-07
-- ============================================================
-- Ce script exécute TOUTES les migrations dans le bon ordre
-- pour recréer le schéma complet de la base de données Oli
-- ============================================================

\echo '============================================================'
\echo 'DÉBUT DE LA MIGRATION COMPLÈTE OLI'
\echo '============================================================'

-- ============================================================
-- ÉTAPE 1: CRÉATION DES TABLES DE BASE
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 1/6: Création de la table users...'

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100),
    id_oli VARCHAR(50) UNIQUE,
    email VARCHAR(100),
    wallet DECIMAL(10,2) DEFAULT 0.00,
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    otp_code VARCHAR(10),
    otp_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

\echo '✅ Table users créée'

-- ============================================================
-- ÉTAPE 2: CRÉATION DES TABLES SOCIALES ET PRODUITS
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 2/6: Création des tables products, conversations, messages...'

-- Table Produits
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    seller_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),
    images TEXT[],
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Table Méthodes de Paiement
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,
    provider VARCHAR(50),
    last4 VARCHAR(4),
    token VARCHAR(255) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Table Amitiés
CREATE TABLE IF NOT EXISTS friendships (
    id SERIAL PRIMARY KEY,
    requester_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    addressee_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(requester_id, addressee_id)
);

-- Table Conversations
CREATE TABLE IF NOT EXISTS conversations (
    id SERIAL PRIMARY KEY,
    type VARCHAR(20) DEFAULT 'private',
    name VARCHAR(100),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Table Participants
CREATE TABLE IF NOT EXISTS conversation_participants (
    conversation_id INTEGER REFERENCES conversations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    last_read_at TIMESTAMP,
    PRIMARY KEY (conversation_id, user_id)
);

-- Table Messages
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) DEFAULT 'text',
    content TEXT,
    amount DECIMAL(10,2),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_products_seller ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_participants_user ON conversation_participants(user_id);

\echo '✅ Tables sociales et produits créées'

-- ============================================================
-- ÉTAPE 3: CRÉATION DES TABLES DE COMMANDES
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 3/6: Création des tables orders et order_items...'

-- Table des commandes
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    delivery_address TEXT,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    payment_method VARCHAR(30),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Table des items de commande
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_image_url TEXT,
    product_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
    seller_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

\echo '✅ Tables de commandes créées'

-- ============================================================
-- ÉTAPE 4: CRÉATION DES TABLES DE TRANSACTIONS
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 4/6: Création de la table transactions...'

-- Ajout de la colonne points de fidélité
ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_points INTEGER DEFAULT 0;

-- Création de la table des transactions
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    reference VARCHAR(100),
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

\echo '✅ Table transactions créée'

-- ============================================================
-- ÉTAPE 5: MIGRATION PHASE 1 COMPLÈTE
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 5/6: Exécution de la migration Phase 1...'

-- Enrichir la table users
ALTER TABLE users ADD COLUMN IF NOT EXISTS country_code VARCHAR(5) DEFAULT '+243';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_seller BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_deliverer BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS rating DECIMAL(2,1) DEFAULT 5.0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_sales INTEGER DEFAULT 0;

-- Table des boutiques virtuelles
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

-- Enrichir la table products
ALTER TABLE products ADD COLUMN IF NOT EXISTS shop_id INTEGER REFERENCES shops(id) ON DELETE SET NULL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_negotiable BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_location ON products(location);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Table des livraisons
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

-- Historique des transactions wallet
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

-- Enrichir conversations et messages
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS product_id INTEGER REFERENCES products(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id INTEGER REFERENCES messages(id) ON DELETE SET NULL;

-- Table des favoris
CREATE TABLE IF NOT EXISTS favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);

-- Table des notifications
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

\echo '✅ Migration Phase 1 terminée'

-- ============================================================
-- ÉTAPE 6: MIGRATIONS NUMÉROTÉES (003-027)
-- ============================================================

\echo ''
\echo '>>> ÉTAPE 6/6: Exécution des migrations numérotées...'

-- Migration 004: user_product_views
CREATE TABLE IF NOT EXISTS user_product_views (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_user_product_views_user ON user_product_views(user_id);
CREATE INDEX IF NOT EXISTS idx_user_product_views_product ON user_product_views(product_id);

\echo '  ✓ Migration 004: user_product_views'

-- Migration 005: addresses
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50),
    address TEXT NOT NULL,
    city VARCHAR(100),
    phone VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

\echo '  ✓ Migration 005: addresses'

-- Migration 006: last_profile_update
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_profile_update TIMESTAMP DEFAULT NULL;

\echo '  ✓ Migration 006: last_profile_update'

-- Migration 007: admin et featured
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_products_featured ON products(is_featured) WHERE is_featured = TRUE AND status = 'active';
CREATE INDEX IF NOT EXISTS idx_users_admin ON users(is_admin) WHERE is_admin = TRUE;

\echo '  ✓ Migration 007: admin et featured'

-- Migration 008: admin_dashboard_support
ALTER TABLE users ADD COLUMN IF NOT EXISTS account_type VARCHAR(20) DEFAULT 'personal' CHECK (account_type IN ('personal', 'business'));

\echo '  ✓ Migration 008: admin_dashboard_support'

-- Migration 009: disputes
CREATE TABLE IF NOT EXISTS disputes (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    created_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_disputes_order ON disputes(order_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);

\echo '  ✓ Migration 009: disputes'

-- Migration 010: user_identity_architecture (simplifié)
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_certified BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS avatar_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    avatar_url TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

\echo '  ✓ Migration 010: user_identity_architecture'

-- Migration 011: exchange_rates
CREATE TABLE IF NOT EXISTS exchange_rates (
    id SERIAL PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(10,6) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(from_currency, to_currency)
);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_currencies ON exchange_rates(from_currency, to_currency);

\echo '  ✓ Migration 011: exchange_rates'

-- Migration 012: product_details
ALTER TABLE products ADD COLUMN IF NOT EXISTS brand VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS condition VARCHAR(20) DEFAULT 'new' CHECK (condition IN ('new', 'used', 'refurbished'));
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity INTEGER DEFAULT 0;

\echo '  ✓ Migration 012: product_details'

-- Migration 013: services
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),
    images TEXT[],
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_services_provider ON services(provider_id);

\echo '  ✓ Migration 013: services'

-- Migration 014: seller_certification (simplifié)
ALTER TABLE users ADD COLUMN IF NOT EXISTS certification_score INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;

\echo '  ✓ Migration 014: seller_certification'

-- Migration 015: product_discounts
ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_percentage INTEGER DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_end_date TIMESTAMP;

\echo '  ✓ Migration 015: product_discounts'

-- Migration 016: products_is_active
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active) WHERE is_active = TRUE;

\echo '  ✓ Migration 016: products_is_active'

-- Migration 017: express_delivery_price
ALTER TABLE products ADD COLUMN IF NOT EXISTS express_delivery_price DECIMAL(10,2) DEFAULT 0;

\echo '  ✓ Migration 017: express_delivery_price'

-- Migration 018: subscription_and_admin
CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    started_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    UNIQUE(user_id)
);

\echo '  ✓ Migration 018: subscription_and_admin'

-- Migration 019: shipping_options
ALTER TABLE products ADD COLUMN IF NOT EXISTS shipping_options JSONB DEFAULT '[]'::jsonb;

\echo '  ✓ Migration 019: shipping_options'

-- Migration 020: product_variants_and_import
CREATE TABLE IF NOT EXISTS product_variants (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    variant_name VARCHAR(100),
    variant_value VARCHAR(100),
    price_adjustment DECIMAL(10,2) DEFAULT 0,
    stock_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS import_history (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER REFERENCES shops(id) ON DELETE CASCADE,
    filename VARCHAR(255),
    total_rows INTEGER,
    successful_rows INTEGER,
    failed_rows INTEGER,
    status VARCHAR(20) DEFAULT 'processing',
    created_at TIMESTAMP DEFAULT NOW()
);

\echo '  ✓ Migration 020: product_variants_and_import'

-- Migration 021: order_workflow
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number VARCHAR(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP;

\echo '  ✓ Migration 021: order_workflow'

-- Migration 022: coupons_loyalty
CREATE TABLE IF NOT EXISTS coupons (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER REFERENCES shops(id) ON DELETE CASCADE,
    code VARCHAR(50) UNIQUE NOT NULL,
    discount_type VARCHAR(20) CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL,
    min_purchase DECIMAL(10,2) DEFAULT 0,
    max_uses INTEGER,
    current_uses INTEGER DEFAULT 0,
    valid_from TIMESTAMP DEFAULT NOW(),
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS loyalty_programs (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER REFERENCES shops(id) ON DELETE CASCADE,
    points_per_dollar DECIMAL(5,2) DEFAULT 1.00,
    redemption_rate DECIMAL(5,2) DEFAULT 0.01,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(shop_id)
);

CREATE TABLE IF NOT EXISTS loyalty_points (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    shop_id INTEGER REFERENCES shops(id) ON DELETE CASCADE,
    points INTEGER DEFAULT 0,
    lifetime_points INTEGER DEFAULT 0,
    tier VARCHAR(20) DEFAULT 'bronze',
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, shop_id)
);

\echo '  ✓ Migration 022: coupons_loyalty'

-- Migration 023: ensure_shops_and_import (déjà créé)
\echo '  ✓ Migration 023: ensure_shops_and_import (skip)'

-- Migration 024: support_tickets
CREATE TABLE IF NOT EXISTS support_tickets (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);

\echo '  ✓ Migration 024: support_tickets'

-- Migration 025: delivery_qr
ALTER TABLE delivery_orders ADD COLUMN IF NOT EXISTS qr_code TEXT;
ALTER TABLE delivery_orders ADD COLUMN IF NOT EXISTS verification_code VARCHAR(6);

\echo '  ✓ Migration 025: delivery_qr'

-- Migration 026: deliveries_table
CREATE TABLE IF NOT EXISTS deliveries (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    deliverer_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'pending',
    pickup_address TEXT,
    delivery_address TEXT,
    tracking_code VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deliveries_order ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_deliverer ON deliveries(deliverer_id);

\echo '  ✓ Migration 026: deliveries_table'

-- Migration 027: add_deliverer_to_orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS deliverer_id INTEGER REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_status VARCHAR(20) DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_orders_deliverer ON orders(deliverer_id);

\echo '  ✓ Migration 027: add_deliverer_to_orders'

-- Migrations supplémentaires
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_oli_unique VARCHAR(50);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_id_oli_unique ON users(id_oli_unique) WHERE id_oli_unique IS NOT NULL;

\echo '  ✓ Migrations supplémentaires terminées'

\echo ''
\echo '============================================================'
\echo 'MIGRATION COMPLÈTE TERMINÉE AVEC SUCCÈS !'
\echo '============================================================'

-- Vérification finale
DO $$
DECLARE
    table_count INTEGER;
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public';
    
    SELECT COUNT(*) INTO index_count 
    FROM pg_indexes 
    WHERE schemaname = 'public';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STATISTIQUES DE LA BASE DE DONNÉES';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Nombre de tables: %', table_count;
    RAISE NOTICE 'Nombre d''index: %', index_count;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ La base de données est prête à être utilisée !';
    RAISE NOTICE '';
END $$;
