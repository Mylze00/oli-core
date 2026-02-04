-- =====================================================
-- CORRECTION: Création de la table user_avatar_history
-- À exécuter sur la base de données de production
-- =====================================================

-- 1. Table pour l'historique des avatars
CREATE TABLE IF NOT EXISTS user_avatar_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    avatar_url TEXT NOT NULL,
    storage_provider VARCHAR(20) DEFAULT 'cloudinary',
    file_size_bytes INTEGER,
    mime_type VARCHAR(50),
    is_current BOOLEAN DEFAULT FALSE,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_avatar_history_user ON user_avatar_history(user_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_avatar_history_current ON user_avatar_history(user_id) WHERE is_current = TRUE;

-- 3. Commentaire
COMMENT ON TABLE user_avatar_history IS 'Historique complet des avatars utilisateur avec backup automatique';

-- 4. Migration des avatars existants
INSERT INTO user_avatar_history (user_id, avatar_url, storage_provider, is_current, uploaded_at, created_at)
SELECT 
    id,
    avatar_url,
    CASE 
        WHEN avatar_url LIKE '%cloudinary%' THEN 'cloudinary'
        WHEN avatar_url LIKE '%s3%' THEN 's3'
        ELSE 'local'
    END as storage_provider,
    TRUE,
    COALESCE(created_at, NOW()),
    NOW()
FROM users
WHERE avatar_url IS NOT NULL AND avatar_url != ''
ON CONFLICT DO NOTHING;

-- =====================================================
-- VÉRIFICATION
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_avatar_history;
    RAISE NOTICE '✅ Table user_avatar_history créée avec succès!';
    RAISE NOTICE '📊 Avatars migrés: %', v_count;
END $$;
