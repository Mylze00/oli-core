-- Migration : moment où un message atteint l'appareil du destinataire
-- Le serveur applique aussi ces changements au démarrage (server.js).

ALTER TABLE messages ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_messages_undelivered
    ON messages (conversation_id)
    WHERE delivered_at IS NULL;
