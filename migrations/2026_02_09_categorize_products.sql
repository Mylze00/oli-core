-- Migration: Auto-categorize existing products
-- Date: 2026-02-09
-- Description: Assigns categories to existing products based on keywords

-- ============================================
-- VEHICLES (Véhicules)
-- ============================================
UPDATE products 
SET category = 'vehicles'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%voiture%'
    OR LOWER(name) LIKE '%moto%'
    OR LOWER(name) LIKE '%véhicule%'
    OR LOWER(name) LIKE '%auto%'
    OR LOWER(name) LIKE '%camion%'
    OR LOWER(name) LIKE '%scooter%'
    OR LOWER(name) LIKE '%toyota%'
    OR LOWER(name) LIKE '%honda%'
    OR LOWER(name) LIKE '%bmw%'
    OR LOWER(description) LIKE '%vehicule%'
    OR LOWER(description) LIKE '%automobile%'
);

-- ============================================
-- FASHION (Mode)
-- ============================================
UPDATE products 
SET category = 'fashion'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%robe%'
    OR LOWER(name) LIKE '%chaussure%'
    OR LOWER(name) LIKE '%chemise%'
    OR LOWER(name) LIKE '%pantalon%'
    OR LOWER(name) LIKE '%jean%'
    OR LOWER(name) LIKE '%veste%'
    OR LOWER(name) LIKE '%sac%'
    OR LOWER(name) LIKE '%lunette%'
    OR LOWER(name) LIKE '%montre%'
    OR LOWER(name) LIKE '%bijou%'
    OR LOWER(name) LIKE '%t-shirt%'
    OR LOWER(name) LIKE '%short%'
    OR LOWER(name) LIKE '%basket%'
    OR LOWER(name) LIKE '%sneaker%'
    OR LOWER(description) LIKE '%mode%'
    OR LOWER(description) LIKE '%vetement%'
    OR LOWER(description) LIKE '%fashion%'
);

-- ============================================
-- ELECTRONICS (Électronique)
-- ============================================
UPDATE products 
SET category = 'electronics'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%iphone%'
    OR LOWER(name) LIKE '%samsung%'
    OR LOWER(name) LIKE '%telephone%'
    OR LOWER(name) LIKE '%téléphone%'
    OR LOWER(name) LIKE '%laptop%'
    OR LOWER(name) LIKE '%ordinateur%'
    OR LOWER(name) LIKE '%tablet%'
    OR LOWER(name) LIKE '%tablette%'
    OR LOWER(name) LIKE '%ecouteur%'
    OR LOWER(name) LIKE '%casque%'
    OR LOWER(name) LIKE '%cable%'
    OR LOWER(name) LIKE '%chargeur%'
    OR LOWER(name) LIKE '%tv%'
    OR LOWER(name) LIKE '%television%'
    OR LOWER(name) LIKE '%camera%'
    OR LOWER(name) LIKE '%appareil photo%'
    OR LOWER(description) LIKE '%electronique%'
    OR LOWER(description) LIKE '%electronic%'
);

-- ============================================
-- BEAUTY (Beauté)
-- ============================================
UPDATE products 
SET category = 'beauty'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%maquillage%'
    OR LOWER(name) LIKE '%parfum%'
    OR LOWER(name) LIKE '%creme%'
    OR LOWER(name) LIKE '%crème%'
    OR LOWER(name) LIKE '%lotion%'
    OR LOWER(name) LIKE '%shampooing%'
    OR LOWER(name) LIKE '%savon%'
    OR LOWER(name) LIKE '%beaute%'
    OR LOWER(name) LIKE '%beauté%'
    OR LOWER(name) LIKE '%coiffure%'
    OR LOWER(name) LIKE '%nail%'
    OR LOWER(name) LIKE '%vernis%'
    OR LOWER(description) LIKE '%beaute%'
    OR LOWER(description) LIKE '%cosmetique%'
);

-- ============================================
-- HOME (Maison)
-- ============================================
UPDATE products 
SET category = 'home'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%meuble%'
    OR LOWER(name) LIKE '%lit%'
    OR LOWER(name) LIKE '%table%'
    OR LOWER(name) LIKE '%chaise%'
    OR LOWER(name) LIKE '%cuisine%'
    OR LOWER(name) LIKE '%frigo%'
    OR LOWER(name) LIKE '%refrigerateur%'
    OR LOWER(name) LIKE '%four%'
    OR LOWER(name) LIKE '%micro-onde%'
    OR LOWER(name) LIKE '%decoration%'
    OR LOWER(name) LIKE '%décoration%'
    OR LOWER(name) LIKE '%lampe%'
    OR LOWER(name) LIKE '%tapis%'
    OR LOWER(name) LIKE '%rideau%'
    OR LOWER(description) LIKE '%maison%'
    OR LOWER(description) LIKE '%home%'
    OR LOWER(description) LIKE '%interieur%'
);

-- ============================================
-- KIDS (Enfants)
-- ============================================
UPDATE products 
SET category = 'kids'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%enfant%'
    OR LOWER(name) LIKE '%bébé%'
    OR LOWER(name) LIKE '%bebe%'
    OR LOWER(name) LIKE '%jouet%'
    OR LOWER(name) LIKE '%jeu%'
    OR LOWER(name) LIKE '%poussette%'
    OR LOWER(name) LIKE '%biberon%'
    OR LOWER(name) LIKE '%couche%'
    OR LOWER(name) LIKE '%peluche%'
    OR LOWER(description) LIKE '%enfant%'
    OR LOWER(description) LIKE '%kid%'
);

-- ============================================
-- INDUSTRY (Industrie)
-- ============================================
UPDATE products 
SET category = 'industry'
WHERE category IS NULL 
AND (
    LOWER(name) LIKE '%generateur%'
    OR LOWER(name) LIKE '%générateur%'
    OR LOWER(name) LIKE '%groupe electrogene%'
    OR LOWER(name) LIKE '%groupe électrogène%'
    OR LOWER(name) LIKE '%outil%'
    OR LOWER(name) LIKE '%machine%'
    OR LOWER(name) LIKE '%moteur%'
    OR LOWER(name) LIKE '%pompe%'
    OR LOWER(name) LIKE '%compresseur%'
    OR LOWER(name) LIKE '%soudure%'
    OR LOWER(name) LIKE '%industriel%'
    OR LOWER(description) LIKE '%industrie%'
    OR LOWER(description) LIKE '%industrial%'
);

-- ============================================
-- STATISTICS
-- ============================================
SELECT 
    category,
    COUNT(*) as product_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM products), 2) as percentage
FROM products
GROUP BY category
ORDER BY product_count DESC;

-- Show uncategorized products
SELECT COUNT(*) as uncategorized_products
FROM products
WHERE category IS NULL;

-- Sample uncategorized products for manual review
SELECT id, name, LEFT(description, 100) as description_preview
FROM products
WHERE category IS NULL
LIMIT 20;
