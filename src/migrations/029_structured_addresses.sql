-- Migration 029: Restructurer la table addresses pour la livraison
-- Ajouter des champs structurés: avenue, numéro, quartier, commune
-- + coordonnées GPS pour le calcul de distance vendeur/acheteur

-- Ajouter les colonnes structurées
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS avenue VARCHAR(255);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS numero VARCHAR(20);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS quartier VARCHAR(100);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS commune VARCHAR(100);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS ville VARCHAR(100) DEFAULT 'Kinshasa';
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS province VARCHAR(100);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS reference_point TEXT; -- Point de repère
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Index pour recherche géographique
CREATE INDEX IF NOT EXISTS idx_addresses_commune ON addresses(commune);
CREATE INDEX IF NOT EXISTS idx_addresses_quartier ON addresses(quartier);
CREATE INDEX IF NOT EXISTS idx_addresses_coords ON addresses(latitude, longitude) WHERE latitude IS NOT NULL;

SELECT 'Migration 029 addresses restructurées avec succès' AS status;
