-- ============================================
-- Configuration Admin & Produits Featured
-- À exécuter dans PostgreSQL production (Render)
-- ============================================

-- 1. Définir +243827088682 comme administrateur
UPDATE users 
SET is_admin = TRUE 
WHERE phone = '+243827088682';

-- Vérification
SELECT id, phone, name, is_admin 
FROM users 
WHERE phone = '+243827088682';

-- 2. Marquer les 5 premiers produits actifs comme featured
UPDATE products 
SET is_featured = TRUE 
WHERE id IN (
    SELECT id FROM products 
    WHERE status = 'active' 
    ORDER BY created_at DESC 
    LIMIT 5
);

-- OU si vous connaissez les IDs spécifiques :
-- UPDATE products SET is_featured = TRUE WHERE id IN (1, 2, 3, 4, 5);

-- Vérification
SELECT id, name, seller_id, is_featured, status 
FROM products 
WHERE is_featured = TRUE;

-- 3. Afficher résumé
SELECT 
    (SELECT COUNT(*) FROM users WHERE is_admin = TRUE) as admins_count,
    (SELECT COUNT(*) FROM products WHERE is_featured = TRUE) as featured_products_count;
