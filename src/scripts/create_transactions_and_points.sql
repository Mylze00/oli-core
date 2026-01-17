-- Ajout de la colonne points de fidélité
ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_points INTEGER DEFAULT 0;

-- Création de la table des transactions (Wallet & Historique)
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'deposit', 'withdrawal', 'purchase', 'sale', 'refund'
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    reference VARCHAR(100), -- ex: ID Mobile Money ou ID Commande
    status VARCHAR(20) DEFAULT 'completed', -- 'pending', 'completed', 'failed'
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
