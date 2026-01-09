ALTER TABLE users
ADD COLUMN IF NOT EXISTS id_oli VARCHAR(20) UNIQUE;

-- Create an index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_id_oli ON users(id_oli);
