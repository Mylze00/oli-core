-- Migration 036: Activer la recherche floue (pg_trgm)
-- Permet de trouver des produits malgré des fautes de frappe
-- Exemple: "chossure" → retrouve "chaussures"

-- 1. Activer l'extension pg_trgm (trigrammes)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Créer un index GIN trigram sur le nom des produits (le plus important)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_name_trgm
    ON products USING GIN (name gin_trgm_ops);

-- 3. Créer un index GIN trigram sur la description (pour la recherche dans les descriptions)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_description_trgm
    ON products USING GIN (description gin_trgm_ops);

-- 4. Créer un index GIN trigram sur la catégorie
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_category_trgm
    ON products USING GIN (category gin_trgm_ops);

-- 5. Définir le seuil de similarité global (0.2 = assez permissif pour les fautes)
-- (Ce paramètre est par session, on le configure dans le service Node.js)

SELECT 'pg_trgm activé avec succès. Recherche tolérante aux fautes opérationnelle.' AS status;
