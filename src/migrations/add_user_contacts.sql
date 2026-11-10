-- Migration : liste de contacts Oli de chaque utilisateur
-- Le serveur applique aussi ces changements au démarrage (server.js).

CREATE TABLE IF NOT EXISTS user_contacts (
    owner_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (owner_id, contact_id),
    CHECK (owner_id <> contact_id)
);

CREATE INDEX IF NOT EXISTS idx_user_contacts_contact ON user_contacts(contact_id);
