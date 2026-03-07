-- Migration 030 : Ajout de la colonne subcategory à la table products
-- Pour l'auto-catégorisation basée sur l'analyse du nom de produit

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS subcategory VARCHAR(80);

-- Index pour optimiser les requêtes filtrées par sous-catégorie
CREATE INDEX IF NOT EXISTS idx_products_subcategory
  ON products(subcategory)
  WHERE subcategory IS NOT NULL;

-- Index composite pour filtres catégorie + sous-catégorie (ex: "electronics > smartphones")
CREATE INDEX IF NOT EXISTS idx_products_category_subcategory
  ON products(category, subcategory)
  WHERE subcategory IS NOT NULL;

-- Commentaire de documentation
COMMENT ON COLUMN products.subcategory IS
  'Sous-catégorie auto-détectée à partir du nom du produit. Ex: smartphones, tv, robes, meubles...';
