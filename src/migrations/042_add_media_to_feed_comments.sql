-- Migration: Ajout des médias aux commentaires du Feed

ALTER TABLE feed_comments 
ADD COLUMN IF NOT EXISTS media_url VARCHAR(255),
ADD COLUMN IF NOT EXISTS media_type VARCHAR(20) DEFAULT 'text';
