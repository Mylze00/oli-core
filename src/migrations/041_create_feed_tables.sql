-- Migration: Création des tables pour le Fil d'Actualité (Feed)
-- Permet aux utilisateurs de publier des statuts, photos et vidéos.

-- Table principale des publications
CREATE TABLE IF NOT EXISTS feed_posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT,
    media_url VARCHAR(255),
    media_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'video'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index pour optimiser le tri par date d'ajout
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON feed_posts(created_at DESC);

-- Table des "J'aime" (Likes)
CREATE TABLE IF NOT EXISTS feed_likes (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id) -- Un utilisateur ne peut liker qu'une seule fois un post
);

-- Table des Commentaires
CREATE TABLE IF NOT EXISTS feed_comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index pour charger rapidement les commentaires d'un post
CREATE INDEX IF NOT EXISTS idx_feed_comments_post_id ON feed_comments(post_id);
