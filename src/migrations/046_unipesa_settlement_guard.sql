-- =====================================================
-- Migration 046 : verrou de règlement des opérations Unipesa
-- =====================================================
-- settled_at est posé une seule fois, quand une opération est créditée
-- (dépôt) ou remboursée (retrait en échec). Il protège contre les rejeux
-- de webhook et contre les doubles appels (webhook + polling).
-- Les opérations déjà terminées sont marquées comme réglées pour ne pas
-- pouvoir être créditées une seconde fois. Aucune donnée n'est supprimée.

ALTER TABLE unipesa_operations ADD COLUMN IF NOT EXISTS settled_at TIMESTAMP NULL;

UPDATE unipesa_operations
SET settled_at = COALESCE(confirmed_at, NOW())
WHERE status IN ('success', 'failed') AND settled_at IS NULL;
