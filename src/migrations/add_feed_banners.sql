-- Migration : bannières du fil d'accueil (insérées entre les blocs du Top Classement)
-- Une bannière est une image (avec lien facultatif) ou une vidéo courte compressée.
-- Le serveur applique aussi cette migration au démarrage (server.js).

CREATE TABLE IF NOT EXISTS feed_banners (
    id SERIAL PRIMARY KEY,
    media_type VARCHAR(10) NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
    media_url TEXT NOT NULL,          -- image, ou vidéo déjà compressée (URL Cloudinary transformée)
    poster_url TEXT,                  -- vignette de la vidéo (affichée pendant son chargement)
    link_url TEXT,                    -- destination au toucher (facultatif)
    title VARCHAR(255),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_banners_active_order
    ON feed_banners (is_active, display_order);
