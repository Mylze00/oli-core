-- =====================================================
-- Script de vérification des vendeurs et leur certification
-- =====================================================

-- 1. Vue d'ensemble des vendeurs
SELECT 
    '=== VUE D''ENSEMBLE DES VENDEURS ===' as section;

SELECT 
    COUNT(*) as total_vendeurs,
    COUNT(CASE WHEN account_type = 'ordinaire' THEN 1 END) as ordinaires,
    COUNT(CASE WHEN account_type = 'certifie' THEN 1 END) as certifies,
    COUNT(CASE WHEN account_type = 'premium' THEN 1 END) as premium,
    COUNT(CASE WHEN account_type = 'entreprise' THEN 1 END) as entreprises,
    COUNT(CASE WHEN has_certified_shop = TRUE THEN 1 END) as avec_boutique_certifiee
FROM users 
WHERE is_seller = TRUE;

-- 2. Détails des vendeurs avec leurs métriques
SELECT 
    '=== DÉTAILS DES VENDEURS ===' as section;

SELECT 
    u.id,
    u.name,
    u.phone,
    u.account_type,
    u.has_certified_shop,
    COALESCE(u.total_sales, 0) as total_sales,
    u.rating,
    EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as jours_actif,
    COALESCE(uts.overall_score, 0) as trust_score,
    COALESCE(uvl.identity_verified, FALSE) as identite_verifiee,
    (SELECT COUNT(*) FROM products WHERE seller_id = u.id) as nb_produits,
    (SELECT COUNT(*) FROM shops WHERE owner_id = u.id) as nb_boutiques
FROM users u
LEFT JOIN user_trust_scores uts ON uts.user_id = u.id
LEFT JOIN user_verification_levels uvl ON uvl.user_id = u.id
WHERE u.is_seller = TRUE
ORDER BY u.created_at DESC
LIMIT 20;

-- 3. Vendeurs avec des ventes
SELECT 
    '=== VENDEURS AVEC VENTES ===' as section;

SELECT 
    u.id,
    u.name,
    u.account_type,
    COUNT(DISTINCT o.id) as nb_ventes_completees,
    SUM(oi.quantity * oi.price) as revenu_total
FROM users u
JOIN products p ON p.seller_id = u.id
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o ON o.id = oi.order_id AND o.status = 'completed'
WHERE u.is_seller = TRUE
GROUP BY u.id, u.name, u.account_type
ORDER BY nb_ventes_completees DESC
LIMIT 10;

-- 4. Vendeurs éligibles pour certification (mais pas encore certifiés)
SELECT 
    '=== VENDEURS ÉLIGIBLES POUR CERTIFICATION ===' as section;

SELECT 
    u.id,
    u.name,
    u.account_type as niveau_actuel,
    COALESCE(u.total_sales, 0) as ventes,
    COALESCE(uts.overall_score, 0) as trust_score,
    COALESCE(uvl.identity_verified, FALSE) as id_verifiee,
    EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as jours_actif,
    CASE 
        WHEN COALESCE(u.total_sales, 0) >= 100 
             AND COALESCE(uts.overall_score, 0) >= 80 
             AND COALESCE(u.rating, 0) >= 4.5 
             AND EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER >= 60 
        THEN 'Éligible PREMIUM'
        WHEN COALESCE(u.total_sales, 0) >= 50 
             AND EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER >= 30 
        THEN 'Éligible ENTREPRISE (si docs soumis)'
        WHEN COALESCE(u.total_sales, 0) >= 10 
             AND COALESCE(uts.overall_score, 0) >= 60 
             AND COALESCE(uvl.identity_verified, FALSE) = TRUE 
        THEN 'Éligible CERTIFIÉ'
        ELSE 'Pas encore éligible'
    END as eligibilite
FROM users u
LEFT JOIN user_trust_scores uts ON uts.user_id = u.id
LEFT JOIN user_verification_levels uvl ON uvl.user_id = u.id
WHERE u.is_seller = TRUE
  AND u.account_type = 'ordinaire'
ORDER BY COALESCE(u.total_sales, 0) DESC
LIMIT 15;

-- 5. Statistiques des boutiques
SELECT 
    '=== STATISTIQUES DES BOUTIQUES ===' as section;

SELECT 
    COUNT(*) as total_boutiques,
    COUNT(CASE WHEN is_verified = TRUE THEN 1 END) as boutiques_verifiees,
    AVG(rating) as rating_moyen,
    SUM(total_products) as total_produits,
    SUM(total_sales) as total_ventes
FROM shops;

-- 6. Vérifier si la fonction de calcul existe
SELECT 
    '=== VÉRIFICATION FONCTION SQL ===' as section;

SELECT 
    proname as nom_fonction,
    pg_get_functiondef(oid) as existe
FROM pg_proc 
WHERE proname = 'calculate_seller_account_type';

-- 7. Vérifier si le trigger existe
SELECT 
    '=== VÉRIFICATION TRIGGER ===' as section;

SELECT 
    tgname as nom_trigger,
    tgenabled as actif
FROM pg_trigger 
WHERE tgname = 'trg_recalc_certification_on_order';
