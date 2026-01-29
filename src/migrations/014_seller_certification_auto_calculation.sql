-- =====================================================
-- Migration 014: Calcul automatique certification vendeur
-- =====================================================

-- Fonction pour calculer le niveau de certification d'un vendeur
CREATE OR REPLACE FUNCTION calculate_seller_account_type(p_user_id UUID)
RETURNS VARCHAR AS $$
DECLARE
    v_total_sales INTEGER;
    v_active_days INTEGER;
    v_trust_score INTEGER;
    v_avg_rating DECIMAL(3,2);
    v_identity_verified BOOLEAN;
    v_business_docs_verified BOOLEAN;
    v_new_type VARCHAR(30);
BEGIN
    -- Récupérer les métriques du vendeur
    SELECT 
        COALESCE(COUNT(DISTINCT o.id), 0) as sales,
        EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as days,
        COALESCE(uts.overall_score, 0) as trust,
        COALESCE(u.rating, 0.0) as rating,
        COALESCE(uvl.identity_verified, FALSE) as id_verified,
        COALESCE(
            (SELECT COUNT(*) > 0 
             FROM user_identity_documents uid 
             WHERE uid.user_id = u.id 
             AND uid.document_type = 'business_registration' 
             AND uid.verification_status = 'approved'
            ), 
            FALSE
        ) as biz_verified
    INTO 
        v_total_sales,
        v_active_days,
        v_trust_score,
        v_avg_rating,
        v_identity_verified,
        v_business_docs_verified
    FROM users u
    LEFT JOIN products p ON p.seller_id = u.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    LEFT JOIN orders o ON o.id = oi.order_id AND o.status = 'completed'
    LEFT JOIN user_trust_scores uts ON uts.user_id = u.id
    LEFT JOIN user_verification_levels uvl ON uvl.user_id = u.id
    WHERE u.id = p_user_id
    GROUP BY u.created_at, u.rating, uts.overall_score, uvl.identity_verified;
    
    -- Si aucune donnée trouvée, initialiser à 0
    IF v_total_sales IS NULL THEN
        v_total_sales := 0;
        v_active_days := 0;
        v_trust_score := 0;
        v_avg_rating := 0.0;
        v_identity_verified := FALSE;
        v_business_docs_verified := FALSE;
    END IF;
    
    -- Déterminer le niveau (ordre important : premium > entreprise > certifie > ordinaire)
    IF v_total_sales >= 100 AND v_trust_score >= 80 AND v_avg_rating >= 4.5 AND v_active_days >= 60 THEN
        v_new_type := 'premium';
    ELSIF v_total_sales >= 50 AND v_business_docs_verified AND v_active_days >= 30 THEN
        v_new_type := 'entreprise';
    ELSIF v_total_sales >= 10 AND v_trust_score >= 60 AND v_identity_verified THEN
        v_new_type := 'certifie';
    ELSE
        v_new_type := 'ordinaire';
    END IF;
    
    -- Mettre à jour si changement
    UPDATE users
    SET 
        account_type = v_new_type,
        total_sales = v_total_sales,
        updated_at = NOW()
    WHERE id = p_user_id AND (account_type IS NULL OR account_type != v_new_type);
    
    RETURN v_new_type;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour recalcul après chaque vente complétée
CREATE OR REPLACE FUNCTION trigger_recalculate_seller_certification()
RETURNS TRIGGER AS $$
DECLARE
    v_seller_id UUID;
BEGIN
    -- Récupérer le seller_id du premier produit de la commande
    SELECT p.seller_id INTO v_seller_id
    FROM order_items oi
    JOIN products p ON p.id = oi.product_id
    WHERE oi.order_id = NEW.id
    LIMIT 1;
    
    -- Recalculer la certification si un vendeur est trouvé
    IF v_seller_id IS NOT NULL THEN
        PERFORM calculate_seller_account_type(v_seller_id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Supprimer le trigger s'il existe déjà
DROP TRIGGER IF EXISTS trg_recalc_certification_on_order ON orders;

-- Créer le trigger
CREATE TRIGGER trg_recalc_certification_on_order
AFTER UPDATE ON orders
FOR EACH ROW
WHEN (NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed'))
EXECUTE FUNCTION trigger_recalculate_seller_certification();

-- Initialiser pour tous les vendeurs existants
DO $$
DECLARE
    seller_record RECORD;
    v_count INTEGER := 0;
BEGIN
    FOR seller_record IN SELECT id FROM users WHERE is_seller = TRUE
    LOOP
        PERFORM calculate_seller_account_type(seller_record.id);
        v_count := v_count + 1;
    END LOOP;
    RAISE NOTICE '✅ Certification recalculée pour % vendeurs', v_count;
END $$;

-- Commentaires
COMMENT ON FUNCTION calculate_seller_account_type(UUID) IS 'Calcule et met à jour automatiquement le niveau de certification d''un vendeur';
COMMENT ON FUNCTION trigger_recalculate_seller_certification() IS 'Trigger pour recalculer la certification après une vente complétée';
