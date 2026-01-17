-- Migration 007: Ajouter système de produits mis en avant par admin
-- Permet à l'admin de marquer des produits comme "featured" pour la page Accueil

-- 1. Ajouter colonne is_admin aux utilisateurs
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- 2. Ajouter colonne is_featured aux produits
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

-- 3. Index pour optimiser les requêtes de produits featured
CREATE INDEX IF NOT EXISTS idx_products_featured 
ON products(is_featured) 
WHERE is_featured = TRUE AND status = 'active';

-- 4. Index pour utilisateurs admin
CREATE INDEX IF NOT EXISTS idx_users_admin 
ON users(is_admin) 
WHERE is_admin = TRUE;

-- 5. Marquer un utilisateur comme admin (à personnaliser avec votre numéro)
-- IMPORTANT: Remplacer +243XXXXXXXXX par le numéro admin
-- UPDATE users SET is_admin = TRUE WHERE phone = '+243XXXXXXXXX';

-- 6. Exemple: Marquer quelques produits comme featured (optionnel)
-- UPDATE products SET is_featured = TRUE WHERE id IN (1, 2, 3) AND seller_id IN (SELECT id FROM users WHERE is_admin = TRUE);

-- 7. Vérification
DO $$
DECLARE
    admin_count INTEGER;
    featured_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO admin_count FROM users WHERE is_admin = TRUE;
    SELECT COUNT(*) INTO featured_count FROM products WHERE is_featured = TRUE;
    
    RAISE NOTICE '✅ Migration 007 terminée!';
    RAISE NOTICE '👤 Admins: %', admin_count;
    RAISE NOTICE '⭐ Produits featured: %', featured_count;
    
    IF admin_count = 0 THEN
        RAISE WARNING '⚠️  Aucun admin défini. Exécuter: UPDATE users SET is_admin = TRUE WHERE phone = ''+243XXXXXXXXX'';';
    END IF;
END $$;
