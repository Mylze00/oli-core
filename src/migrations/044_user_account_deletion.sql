-- =====================================================
-- Migration 044 : suppression de compte (suppression logique)
-- =====================================================
-- Ajout non destructif : une colonne nullable et un index partiel.
-- Aucune donnée existante n'est modifiée ni supprimée.
-- La suppression réelle est une anonymisation (voir account.service.js),
-- car commandes, transactions et wallets référencent users(id) sans cascade.

ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL;

CREATE INDEX IF NOT EXISTS idx_users_deleted_at
    ON users(deleted_at)
    WHERE deleted_at IS NOT NULL;
