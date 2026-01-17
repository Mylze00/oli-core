-- Migration pour ajouter la table des adresses de livraison

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

-- Index pour accélérer la recherche des adresses d'un user
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
