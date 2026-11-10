-- Migration : commentaires et signalements des vidéos Live Shopping
-- Le service video-sales crée aussi ces tables au démarrage (ensureTables).

CREATE TABLE IF NOT EXISTS video_comments (
  id SERIAL PRIMARY KEY,
  video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  content VARCHAR(500) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_video_comments_video ON video_comments(video_id, created_at DESC);

CREATE TABLE IF NOT EXISTS video_reports (
  id SERIAL PRIMARY KEY,
  video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
  reporter_id INTEGER NOT NULL REFERENCES users(id),
  reason VARCHAR(30) NOT NULL,
  details TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  reviewed_by INTEGER REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS idx_video_reports_status ON video_reports(status, created_at DESC);

ALTER TABLE video_comments
  ADD COLUMN IF NOT EXISTS parent_id INTEGER REFERENCES video_comments(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

CREATE INDEX IF NOT EXISTS idx_video_comments_parent ON video_comments(parent_id);

CREATE TABLE IF NOT EXISTS video_comment_reactions (
  comment_id INTEGER NOT NULL REFERENCES video_comments(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  value SMALLINT NOT NULL CHECK (value IN (1, -1)),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

ALTER TABLE video_comments
  ADD COLUMN IF NOT EXISTS is_sticker BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS stickers (
  id SERIAL PRIMARY KEY,
  pack VARCHAR(60) NOT NULL DEFAULT 'Oli',
  name VARCHAR(60) NOT NULL,
  image_url TEXT NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
