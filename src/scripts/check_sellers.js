/**
 * Script de vérification des vendeurs et leur certification
 * Usage: node src/scripts/check_sellers.js
 */

const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

async function checkSellers() {
    const client = await pool.connect();
    try {
        console.log('\n📊 === VUE D\'ENSEMBLE DES VENDEURS ===\n');

        // 1. Vue d'ensemble
        const overview = await client.query(`
            SELECT 
                COUNT(*) as total_vendeurs,
                COUNT(CASE WHEN account_type = 'ordinaire' THEN 1 END) as ordinaires,
                COUNT(CASE WHEN account_type = 'certifie' THEN 1 END) as certifies,
                COUNT(CASE WHEN account_type = 'premium' THEN 1 END) as premium,
                COUNT(CASE WHEN account_type = 'entreprise' THEN 1 END) as entreprises,
                COUNT(CASE WHEN has_certified_shop = TRUE THEN 1 END) as avec_boutique_certifiee
            FROM users 
            WHERE is_seller = TRUE
        `);

        const stats = overview.rows[0];
        console.log(`Total vendeurs: ${stats.total_vendeurs}`);
        console.log(`  - Ordinaires: ${stats.ordinaires}`);
        console.log(`  - Certifiés: ${stats.certifies}`);
        console.log(`  - Premium: ${stats.premium}`);
        console.log(`  - Entreprises: ${stats.entreprises}`);
        console.log(`  - Avec boutique certifiée: ${stats.avec_boutique_certifiee}`);

        // 2. Top 10 vendeurs par ventes
        console.log('\n📈 === TOP 10 VENDEURS (par ventes) ===\n');

        const topSellers = await client.query(`
            SELECT 
                u.id,
                u.name,
                u.phone,
                u.account_type,
                COALESCE(u.total_sales, 0) as total_sales,
                u.rating,
                EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as jours_actif,
                (SELECT COUNT(*) FROM products WHERE seller_id = u.id) as nb_produits
            FROM users u
            WHERE u.is_seller = TRUE
            ORDER BY COALESCE(u.total_sales, 0) DESC
            LIMIT 10
        `);

        if (topSellers.rows.length === 0) {
            console.log('Aucun vendeur trouvé.');
        } else {
            topSellers.rows.forEach((seller, index) => {
                console.log(`${index + 1}. ${seller.name} (${seller.phone})`);
                console.log(`   Niveau: ${seller.account_type.toUpperCase()}`);
                console.log(`   Ventes: ${seller.total_sales} | Produits: ${seller.nb_produits} | Jours actif: ${seller.jours_actif}`);
                console.log(`   Rating: ${seller.rating || 'N/A'}`);
                console.log('');
            });
        }

        // 3. Vendeurs éligibles pour upgrade
        console.log('\n⭐ === VENDEURS ÉLIGIBLES POUR UPGRADE ===\n');

        const eligible = await client.query(`
            SELECT 
                u.id,
                u.name,
                u.account_type as niveau_actuel,
                COALESCE(u.total_sales, 0) as ventes,
                COALESCE(uts.overall_score, 0) as trust_score,
                COALESCE(uvl.identity_verified, FALSE) as id_verifiee,
                COALESCE(u.rating, 0) as rating,
                EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER as jours_actif,
                CASE 
                    WHEN COALESCE(u.total_sales, 0) >= 100 
                         AND COALESCE(uts.overall_score, 0) >= 80 
                         AND COALESCE(u.rating, 0) >= 4.5 
                         AND EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER >= 60 
                    THEN 'PREMIUM'
                    WHEN COALESCE(u.total_sales, 0) >= 50 
                         AND EXTRACT(DAY FROM (NOW() - u.created_at))::INTEGER >= 30 
                    THEN 'ENTREPRISE'
                    WHEN COALESCE(u.total_sales, 0) >= 10 
                         AND COALESCE(uts.overall_score, 0) >= 60 
                         AND COALESCE(uvl.identity_verified, FALSE) = TRUE 
                    THEN 'CERTIFIÉ'
                    ELSE NULL
                END as eligible_pour
            FROM users u
            LEFT JOIN user_trust_scores uts ON uts.user_id = u.id
            LEFT JOIN user_verification_levels uvl ON uvl.user_id = u.id
            WHERE u.is_seller = TRUE
              AND u.account_type = 'ordinaire'
            ORDER BY COALESCE(u.total_sales, 0) DESC
            LIMIT 10
        `);

        if (eligible.rows.length === 0) {
            console.log('Aucun vendeur éligible pour upgrade.');
        } else {
            eligible.rows.forEach((seller) => {
                if (seller.eligible_pour) {
                    console.log(`✅ ${seller.name}`);
                    console.log(`   Éligible pour: ${seller.eligible_pour}`);
                    console.log(`   Ventes: ${seller.ventes} | Trust: ${seller.trust_score} | Rating: ${seller.rating} | Jours: ${seller.jours_actif}`);
                    console.log('');
                }
            });
        }

        // 4. Vérifier si la migration a été exécutée
        console.log('\n🔧 === VÉRIFICATION MIGRATION ===\n');

        const functionCheck = await client.query(`
            SELECT COUNT(*) as count
            FROM pg_proc 
            WHERE proname = 'calculate_seller_account_type'
        `);

        if (functionCheck.rows[0].count > 0) {
            console.log('✅ Fonction calculate_seller_account_type existe');
        } else {
            console.log('❌ Fonction calculate_seller_account_type N\'EXISTE PAS');
            console.log('   → Vous devez exécuter la migration 014_seller_certification_auto_calculation.sql');
        }

        const triggerCheck = await client.query(`
            SELECT COUNT(*) as count
            FROM pg_trigger 
            WHERE tgname = 'trg_recalc_certification_on_order'
        `);

        if (triggerCheck.rows[0].count > 0) {
            console.log('✅ Trigger trg_recalc_certification_on_order existe');
        } else {
            console.log('❌ Trigger trg_recalc_certification_on_order N\'EXISTE PAS');
        }

        // 5. Statistiques des boutiques
        console.log('\n🏪 === STATISTIQUES DES BOUTIQUES ===\n');

        const shopStats = await client.query(`
            SELECT 
                COUNT(*) as total_boutiques,
                COUNT(CASE WHEN is_verified = TRUE THEN 1 END) as boutiques_verifiees,
                ROUND(AVG(rating)::numeric, 2) as rating_moyen,
                SUM(total_products) as total_produits,
                SUM(total_sales) as total_ventes
            FROM shops
        `);

        const shops = shopStats.rows[0];
        console.log(`Total boutiques: ${shops.total_boutiques}`);
        console.log(`Boutiques vérifiées: ${shops.boutiques_verifiees}`);
        console.log(`Rating moyen: ${shops.rating_moyen || 'N/A'}`);
        console.log(`Total produits: ${shops.total_produits || 0}`);
        console.log(`Total ventes: ${shops.total_ventes || 0}`);

    } catch (error) {
        console.error('❌ Erreur:', error.message);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

// Exécuter le script
checkSellers()
    .then(() => {
        console.log('\n✅ Vérification terminée!\n');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n💥 Erreur lors de la vérification:', error);
        process.exit(1);
    });
