-- Migration 033: Création des tables pour le Live Shopping (vidéos de vente)

-- Table principale des vidéos de vente
CREATE TABLE IF NOT EXISTS video_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  product_id UUID REFERENCES products(id),
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  title VARCHAR(150),
  description TEXT,
  duration_seconds INTEGER,
  views_count INTEGER DEFAULT 0,
  likes_count INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table des likes (1 like par user par vidéo)
CREATE TABLE IF NOT EXISTS video_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, user_id)
);

-- Table pour traquer les vues uniques (anti-spam)
CREATE TABLE IF NOT EXISTS video_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, user_id)
);

-- Index pour le feed et les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_video_sales_status ON video_sales(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_sales_user ON video_sales(user_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_video ON video_likes(video_id);
CREATE INDEX IF NOT EXISTS idx_video_views_video ON video_views(video_id);
