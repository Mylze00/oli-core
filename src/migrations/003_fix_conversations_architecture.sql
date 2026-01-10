-- =====================================================
-- Migration 003: Corriger l'architecture des conversations
-- Passer de user1_id/user2_id vers conversation_participants
-- =====================================================

-- 1. Ajouter les colonnes user1_id et user2_id si elles n'existent pas déjà
-- (Pour migration des données existantes)
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS user1_id INTEGER REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS user2_id INTEGER REFERENCES users(id) ON DELETE CASCADE;

-- 2. Créer un index temporaire pour la performance de migration
CREATE INDEX IF NOT EXISTS idx_conversations_users_temp ON conversations(user1_id, user2_id);

-- 3. Migrer les données existantes vers conversation_participants
-- On s'assure de ne pas créer de doublons
INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
SELECT 
    c.id AS conversation_id,
    c.user1_id AS user_id,
    c.updated_at AS joined_at
FROM conversations c
WHERE c.user1_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM conversation_participants cp
    WHERE cp.conversation_id = c.id AND cp.user_id = c.user1_id
  );

INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
SELECT 
    c.id AS conversation_id,
    c.user2_id AS user_id,
    c.updated_at AS joined_at
FROM conversations c
WHERE c.user2_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM conversation_participants cp
    WHERE cp.conversation_id = c.id AND cp.user_id = c.user2_id
  );

-- 4. Ajouter des commentaires pour indiquer que les colonnes sont deprecated
COMMENT ON COLUMN conversations.user1_id IS 'DEPRECATED - Utiliser conversation_participants. Conservé temporairement pour compatibilité.';
COMMENT ON COLUMN conversations.user2_id IS 'DEPRECATED - Utiliser conversation_participants. Conservé temporairement pour compatibilité.';

-- 5. Créer des index supplémentaires pour la performance
CREATE INDEX IF NOT EXISTS idx_conversation_participants_conversation 
ON conversation_participants(conversation_id);

CREATE INDEX IF NOT EXISTS idx_conversation_participants_both 
ON conversation_participants(conversation_id, user_id);

-- 6. Ajouter une colonne created_at pour conversations si elle n'existe pas
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

-- 7. Mettre à jour les timestamps existants si nécessaire
UPDATE conversations 
SET created_at = updated_at 
WHERE created_at IS NULL;

-- 8. Afficher un résumé de la migration
DO $$
DECLARE
    total_conversations INTEGER;
    total_participants INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_conversations FROM conversations;
    SELECT COUNT(*) INTO total_participants FROM conversation_participants;
    
    RAISE NOTICE '✅ Migration 003 terminée!';
    RAISE NOTICE '📊 Total conversations: %', total_conversations;
    RAISE NOTICE '👥 Total participants: %', total_participants;
    RAISE NOTICE '⚠️  Les colonnes user1_id et user2_id sont maintenant DEPRECATED';
    RAISE NOTICE '💡 Mettez à jour votre code pour utiliser conversation_participants';
END $$;
