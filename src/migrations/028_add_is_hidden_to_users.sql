/**
 * Migration 028: Add is_hidden column to users table
 * Allows admins to hide users and their products from the marketplace
 */

-- Add is_hidden column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_users_is_hidden ON users(is_hidden) WHERE is_hidden = TRUE;

-- Add comment
COMMENT ON COLUMN users.is_hidden IS 'When TRUE, user and their products are hidden from marketplace (but account is not blocked)';
