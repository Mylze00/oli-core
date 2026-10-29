-- Migration: Add display_order to ads table
ALTER TABLE ads ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Create index on display_order and is_active for faster carousel queries
CREATE INDEX IF NOT EXISTS idx_ads_display_order ON ads(display_order ASC, created_at DESC);
