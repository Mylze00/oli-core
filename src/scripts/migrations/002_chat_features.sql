-- ====================================
-- OLI - Migration Phase 1.5
-- Améliorations Chat & Paiements
-- ====================================

-- 1. Enrichir la table messages pour supporter les types spéciaux
ALTER TABLE messages ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'text';
-- types possibles: text, image, audio, video, payment_request, payment_confirm, location

ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB;
-- metadata: { amount: 50, currency: 'USD', status: 'pending', payment_method: 'wallet' }

-- 2. Index pour requêtes plus rapides sur le type
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(type);

COMMENT ON COLUMN messages.type IS 'Type de message: text, media, payment...';
COMMENT ON COLUMN messages.metadata IS 'Données structurées pour les messages spéciaux (paiement, etc)';
