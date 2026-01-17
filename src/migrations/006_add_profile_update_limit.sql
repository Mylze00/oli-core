-- Migration pour ajouter la limite de mise à jour du profil (2 semaines)
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_profile_update TIMESTAMP DEFAULT NULL;

-- Index pour optimiser si besoin (optionnel)
-- CREATE INDEX IF NOT EXISTS idx_users_last_profile_update ON users(last_profile_update);
