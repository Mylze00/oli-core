-- =====================================================
-- Migration 045 : préférences de notification par utilisateur
-- =====================================================
-- Colonne ajoutée avec valeur par défaut : les lignes existantes reçoivent
-- simplement les valeurs par défaut, sans modification des autres données.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS notification_prefs JSONB NOT NULL
    DEFAULT '{"push": true, "email": true, "sms": false}'::jsonb;
