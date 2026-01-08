-- Migration: Ajouter product_id à la table conversations
-- Pour lier les conversations aux produits

-- Ajouter la colonne product_id
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS product_id INTEGER REFERENCES products(id) ON DELETE SET NULL;

-- Créer un index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_conversations_product_id ON conversations(product_id);

-- Commentaire de documentation
COMMENT ON COLUMN conversations.product_id IS 'ID du produit lié à cette conversation (optionnel, pour les discussions vendeur-acheteur)';
