-- Évolution Messagerie (Telegram-like)

-- Ajout des colonnes media_url et forwarded_from_id
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS media_url VARCHAR(1000),
ADD COLUMN IF NOT EXISTS forwarded_from_id INTEGER REFERENCES messages(id) ON DELETE SET NULL;

-- Table d'historique des appels
CREATE TABLE IF NOT EXISTS call_history (
    id SERIAL PRIMARY KEY,
    caller_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL DEFAULT 'audio', -- 'audio' ou 'video'
    start_time TIMESTAMP NOT NULL DEFAULT NOW(),
    duration INTEGER DEFAULT 0, -- en secondes
    status VARCHAR(20) NOT NULL DEFAULT 'completed', -- 'missed', 'completed', 'rejected', 'ongoing'
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_history_caller ON call_history(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_history_receiver ON call_history(receiver_id);
