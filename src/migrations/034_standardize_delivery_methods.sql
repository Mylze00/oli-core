-- =====================================================
-- Migration 034: Standardisation des 7 modes de livraison Oli
-- Date: 2026-03-01
-- Purpose: Harmoniser delivery_methods sur tout l'écosystème
--          avec les 7 modes officiels + champs délai standard
-- =====================================================

-- 1. Ajouter champ "time_label" s'il n'existe pas
ALTER TABLE delivery_methods ADD COLUMN IF NOT EXISTS time_label VARCHAR(100);
ALTER TABLE delivery_methods ADD COLUMN IF NOT EXISTS is_distance_based BOOLEAN DEFAULT FALSE;
ALTER TABLE delivery_methods ADD COLUMN IF NOT EXISTS default_cost DECIMAL(10,2) DEFAULT 0;

-- 2. Upsert des 7 modes officiels Oli
INSERT INTO delivery_methods (id, label, description, time_label, is_active, requires_deliverer, requires_address, is_distance_based, default_cost, icon, sort_order)
VALUES
    ('oli_standard',  'Livraison Standard',           'Livraison standard gérée par Oli',                          '10 jours',       true, true,  true,  false, 2.50, 'inventory_2',    1),
    ('oli_express',   'Oli Express 24h',               'Livraison rapide garantie sous 24h',                        '24 heures',      true, true,  true,  false, 5.00, 'local_shipping', 2),
    ('hand_delivery', 'Retrait en main propre',        'Le vendeur et l''acheteur conviennent d''un RDV',           'Sur rendez-vous',true, false, false, false, 0.00, 'handshake',      3),
    ('free',          'Livraison gratuite',            'Offerte par le vendeur, délai plus long',                   '60 jours',       true, false, true,  false, 0.00, 'card_giftcard',  4),
    ('pick_go',       'PickGo',                        'L''acheteur récupère au guérite du magasin dans la journée','1-4 heures',     true, false, false, false, 1.00, 'store',          5),
    ('moto',          'Livraison moto',                'Livraison par moto, prix calculé selon la distance',        'Calculé/distance',true, true, true,  true,  0.00, 'two_wheeler',    6),
    ('maritime',      'Livraison maritime',            'Transport maritime international ou inter-ville',           '60 jours',       true, true,  true,  false, 15.00,'directions_boat',7)
ON CONFLICT (id) DO UPDATE SET
    label             = EXCLUDED.label,
    description       = EXCLUDED.description,
    time_label        = EXCLUDED.time_label,
    is_active         = EXCLUDED.is_active,
    requires_deliverer= EXCLUDED.requires_deliverer,
    requires_address  = EXCLUDED.requires_address,
    is_distance_based = EXCLUDED.is_distance_based,
    default_cost      = EXCLUDED.default_cost,
    icon              = EXCLUDED.icon,
    sort_order        = EXCLUDED.sort_order;

-- 3. Désactiver l'ancien mode "partner" (remplacé par "moto")
UPDATE delivery_methods SET is_active = false WHERE id = 'partner';

-- 4. Vérification
DO $$
DECLARE
    count_active INTEGER;
BEGIN
    SELECT COUNT(*) INTO count_active FROM delivery_methods WHERE is_active = true;
    RAISE NOTICE '✅ Livraison harmonisée: % modes actifs', count_active;
END $$;
