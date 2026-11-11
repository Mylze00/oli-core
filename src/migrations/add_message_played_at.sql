-- Migration : moment où le destinataire écoute un vocal
-- Le serveur applique aussi ces changements au démarrage (server.js).

ALTER TABLE messages ADD COLUMN IF NOT EXISTS played_at TIMESTAMPTZ;
