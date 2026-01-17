-- =====================================================
-- Migration 004: Créer table pour tracking des produits visités
-- =====================================================

-- 1. Créer la table user_product_views
CREATE TABLE IF NOT EXISTS user_product_views (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Créer des index pour améliorer les performances
-- Index pour récupérer rapidement les produits visités par un utilisateur (tri par date)
CREATE INDEX IF NOT EXISTS idx_user_product_views_user_date 
ON user_product_views(user_id, viewed_at DESC);

-- Index pour vérifier si un produit a déjà été vu (pour éviter doublons si nécessaire)
CREATE INDEX IF NOT EXISTS idx_user_product_views_unique 
ON user_product_views(user_id, product_id);

-- Index pour les statistiques de popularité des produits
CREATE INDEX IF NOT EXISTS idx_user_product_views_product 
ON user_product_views(product_id, viewed_at DESC);

-- 3. Commentaires
COMMENT ON TABLE user_product_views IS 'Tracking des produits visités par les utilisateurs pour historique de navigation';
COMMENT ON COLUMN user_product_views.user_id IS 'ID de l''utilisateur qui a consulté le produit';
COMMENT ON COLUMN user_product_views.product_id IS 'ID du produit consulté';
COMMENT ON COLUMN user_product_views.viewed_at IS 'Date et heure de la consultation';

-- 4. Afficher un résumé de la migration
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 004 terminée!';
    RAISE NOTICE '📊 Table user_product_views créée';
    RAISE NOTICE '🔍 Index créés pour performance optimale';
    RAISE NOTICE '💡 Les vues de produit seront maintenant trackées';
END $$;
