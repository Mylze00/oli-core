-- =====================================================
-- MIGRATION: Architecture Unifiée de l'Identité Utilisateur (CORRIGÉE)
-- Version: 1.2
-- Date: 2026-01-25
-- Description: Création des tables pour la gestion complète
--              du cycle de vie utilisateur (certification,
--              comportement, trust score)
-- IMPORTANT: users.id est de type INTEGER (Legacy)
-- =====================================================

-- =====================================================
-- PARTIE 1: TABLES MANQUANTES (addresses, user_product_views)
-- =====================================================

-- 1. Table des adresses de livraison
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50),
    address TEXT NOT NULL,
    city VARCHAR(100),
    phone VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Nouvelles colonnes GPS et vérification
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    verification_method VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ensure columns exist even if table was already present
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS latitude DECIMAL(10,8);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS longitude DECIMAL(11,8);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS verification_method VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

COMMENT ON TABLE addresses IS 'Adresses de livraison des utilisateurs avec GPS et vérification';
COMMENT ON COLUMN addresses.verification_method IS 'Méthode: gps, manual, delivery_confirmation';

-- =====================================================

-- 2. Table pour tracking des produits visités
CREATE TABLE IF NOT EXISTS user_product_views (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    
    -- Nouvelles colonnes pour contexte enrichi
    session_id VARCHAR(100),
    view_duration_seconds INTEGER,
    source VARCHAR(50),
    device_type VARCHAR(20),
    interactions JSONB,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ensure columns exist for user_product_views
ALTER TABLE user_product_views ADD COLUMN IF NOT EXISTS session_id VARCHAR(100);
ALTER TABLE user_product_views ADD COLUMN IF NOT EXISTS view_duration_seconds INTEGER;
ALTER TABLE user_product_views ADD COLUMN IF NOT EXISTS source VARCHAR(50);
ALTER TABLE user_product_views ADD COLUMN IF NOT EXISTS device_type VARCHAR(20);
ALTER TABLE user_product_views ADD COLUMN IF NOT EXISTS interactions JSONB;

CREATE INDEX IF NOT EXISTS idx_user_product_views_user_date ON user_product_views(user_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_product_views_unique ON user_product_views(user_id, product_id);
CREATE INDEX IF NOT EXISTS idx_user_product_views_product ON user_product_views(product_id, viewed_at DESC);

COMMENT ON TABLE user_product_views IS 'Tracking des produits visités par les utilisateurs';
COMMENT ON COLUMN user_product_views.source IS 'Source: search, category, recommendation, direct';

-- =====================================================
-- PARTIE 2: NOUVELLES TABLES POUR L'IDENTITÉ
-- =====================================================

-- 1. Table pour les pièces d'identité
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

COMMENT ON TABLE user_identity_documents IS 'Stockage sécurisé des pièces d''identité pour la certification KYC';

-- =====================================================

-- 2. Table pour les niveaux de vérification
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
CREATE INDEX IF NOT EXISTS idx_trust_score ON user_verification_levels(trust_score DESC);

COMMENT ON TABLE user_verification_levels IS 'Niveaux de vérification et trust score par utilisateur';

-- =====================================================

-- 3. Table pour les événements comportementaux
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
CREATE INDEX IF NOT EXISTS idx_behavior_category ON user_behavior_events(event_category);
CREATE INDEX IF NOT EXISTS idx_behavior_recent ON user_behavior_events(user_id, created_at DESC) 
WHERE created_at > NOW() - INTERVAL '30 days';

COMMENT ON TABLE user_behavior_events IS 'Tracking de tous les événements utilisateur pour analyse comportementale';

-- =====================================================

-- 4. Table pour les sessions utilisateur
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
CREATE INDEX IF NOT EXISTS idx_sessions_active ON user_sessions(user_id) WHERE ended_at IS NULL;

COMMENT ON TABLE user_sessions IS 'Tracking des sessions utilisateur avec durée et localisation';

-- =====================================================

-- 5. Table pour les scores de confiance
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
CREATE INDEX IF NOT EXISTS idx_trust_fraud_risk ON user_trust_scores(fraud_risk_level);
CREATE INDEX IF NOT EXISTS idx_trust_flagged ON user_trust_scores(is_flagged) WHERE is_flagged = TRUE;

COMMENT ON TABLE user_trust_scores IS 'Scores de confiance et détection de fraude par utilisateur';

-- =====================================================

-- 6. Table pour l'historique des avatars
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

COMMENT ON TABLE user_avatar_history IS 'Historique complet des avatars utilisateur avec backup automatique';

-- =====================================================
-- PARTIE 3: MODIFICATIONS DES TABLES EXISTANTES
-- =====================================================

-- Amélioration de la table orders (lier aux adresses)
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS address_id INTEGER REFERENCES addresses(id),
ADD COLUMN IF NOT EXISTS delivery_latitude DECIMAL(10,8),
ADD COLUMN IF NOT EXISTS delivery_longitude DECIMAL(11,8);

COMMENT ON COLUMN orders.address_id IS 'Référence vers l''adresse de livraison enregistrée';

-- =====================================================
-- PARTIE 4: INITIALISATION DES DONNÉES
-- =====================================================

-- Initialiser user_verification_levels pour tous les utilisateurs existants
INSERT INTO user_verification_levels (user_id, phone_verified, verification_level, created_at, updated_at)
SELECT 
    id,
    TRUE,
    'basic',
    NOW(),
    NOW()
FROM users
ON CONFLICT (user_id) DO NOTHING;

-- Initialiser user_trust_scores pour tous les utilisateurs existants
INSERT INTO user_trust_scores (user_id, identity_score, transaction_score, behavior_score, social_score, overall_score, created_at, updated_at)
SELECT 
    id,
    0,
    50,
    50,
    50,
    37,
    NOW(),
    NOW()
FROM users
ON CONFLICT (user_id) DO NOTHING;

-- Migrer les avatars existants vers l'historique
INSERT INTO user_avatar_history (user_id, avatar_url, storage_provider, is_current, uploaded_at, created_at)
SELECT 
    id,
    avatar_url,
    CASE 
        WHEN avatar_url LIKE '%cloudinary%' THEN 'cloudinary'
        WHEN avatar_url LIKE '%s3%' THEN 's3'
        ELSE 'local'
    END as storage_provider,
    TRUE,
    created_at,
    NOW()
FROM users
WHERE avatar_url IS NOT NULL AND avatar_url != '';

-- =====================================================
-- PARTIE 5: FONCTIONS UTILITAIRES
-- =====================================================

-- Fonction pour calculer le niveau de vérification
CREATE OR REPLACE FUNCTION calculate_verification_level(p_user_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    v_phone_verified BOOLEAN;
    v_email_verified BOOLEAN;
    v_identity_verified BOOLEAN;
    v_address_verified BOOLEAN;
    v_level VARCHAR(20);
BEGIN
    SELECT phone_verified, email_verified, identity_verified, address_verified
    INTO v_phone_verified, v_email_verified, v_identity_verified, v_address_verified
    FROM user_verification_levels
    WHERE user_id = p_user_id;
    
    IF v_identity_verified AND v_address_verified AND v_email_verified THEN
        v_level := 'premium';
    ELSIF v_identity_verified AND v_email_verified THEN
        v_level := 'advanced';
    ELSIF v_identity_verified OR v_email_verified THEN
        v_level := 'intermediate';
    ELSIF v_phone_verified THEN
        v_level := 'basic';
    ELSE
        v_level := 'unverified';
    END IF;
    
    UPDATE user_verification_levels
    SET verification_level = v_level, updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_level;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour calculer le trust score global
CREATE OR REPLACE FUNCTION calculate_overall_trust_score(p_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_identity_score INTEGER;
    v_transaction_score INTEGER;
    v_behavior_score INTEGER;
    v_social_score INTEGER;
    v_overall_score INTEGER;
BEGIN
    SELECT identity_score, transaction_score, behavior_score, social_score
    INTO v_identity_score, v_transaction_score, v_behavior_score, v_social_score
    FROM user_trust_scores
    WHERE user_id = p_user_id;
    
    v_overall_score := ROUND(
        (v_identity_score * 0.4) + 
        (v_transaction_score * 0.3) + 
        (v_behavior_score * 0.2) + 
        (v_social_score * 0.1)
    );
    
    UPDATE user_trust_scores
    SET overall_score = v_overall_score, 
        last_calculated_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_overall_score;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTIE 6: TRIGGERS
-- =====================================================

-- Trigger pour mettre à jour le niveau de vérification automatiquement
CREATE OR REPLACE FUNCTION trigger_update_verification_level()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM calculate_verification_level(NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_verification_level ON user_verification_levels;
CREATE TRIGGER trg_update_verification_level
AFTER UPDATE ON user_verification_levels
FOR EACH ROW
WHEN (OLD.phone_verified IS DISTINCT FROM NEW.phone_verified OR
      OLD.email_verified IS DISTINCT FROM NEW.email_verified OR
      OLD.identity_verified IS DISTINCT FROM NEW.identity_verified OR
      OLD.address_verified IS DISTINCT FROM NEW.address_verified)
EXECUTE FUNCTION trigger_update_verification_level();

-- Trigger pour mettre à jour le trust score automatiquement
CREATE OR REPLACE FUNCTION trigger_update_trust_score()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM calculate_overall_trust_score(NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_trust_score ON user_trust_scores;
CREATE TRIGGER trg_update_trust_score
AFTER UPDATE ON user_trust_scores
FOR EACH ROW
WHEN (OLD.identity_score IS DISTINCT FROM NEW.identity_score OR
      OLD.transaction_score IS DISTINCT FROM NEW.transaction_score OR
      OLD.behavior_score IS DISTINCT FROM NEW.behavior_score OR
      OLD.social_score IS DISTINCT FROM NEW.social_score)
EXECUTE FUNCTION trigger_update_trust_score();

-- =====================================================
-- FIN DE LA MIGRATION
-- =====================================================

DO $$
DECLARE
    v_avatar_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_avatar_count FROM user_avatar_history;
    
    RAISE NOTICE '✅ Migration terminée avec succès!';
    RAISE NOTICE '📊 Tables créées:';
    RAISE NOTICE '   - addresses';
    RAISE NOTICE '   - user_product_views';
    RAISE NOTICE '   - user_identity_documents';
    RAISE NOTICE '   - user_verification_levels';
    RAISE NOTICE '   - user_behavior_events';
    RAISE NOTICE '   - user_sessions';
    RAISE NOTICE '   - user_trust_scores';
    RAISE NOTICE '   - user_avatar_history';
    RAISE NOTICE '🔧 Tables modifiées:';
    RAISE NOTICE '   - orders (lien vers addresses)';
    RAISE NOTICE '⚙️  Fonctions créées:';
    RAISE NOTICE '   - calculate_verification_level()';
    RAISE NOTICE '   - calculate_overall_trust_score()';
    RAISE NOTICE '💰 Numéro financier: Déjà présent dans users';
    RAISE NOTICE '🖼️  Historique avatars: Migration de % avatars existants', v_avatar_count;
END $$;
