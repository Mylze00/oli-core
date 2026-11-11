-- Migration : modifier, supprimer et masquer un message de la messagerie
-- Le serveur applique aussi ces changements au démarrage (server.js).

-- Date de la dernière modification du texte par son auteur
ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

-- Date de la suppression pour tous : le contenu est effacé, la ligne reste pour l'historique
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Messages qu'un participant a supprimés pour lui seul
CREATE TABLE IF NOT EXISTS message_hidden_for (
    message_id INT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hidden_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);
