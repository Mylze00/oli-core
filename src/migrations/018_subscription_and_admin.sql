-- Migration: Add Subscription fields and Admin flag
-- Description: Adds subscription management fields to users table and seeds the master admin.

-- 1. Add columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS subscription_plan VARCHAR(20) DEFAULT 'none', -- 'none', 'certified', 'enterprise'
ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(20) DEFAULT 'inactive', -- 'active', 'expired', 'inactive'
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMP,
ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) DEFAULT 'ordinary';

-- 2. Update user_identity_documents to allow new types if constrainst exist (usually handled by app logic but good to document)
-- No enum constraint modification needed usually for VARCHAR, but we note the types: 'rccm', 'tax_id', 'business_proof'

-- 3. Seed Master Admin
UPDATE users 
SET is_admin = TRUE, 
    account_type = 'admin' -- Optional, if we want to reflect it here too
WHERE phone LIKE '%827088682' OR phone LIKE '%243827088682';

-- If admin user doesn't exist, we can't easily insert it without other required fields (password hash etc). 
-- Logic implies the user likely already exists or will sign up. 
-- We can create a Trigger to auto-promote this specific number if it joins later? 
-- For now, simple UPDATE is safer.

-- 4. Create Service Plans table (Optional, but good for price management) - skipping for now, hardcoded in verified logic as per user request.
