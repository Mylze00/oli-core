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
