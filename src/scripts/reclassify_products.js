#!/usr/bin/env node
/**
 * Script de reclassification des produits existants
 * ───────────────────────────────────────────────────
 * Analyse le nom + description de chaque produit et met à jour
 * category + subcategory en base de données.
 *
 * Usage:
 *   node src/scripts/reclassify_products.js               → reclassifie TOUT
 *   node src/scripts/reclassify_products.js --dry-run     → simulation (aucune écriture)
 *   node src/scripts/reclassify_products.js --only-other  → uniquement ceux avec category='other' ou null
 *   node src/scripts/reclassify_products.js --limit=100   → limite le nombre traité
 *   node src/scripts/reclassify_products.js --min-confidence=50 → ne change que si confiance >= 50%
 *   node src/scripts/reclassify_products.js --dry-run --limit=20 → test rapide
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const pool = require('../config/db');
const { categorizeByName } = require('../services/product_categorizer.service');

// ─── Arguments CLI ─────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const ONLY_OTHER = args.includes('--only-other');
const limitArg = args.find(a => a.startsWith('--limit='));
const confidenceArg = args.find(a => a.startsWith('--min-confidence='));
const LIMIT = limitArg ? parseInt(limitArg.split('=')[1]) : null;
const MIN_CONFIDENCE = confidenceArg ? parseInt(confidenceArg.split('=')[1]) : 30;
const BATCH_SIZE = 100;

// ─── Couleurs terminal ──────────────────────────────────────────────────────
const C = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    red: '\x1b[31m',
    blue: '\x1b[34m',
    gray: '\x1b[90m',
    bold: '\x1b[1m',
};

function log(msg) { process.stdout.write(msg + '\n'); }

async function main() {
    log(`\n${C.bold}🏷️  Reclassification des produits Oli${C.reset}`);
    log(`${C.gray}────────────────────────────────────────${C.reset}`);
    log(`  Mode          : ${DRY_RUN ? C.yellow + 'DRY-RUN (aucune écriture)' : C.green + 'LIVE (écriture en DB)'}${C.reset}`);
    log(`  Filtre        : ${ONLY_OTHER ? 'Uniquement category=other/null' : 'TOUS les produits'}`);
    log(`  Limite        : ${LIMIT ?? 'aucune'}`);
    log(`  Confiance min : ${MIN_CONFIDENCE}%`);
    log(`${C.gray}────────────────────────────────────────${C.reset}\n`);

    // Compter les produits à traiter
    const countQuery = ONLY_OTHER
        ? `SELECT COUNT(*) FROM products WHERE (category IS NULL OR category IN ('other','autres','Autres','')) AND status != 'deleted'`
        : `SELECT COUNT(*) FROM products WHERE status != 'deleted'`;
    const countRes = await pool.query(countQuery);
    const total = Math.min(parseInt(countRes.rows[0].count), LIMIT ?? Infinity);
    log(`📦 ${total} produit(s) à traiter\n`);

    // Statistiques
    const stats = {
        processed: 0,
        updated: 0,
        skipped: 0,
        errors: 0,
        unchanged: 0,
        categoryDistrib: {},
        subcategoryDistrib: {},
    };

    let offset = 0;

    while (true) {
        // Récupérer un batch
        const batchLimit = LIMIT ? Math.min(BATCH_SIZE, LIMIT - stats.processed) : BATCH_SIZE;
        if (batchLimit <= 0) break;

        const fetchQuery = ONLY_OTHER
            ? `SELECT id, name, description, category, subcategory FROM products
         WHERE (category IS NULL OR category IN ('other','autres','Autres',''))
           AND status != 'deleted'
         ORDER BY created_at DESC LIMIT $1 OFFSET $2`
            : `SELECT id, name, description, category, subcategory FROM products
         WHERE status != 'deleted'
         ORDER BY created_at DESC LIMIT $1 OFFSET $2`;

        const { rows } = await pool.query(fetchQuery, [batchLimit, offset]);
        if (rows.length === 0) break;

        for (const product of rows) {
            try {
                const result = categorizeByName(
                    product.name || '',
                    product.description || ''
                );

                // Ignorer si confiance insuffisante
                if (result.confidence < MIN_CONFIDENCE) {
                    stats.skipped++;
                    log(`${C.gray}  ⏭ [SKIP] ${product.name?.substring(0, 50)} → confiance ${result.confidence}% < ${MIN_CONFIDENCE}%${C.reset}`);
                    continue;
                }

                // Ignorer si rien ne change
                const catChanged = product.category !== result.category;
                const subCatChanged = product.subcategory !== result.subcategory;

                if (!catChanged && !subCatChanged) {
                    stats.unchanged++;
                    log(`${C.gray}  ✓ [OK] ${product.name?.substring(0, 50)} → ${result.category}/${result.subcategory}${C.reset}`);
                    stats.processed++;
                    continue;
                }

                // Afficher le changement
                const catStr = catChanged
                    ? `${C.red}${product.category || 'null'}${C.reset} → ${C.green}${result.category}${C.reset}`
                    : `${C.gray}${result.category}${C.reset}`;
                const subStr = subCatChanged
                    ? `${C.red}${product.subcategory || 'null'}${C.reset} → ${C.green}${result.subcategory}${C.reset}`
                    : `${C.gray}${result.subcategory}${C.reset}`;
                log(`  ${DRY_RUN ? '🔍' : '✏️'} ${product.name?.substring(0, 50)} → ${catStr} / ${subStr} (${result.confidence}%)`);

                // Écriture en DB si pas dry-run
                if (!DRY_RUN) {
                    await pool.query(
                        `UPDATE products SET category = $1, subcategory = $2, updated_at = NOW() WHERE id = $3`,
                        [result.category, result.subcategory, product.id]
                    );
                    stats.updated++;
                }

                // Mettre à jour les stats de distribution
                stats.categoryDistrib[result.category] = (stats.categoryDistrib[result.category] || 0) + 1;
                stats.subcategoryDistrib[result.subcategory] = (stats.subcategoryDistrib[result.subcategory] || 0) + 1;

            } catch (err) {
                stats.errors++;
                log(`${C.red}  ❌ Erreur produit ${product.id}: ${err.message}${C.reset}`);
            }

            stats.processed++;
        }

        offset += rows.length;

        // Progression
        const pct = total > 0 ? Math.round((stats.processed / total) * 100) : 0;
        log(`\n${C.blue}  [${pct}%] ${stats.processed}/${total} traités…${C.reset}\n`);

        if (rows.length < batchLimit) break;
    }

    // Résumé final
    log(`\n${C.bold}📊 Résumé${C.reset}`);
    log(`${C.gray}─────────────────────────────${C.reset}`);
    log(`  Traités   : ${stats.processed}`);
    log(`  ${C.green}Mis à jour : ${stats.updated}${C.reset}`);
    log(`  Inchangés : ${stats.unchanged}`);
    log(`  ${C.yellow}Ignorés   : ${stats.skipped} (confiance < ${MIN_CONFIDENCE}%)${C.reset}`);
    log(`  ${C.red}Erreurs   : ${stats.errors}${C.reset}`);

    if (Object.keys(stats.categoryDistrib).length > 0) {
        log(`\n${C.bold}📁 Distribution par catégorie :${C.reset}`);
        const sorted = Object.entries(stats.categoryDistrib).sort((a, b) => b[1] - a[1]);
        for (const [cat, count] of sorted) {
            log(`  ${cat.padEnd(20)} : ${count}`);
        }
    }

    if (DRY_RUN) {
        log(`\n${C.yellow}⚠️  Mode DRY-RUN — aucune modification effectuée en base.${C.reset}`);
        log(`   Relancez sans --dry-run pour appliquer les changements.\n`);
    } else {
        log(`\n${C.green}✅ Reclassification terminée !${C.reset}\n`);
    }

    await pool.end();
    process.exit(0);
}

main().catch(err => {
    console.error('❌ Erreur fatale:', err);
    process.exit(1);
});
