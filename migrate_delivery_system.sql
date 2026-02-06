-- =====================================================
-- MIGRATION CONSOLIDÉE: Système de Livraison
-- Date: 2026-02-05
-- Ordre d'exécution: 026 → 027
-- =====================================================
-- IMPORTANT: Faire un backup avant d'exécuter !
-- pg_dump -h <host> -U <user> -d <database> > backup_before_delivery_$(date +%Y%m%d).sql
-- =====================================================

\echo '🚀 Démarrage de la migration du système de livraison...'
\echo ''

-- =====================================================
-- ÉTAPE 1: Créer la table deliveries
-- =====================================================
\echo '📦 Étape 1/2: Création de la table deliveries...'

\i src/migrations/026_create_deliveries_table.sql

\echo '✅ Table deliveries créée'
\echo ''

-- =====================================================
-- ÉTAPE 2: Ajouter deliverer_id à orders
-- =====================================================
\echo '📦 Étape 2/2: Ajout de deliverer_id à la table orders...'

\i src/migrations/027_add_deliverer_to_orders.sql

\echo '✅ Colonnes delivery ajoutées à orders'
\echo ''

-- =====================================================
-- VÉRIFICATION FINALE
-- =====================================================
\echo '🔍 Vérification des tables créées...'

DO $$
DECLARE
    deliveries_count INTEGER;
    orders_deliverer_col BOOLEAN;
BEGIN
    -- Vérifier table deliveries
    SELECT COUNT(*) INTO deliveries_count
    FROM information_schema.tables 
    WHERE table_name = 'deliveries';
    
    -- Vérifier colonne deliverer_id dans orders
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'deliverer_id'
    ) INTO orders_deliverer_col;
    
    IF deliveries_count > 0 AND orders_deliverer_col THEN
        RAISE NOTICE '';
        RAISE NOTICE '════════════════════════════════════════';
        RAISE NOTICE '✅ MIGRATION RÉUSSIE - Système de Livraison';
        RAISE NOTICE '════════════════════════════════════════';
        RAISE NOTICE '';
        RAISE NOTICE '📊 Tables modifiées:';
        RAISE NOTICE '   ✅ deliveries (NOUVELLE)';
        RAISE NOTICE '   ✅ orders (+ deliverer_id, delivery_status)';
        RAISE NOTICE '';
        RAISE NOTICE '🔗 Relations créées:';
        RAISE NOTICE '   deliveries.order_id → orders.id';
        RAISE NOTICE '   deliveries.deliverer_id → users.id';
        RAISE NOTICE '   orders.deliverer_id → users.id';
        RAISE NOTICE '';
        RAISE NOTICE '📍 Prochaines étapes:';
        RAISE NOTICE '   1. Tester GET /orders/delivery (devrait fonctionner)';
        RAISE NOTICE '   2. Créer endpoint POST /orders/:id/assign-deliverer';
        RAISE NOTICE '   3. Intégrer oli_delivery app';
        RAISE NOTICE '';
        RAISE NOTICE '════════════════════════════════════════';
    ELSE
        RAISE WARNING '⚠️ MIGRATION INCOMPLÈTE - Vérifier les logs';
    END IF;
END $$;

\echo ''
\echo '🏁 Migration terminée!'
