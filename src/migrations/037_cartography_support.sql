-- ============================================================
-- 037: Support Cartographie — Messages location + Produits GPS
-- ============================================================

-- 1) Ajouter latitude/longitude aux messages (type 'location')
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2) Ajouter latitude/longitude aux produits
--    (complète le champ texte 'location' déjà existant)
ALTER TABLE products
    ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 3) Index pour filtrage géographique produits (accélère Haversine)
CREATE INDEX IF NOT EXISTS idx_products_geo
    ON products (latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 4) Index pour messages de type location
CREATE INDEX IF NOT EXISTS idx_messages_location
    ON messages (conversation_id, type)
    WHERE type = 'location';
