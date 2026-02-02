-- =====================================================
-- CORRECTION COMPLÈTE: Tables manquantes Migration 010
-- À exécuter sur la base de données de production Render
-- =====================================================

-- 1. Table user_avatar_history (si pas encore créée)
CREATE TABLE IF NOT EXISTS user_avatar_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    avatar_url TEXT NOT NULL,
    storage_provider VARCHAR(20) DEFAULT 'cloudinary',
    file_size_bytes INTEGER,
    mime_type VARCHAR(50),
    is_current BOOLEAN DEFAULT FALSE,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_avatar_history_user ON user_avatar_history(user_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_avatar_history_current ON user_avatar_history(user_id) WHERE is_current = TRUE;

-- 2. Table user_behavior_events
CREATE TABLE IF NOT EXISTS user_behavior_events (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    event_type VARCHAR(50) NOT NULL,
    event_category VARCHAR(30),
    event_data JSONB,
    
    session_id VARCHAR(100),
    device_type VARCHAR(20),
    platform VARCHAR(20),
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    city VARCHAR(100),
    country VARCHAR(3),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_behavior_user_time ON user_behavior_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_behavior_type ON user_behavior_events(event_type);
CREATE INDEX IF NOT EXISTS idx_behavior_session ON user_behavior_events(session_id);

-- 3. Table user_sessions
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    device_type VARCHAR(20),
    platform VARCHAR(20),
    app_version VARCHAR(20),
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    city VARCHAR(100),
    country VARCHAR(3),
    
    started_at TIMESTAMP DEFAULT NOW(),
    last_activity_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id, started_at DESC);

-- 4. Table user_verification_levels
CREATE TABLE IF NOT EXISTS user_verification_levels (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    phone_verified BOOLEAN DEFAULT FALSE,
    email_verified BOOLEAN DEFAULT FALSE,
    identity_verified BOOLEAN DEFAULT FALSE,
    address_verified BOOLEAN DEFAULT FALSE,
    
    verification_level VARCHAR(20) DEFAULT 'unverified',
    trust_score INTEGER DEFAULT 0,
    
    phone_verified_at TIMESTAMP,
    email_verified_at TIMESTAMP,
    identity_verified_at TIMESTAMP,
    address_verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verification_level ON user_verification_levels(verification_level);

-- 5. Table user_trust_scores
CREATE TABLE IF NOT EXISTS user_trust_scores (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    identity_score INTEGER DEFAULT 0,
    transaction_score INTEGER DEFAULT 50,
    behavior_score INTEGER DEFAULT 50,
    social_score INTEGER DEFAULT 50,
    overall_score INTEGER DEFAULT 0,
    
    fraud_risk_level VARCHAR(20) DEFAULT 'low',
    is_flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    score_history JSONB,
    
    last_calculated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trust_overall_score ON user_trust_scores(overall_score DESC);

-- 6. Table user_identity_documents
CREATE TABLE IF NOT EXISTS user_identity_documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    document_type VARCHAR(50) NOT NULL,
    document_number VARCHAR(100),
    issuing_country VARCHAR(3),
    issue_date DATE,
    expiry_date DATE,
    
    front_image_url TEXT NOT NULL,
    back_image_url TEXT,
    selfie_url TEXT,
    
    verification_status VARCHAR(20) DEFAULT 'pending',
    verified_by INTEGER REFERENCES users(id),
    verified_at TIMESTAMP,
    rejection_reason TEXT,
    
    submitted_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_document UNIQUE(user_id, document_type)
);

CREATE INDEX IF NOT EXISTS idx_identity_docs_user ON user_identity_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_identity_docs_status ON user_identity_documents(verification_status);

-- 7. Table addresses (si manquante)
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50),
    address TEXT NOT NULL,
    city VARCHAR(100),
    phone VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    verification_method VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

-- =====================================================
-- INITIALISATION POUR UTILISATEURS EXISTANTS
-- =====================================================

-- Initialiser verification_levels pour tous les utilisateurs
INSERT INTO user_verification_levels (user_id, phone_verified, verification_level)
SELECT id, TRUE, 'basic' FROM users
ON CONFLICT (user_id) DO NOTHING;

-- Initialiser trust_scores pour tous les utilisateurs  
INSERT INTO user_trust_scores (user_id, identity_score, transaction_score, behavior_score, social_score, overall_score)
SELECT id, 0, 50, 50, 50, 37 FROM users
ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- VÉRIFICATION FINALE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Toutes les tables de migration 010 ont été créées!';
    RAISE NOTICE '📊 Tables créées:';
    RAISE NOTICE '   - user_avatar_history';
    RAISE NOTICE '   - user_behavior_events';
    RAISE NOTICE '   - user_sessions';
    RAISE NOTICE '   - user_verification_levels';
    RAISE NOTICE '   - user_trust_scores';
    RAISE NOTICE '   - user_identity_documents';
    RAISE NOTICE '   - addresses';
END $$;
