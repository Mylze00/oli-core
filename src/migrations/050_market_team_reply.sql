-- ======================================================================
-- Migration 050 : Réponses de l'équipe Oli dans Market Chat
-- Une demande de produit n'est liée à aucun produit : is_market range sa
-- conversation dans Market Chat. response_sent_at trace la livraison au client.
-- ======================================================================

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS is_market BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE product_requests ADD COLUMN IF NOT EXISTS response_sent_at TIMESTAMP;
