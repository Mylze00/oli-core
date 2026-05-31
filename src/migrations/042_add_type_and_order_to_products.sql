-- Migration: Ajouter product_type et sort_order à la table products

-- 1. Ajouter les colonnes (sans bloquer la table longtemps)
ALTER TABLE products ADD COLUMN product_type VARCHAR(100) DEFAULT 'Standard';
ALTER TABLE products ADD COLUMN sort_order INTEGER DEFAULT 0;

-- 2. Ajouter les index pour optimiser les requêtes de tri
CREATE INDEX idx_products_type ON products(product_type);
CREATE INDEX idx_products_sort_order ON products(sort_order);
CREATE INDEX idx_products_type_category ON products(product_type, category);
CREATE INDEX idx_products_category_order ON products(category, sort_order);

-- 3. Mettre à jour l'index existant ou en créer un composite si nécessaire (optionnel)
-- Un index sur (category, sort_order, name) peut être très utile
CREATE INDEX idx_products_cat_ord_name ON products(category, sort_order, name);
