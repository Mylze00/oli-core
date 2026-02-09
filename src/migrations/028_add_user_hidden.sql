-- Migration 028: Ajout colonne is_hidden pour masquer utilisateurs du marketplace
-- Cette colonne permet à l'admin de masquer un utilisateur et ses produits

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

-- Index partiel pour les utilisateurs masqués
CREATE INDEX IF NOT EXISTS idx_users_is_hidden 
ON users(is_hidden) 
WHERE is_hidden = TRUE;

-- Vérification
DO $$
DECLARE
    has_hidden BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'is_hidden'
    ) INTO has_hidden;
    RAISE NOTICE 'users.is_hidden: %', CASE WHEN has_hidden THEN '✅ OK' ELSE '❌ MANQUANT' END;
END $$;
