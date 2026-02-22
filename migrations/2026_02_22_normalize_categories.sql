-- Migration: Normalize category values (FR labels → EN keys)
-- Date: 2026-02-22
-- Description: Converts French category labels stored by the mobile app
--              into standardized English keys used by the rest of the system.
--              This is a safe, non-destructive migration: only transforms values.

-- ============================================
-- NORMALIZE FRENCH LABELS → ENGLISH KEYS
-- ============================================

UPDATE products SET category = 'electronics'  WHERE LOWER(category) = LOWER('Électronique');
UPDATE products SET category = 'beauty'       WHERE LOWER(category) = LOWER('Beauté');
UPDATE products SET category = 'home'         WHERE LOWER(category) = LOWER('Maison');
UPDATE products SET category = 'fashion'      WHERE LOWER(category) = LOWER('Mode');
UPDATE products SET category = 'vehicles'     WHERE LOWER(category) = LOWER('Véhicules');
UPDATE products SET category = 'industry'     WHERE LOWER(category) = LOWER('Industrie');
UPDATE products SET category = 'sports'       WHERE LOWER(category) = LOWER('Sports');
UPDATE products SET category = 'toys'         WHERE LOWER(category) = LOWER('Jouets');
UPDATE products SET category = 'health'       WHERE LOWER(category) = LOWER('Santé');
UPDATE products SET category = 'construction' WHERE LOWER(category) = LOWER('Construction');
UPDATE products SET category = 'tools'        WHERE LOWER(category) = LOWER('Outils');
UPDATE products SET category = 'office'       WHERE LOWER(category) = LOWER('Bureau');
UPDATE products SET category = 'garden'       WHERE LOWER(category) = LOWER('Jardin');
UPDATE products SET category = 'pets'         WHERE LOWER(category) = LOWER('Animaux');
UPDATE products SET category = 'baby'         WHERE LOWER(category) = LOWER('Bébé');
UPDATE products SET category = 'food'         WHERE LOWER(category) = LOWER('Alimentation');
UPDATE products SET category = 'security'     WHERE LOWER(category) = LOWER('Sécurité');
UPDATE products SET category = 'other'        WHERE LOWER(category) = LOWER('Autres');

-- Normalize any remaining non-standard values to 'other'
UPDATE products SET category = 'other'
WHERE category IS NOT NULL
  AND category NOT IN (
    'industry','home','vehicles','fashion','electronics','sports',
    'beauty','toys','health','construction','tools','office',
    'garden','pets','baby','food','security','other'
  );

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 
    category,
    COUNT(*) as product_count,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM products WHERE category IS NOT NULL), 0), 2) as percentage
FROM products
WHERE category IS NOT NULL
GROUP BY category
ORDER BY product_count DESC;

-- Count remaining uncategorized
SELECT COUNT(*) as uncategorized_products
FROM products
WHERE category IS NULL;
