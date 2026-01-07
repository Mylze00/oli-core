-- ====================================
-- OLI - Script de création de la table Users
-- ====================================

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100),
    id_oli VARCHAR(50) UNIQUE, -- Handle unique (ex: @paolice)
    email VARCHAR(100),
    wallet DECIMAL(10,2) DEFAULT 0.00,
    avatar_url TEXT,
    
    -- Sécurité / Auth
    is_verified BOOLEAN DEFAULT FALSE,
    otp_code VARCHAR(10),
    otp_expires_at TIMESTAMP,
    
    -- Metadonnées
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
