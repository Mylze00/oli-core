-- Migration consolidée pour assurer que toutes les colonnes et tables nécessaires existent
-- À exécuter en production si erreurs persistent

-- 1. S'assurer que la table addresses existe
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50), -- "Maison", "Bureau", "Autre"
    address TEXT NOT NULL, -- Texte complet de l'adresse
    city VARCHAR(100),
    phone VARCHAR(20), -- Contact pour la livraison
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. S'assurer que la colonne last_profile_update existe
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS last_profile_update TIMESTAMP DEFAULT NULL;

-- 3. Index pour performances
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

-- 4. Vérification
DO $$
DECLARE
    addr_count INTEGER;
    user_column_exists BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO addr_count FROM information_schema.tables 
    WHERE table_name = 'addresses';
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'last_profile_update'
    ) INTO user_column_exists;
    
    RAISE NOTICE '✅ Table addresses: %', CASE WHEN addr_count > 0 THEN 'OK' ELSE 'MANQUANTE' END;
    RAISE NOTICE '✅ Colonne last_profile_update: %', CASE WHEN user_column_exists THEN 'OK' ELSE 'MANQUANTE' END;
END $$;
