-- Ajout de la colonne reply_to_id pour les réponses
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS reply_to_id INTEGER REFERENCES messages(id) ON DELETE SET NULL;

-- Index pour optimiser les jointures
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON messages(reply_to_id);
