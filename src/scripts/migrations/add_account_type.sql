-- ============================================
-- Ajouter colonne account_type aux utilisateurs
-- Types: ordinaire, certifie, premium, entreprise
-- ============================================

-- Ajouter la colonne account_type si elle n'existe pas
ALTER TABLE users ADD COLUMN IF NOT EXISTS account_type VARCHAR(30) DEFAULT 'ordinaire';

-- Ajouter contrainte de vérification
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_account_type_check;
ALTER TABLE users ADD CONSTRAINT users_account_type_check 
    CHECK (account_type IN ('ordinaire', 'certifie', 'premium', 'entreprise'));

-- Ajouter has_certified_shop pour marquer si l'utilisateur a une boutique certifiée
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_certified_shop BOOLEAN DEFAULT FALSE;

-- Commentaires
COMMENT ON COLUMN users.account_type IS 'Type de compte: ordinaire, certifie, premium, entreprise';
COMMENT ON COLUMN users.has_certified_shop IS 'Indique si le user possède une boutique certifiée';
