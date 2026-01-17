-- ============================================================
-- MIGRATION CONSOLIDÉE PRODUCTION
-- Exécute TOUTES les migrations manquantes en une seule fois
-- ============================================================

-- Migration 004: Table user_product_views
CREATE TABLE IF NOT EXISTS user_product_views (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_user_product_views_user ON user_product_views(user_id);
CREATE INDEX IF NOT EXISTS idx_user_product_views_product ON user_product_views(product_id);

-- Migration 005: Table addresses
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

-- Migration 006: Colonne last_profile_update
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS last_profile_update TIMESTAMP DEFAULT NULL;

-- Migration 007: Colonnes is_admin et is_featured
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_products_featured 
ON products(is_featured) 
WHERE is_featured = TRUE AND status = 'active';

CREATE INDEX IF NOT EXISTS idx_users_admin 
ON users(is_admin) 
WHERE is_admin = TRUE;

-- Configuration: Définir admin
UPDATE users 
SET is_admin = TRUE 
WHERE phone = '+243827088682';

-- Configuration: Marquer 5 produits comme featured
UPDATE products 
SET is_featured = TRUE 
WHERE id IN (
    SELECT id FROM products 
    WHERE status = 'active' 
    ORDER BY created_at DESC 
    LIMIT 5
);

-- Vérification finale
DO $$
DECLARE
    has_last_profile_update BOOLEAN;
    has_is_admin BOOLEAN;
    has_is_featured BOOLEAN;
    has_addresses BOOLEAN;
    has_views BOOLEAN;
    admin_count INTEGER;
    featured_count INTEGER;
BEGIN
    -- Vérifier colonnes users
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'last_profile_update'
    ) INTO has_last_profile_update;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'is_admin'
    ) INTO has_is_admin;
    
    -- Vérifier colonne products
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'is_featured'
    ) INTO has_is_featured;
    
    -- Vérifier tables
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'addresses'
    ) INTO has_addresses;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'user_product_views'
    ) INTO has_views;
    
    -- Compter admins et featured
    SELECT COUNT(*) INTO admin_count FROM users WHERE is_admin = TRUE;
    SELECT COUNT(*) INTO featured_count FROM products WHERE is_featured = TRUE;
    
    -- Afficher résultats
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VÉRIFICATION MIGRATIONS PRODUCTION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'users.last_profile_update: %', CASE WHEN has_last_profile_update THEN '✅ OK' ELSE '❌ MANQUANT' END;
    RAISE NOTICE 'users.is_admin: %', CASE WHEN has_is_admin THEN '✅ OK' ELSE '❌ MANQUANT' END;
    RAISE NOTICE 'products.is_featured: %', CASE WHEN has_is_featured THEN '✅ OK' ELSE '❌ MANQUANT' END;
    RAISE NOTICE 'Table addresses: %', CASE WHEN has_addresses THEN '✅ OK' ELSE '❌ MANQUANT' END;
    RAISE NOTICE 'Table user_product_views: %', CASE WHEN has_views THEN '✅ OK' ELSE '❌ MANQUANT' END;
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Administrateurs: %', admin_count;
    RAISE NOTICE 'Produits featured: %', featured_count;
    RAISE NOTICE '========================================';
    
    IF NOT (has_last_profile_update AND has_is_admin AND has_is_featured AND has_addresses AND has_views) THEN
        RAISE WARNING '⚠️ Certaines migrations ont échoué !';
    ELSE
        RAISE NOTICE '✅ Toutes les migrations sont OK !';
    END IF;
END $$;
