-- Migration 008: Support Dashboard Admin
-- Ajoute colonne is_suspended pour suspendre utilisateurs

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_users_suspended 
ON users(is_suspended) 
WHERE is_suspended = TRUE;

-- Vérification
DO $$
DECLARE
    has_suspended BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'is_suspended'
    ) INTO has_suspended;
    
    RAISE NOTICE '✅ Migration 008 terminée!';
    RAISE NOTICE 'users.is_suspended: %', CASE WHEN has_suspended THEN '✅ OK' ELSE '❌ MANQUANT' END;
END $$;
