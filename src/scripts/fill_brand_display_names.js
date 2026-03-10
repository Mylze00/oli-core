/**
 * Script : remplir brand_display_name pour les produits brand_certified
 * Usage  : node src/scripts/fill_brand_display_names.js
 */
require('dotenv').config();
const pool = require('../config/db');

// ── Dictionnaire de marques : mot-clé → nom officiel ──────────────────────────
const BRAND_MAP = [
    // Mode & Luxe
    { pattern: /\bzara\b/i, brand: 'ZARA' },
    { pattern: /\bysl\b|saint\s*laurent/i, brand: 'YSL — Saint Laurent' },
    { pattern: /\bgucci\b/i, brand: 'Gucci' },
    { pattern: /\blouis\s*vuitton\b/i, brand: 'Louis Vuitton' },
    { pattern: /\bversace\b/i, brand: 'Versace' },
    { pattern: /\bh&m\b/i, brand: 'H&M' },
    { pattern: /\blacoste\b/i, brand: 'Lacoste' },
    { pattern: /\blv\b/i, brand: 'Louis Vuitton' },

    // Chaussures / Sport
    { pattern: /\bnike\b/i, brand: 'Nike' },
    { pattern: /\badidas\b/i, brand: 'Adidas' },
    { pattern: /\bpuma\b/i, brand: 'Puma' },
    { pattern: /\breebok\b/i, brand: 'Reebok' },
    { pattern: /\bnew\s*balance\b/i, brand: 'New Balance' },
    { pattern: /\bconverse\b/i, brand: 'Converse' },
    { pattern: /\bvans\b/i, brand: 'Vans' },

    // Tech
    { pattern: /\bsamsung\b/i, brand: 'Samsung' },
    { pattern: /\bapple\b|iphone|ipad|macbook/i, brand: 'Apple' },
    { pattern: /\bxiaomi\b/i, brand: 'Xiaomi' },
    { pattern: /\bhuawei\b/i, brand: 'Huawei' },
    { pattern: /\boppo\b/i, brand: 'Oppo' },
    { pattern: /\btecno\b/i, brand: 'Tecno' },
    { pattern: /\bmotorola\b/i, brand: 'Motorola' },
    { pattern: /\bsony\b/i, brand: 'Sony' },
    { pattern: /\blg\b/i, brand: 'LG' },
    { pattern: /\bphilips\b/i, brand: 'Philips' },
    { pattern: /\bcanon\b/i, brand: 'Canon' },
    { pattern: /\bdell\b/i, brand: 'Dell' },
    { pattern: /\blenovo\b/i, brand: 'Lenovo' },

    // Beauté / Hygiène
    { pattern: /\bnivea\b/i, brand: 'Nivea' },
    { pattern: /\bdove\b/i, brand: 'Dove' },
    { pattern: /\bvaseline\b/i, brand: 'Vaseline' },
    { pattern: /\bloreal\b|l'oreal|l'oréal/i, brand: "L'Oréal" },
    { pattern: /\bpampers\b/i, brand: 'Pampers' },
    { pattern: /\bunilever\b/i, brand: 'Unilever' },
    { pattern: /\bnestl[eé]\b/i, brand: 'Nestlé' },
    { pattern: /\bperfum\b.*sauvage|sauvage.*parfum/i, brand: 'Dior — Sauvage' },

    // Licences / Disney
    { pattern: /\bmickey\b/i, brand: 'Disney — Mickey' },
    { pattern: /\bdisney\b/i, brand: 'Disney' },

    // Outils bureautique (HP = Hewlett-Packard seulement si électronique)
    // HP exclu car "haute performance" cause faux positifs
];

function detectBrand(productName) {
    for (const { pattern, brand } of BRAND_MAP) {
        if (pattern.test(productName)) return brand;
    }
    return null;
}

async function run() {
    const { rows } = await pool.query(
        `SELECT id, name, brand_display_name
         FROM products
         WHERE brand_certified = TRUE AND status = 'active'
         ORDER BY id`
    );

    console.log(`\n📦 ${rows.length} produits brand_certified trouvés\n`);

    let updated = 0, skipped = 0, manual = 0;

    for (const p of rows) {
        const already = p.brand_display_name?.trim();
        if (already) {
            console.log(`  ✅ [${p.id}] Déjà rempli → "${already}"`);
            skipped++;
            continue;
        }

        const detected = detectBrand(p.name);
        if (detected) {
            await pool.query(
                `UPDATE products SET brand_display_name = $1 WHERE id = $2`,
                [detected, p.id]
            );
            console.log(`  🔄 [${p.id}] "${p.name.slice(0, 40)}" → ${detected}`);
            updated++;
        } else {
            console.log(`  ⚠️  [${p.id}] "${p.name.slice(0, 40)}" → à classer manuellement`);
            manual++;
        }
    }

    console.log(`\n✅ Résumé:`);
    console.log(`   Mis à jour : ${updated}`);
    console.log(`   Déjà définis : ${skipped}`);
    console.log(`   À classer manuellement : ${manual}`);
    console.log(`   Total : ${rows.length}`);

    await pool.end();
}

run().catch(err => {
    console.error('❌ Erreur :', err.message);
    process.exit(1);
});
