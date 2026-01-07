-- ====================================
-- OLI - Script de création des tables Orders
-- Exécuter: psql -d oli_db -f create_orders_tables.sql
-- ====================================

-- Table des commandes
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    delivery_address TEXT,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    payment_method VARCHAR(30), -- wallet, card, mobile_money_mpesa, mobile_money_orange, etc.
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

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Commentaires
COMMENT ON TABLE orders IS 'Table principale des commandes utilisateurs';
COMMENT ON TABLE order_items IS 'Produits inclus dans chaque commande';

-- ====================================
-- Requêtes utiles pour vérification
-- ====================================
-- SELECT * FROM orders;
-- SELECT * FROM order_items;
-- SELECT o.*, COUNT(oi.id) as items_count FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id GROUP BY o.id;
