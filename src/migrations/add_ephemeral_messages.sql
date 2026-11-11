-- Migration : messages éphémères, réglés pour toute la conversation
-- Le serveur applique aussi ces changements au démarrage (server.js).

-- Durée de vie des nouveaux messages de la conversation (NULL = désactivé)
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS ephemeral_seconds INT;

-- Moment où le message disparaît de la discussion
ALTER TABLE messages ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_messages_expires_at ON messages (expires_at) WHERE expires_at IS NOT NULL;

-- Chaque message inséré prend la durée de sa conversation, quel que soit le chemin d'envoi.
-- Un billet de cash reste : c'est la trace d'un transfert d'argent.
CREATE OR REPLACE FUNCTION set_message_expiry() RETURNS trigger AS $$
DECLARE
    lifetime INT;
BEGIN
    IF NEW.expires_at IS NULL AND NOT COALESCE(NEW.metadata ? 'cash_transfer', FALSE) THEN
        SELECT ephemeral_seconds INTO lifetime FROM conversations WHERE id = NEW.conversation_id;
        IF lifetime IS NOT NULL THEN
            NEW.expires_at := NOW() + make_interval(secs => lifetime);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_message_expiry ON messages;
CREATE TRIGGER trg_set_message_expiry BEFORE INSERT ON messages
    FOR EACH ROW EXECUTE FUNCTION set_message_expiry();
