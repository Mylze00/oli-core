/**
 * Script de migration : Re-upload des images externes vers Cloudinary
 * 
 * Ce script détecte les produits ayant des images hébergées sur des serveurs
 * externes (ex: losako.shop) et les re-uploade vers Cloudinary pour résoudre
 * les problèmes CORS sur Flutter Web.
 * 
 * Usage: node scripts/migrate-images-to-cloudinary.js
 * 
 * Options:
 *   --dry-run    Afficher les produits sans modifier la base
 *   --limit=N    Limiter le nombre de produits à traiter
 */

require('dotenv').config();
const path = require('path');
const pool = require(path.resolve(__dirname, '..', 'src', 'config', 'db'));
const cloudinary = require('cloudinary').v2;

// Configurer Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

const DRY_RUN = process.argv.includes('--dry-run');
const limitArg = process.argv.find(a => a.startsWith('--limit='));
const LIMIT = limitArg ? parseInt(limitArg.split('=')[1]) : null;

async function reuploadToCloudinary(imageUrl) {
    try {
        if (!imageUrl || !imageUrl.startsWith('http')) return imageUrl;
        if (imageUrl.includes('cloudinary.com')) return imageUrl;

        const result = await cloudinary.uploader.upload(imageUrl, {
            folder: 'oli_app/imported',
            resource_type: 'image',
        });
        return result.secure_url;
    } catch (err) {
        console.warn(`  ⚠️ Échec: ${imageUrl.substring(0, 80)}... - ${err.message}`);
        return null; // Retourner null pour les échecs
    }
}

async function main() {
    console.log('🔄 Migration des images externes vers Cloudinary');
    console.log(`   Mode: ${DRY_RUN ? 'DRY RUN (pas de modifications)' : 'PRODUCTION'}`);
    if (LIMIT) console.log(`   Limite: ${LIMIT} produits`);
    console.log('');

    // Trouver les produits avec images externes (non-Cloudinary)
    let query = `
        SELECT id, name, images 
        FROM products 
        WHERE images IS NOT NULL 
          AND array_length(images, 1) > 0
        ORDER BY created_at DESC
    `;
    if (LIMIT) query += ` LIMIT ${LIMIT}`;

    const result = await pool.query(query);

    let totalProducts = 0;
    let externalProducts = 0;
    let migratedImages = 0;
    let failedImages = 0;

    for (const row of result.rows) {
        totalProducts++;

        // Vérifier si au moins une image est externe
        const hasExternal = row.images.some(img =>
            img.startsWith('http') && !img.includes('cloudinary.com')
        );

        if (!hasExternal) continue;
        externalProducts++;

        console.log(`📦 [${externalProducts}] ${row.name} (ID: ${row.id})`);
        console.log(`   Images actuelles: ${row.images.length}`);

        if (DRY_RUN) {
            for (const img of row.images) {
                const isExternal = img.startsWith('http') && !img.includes('cloudinary.com');
                console.log(`   ${isExternal ? '🔴 EXTERNE' : '🟢 OK'}: ${img.substring(0, 80)}`);
            }
            continue;
        }

        // Re-uploader les images externes
        const newImages = [];
        let modified = false;

        for (const img of row.images) {
            if (img.includes('cloudinary.com') || !img.startsWith('http')) {
                newImages.push(img);
                continue;
            }

            console.log(`   ☁️ Re-upload: ${img.substring(0, 80)}...`);
            const newUrl = await reuploadToCloudinary(img);

            if (newUrl) {
                newImages.push(newUrl);
                migratedImages++;
                modified = true;
                console.log(`   ✅ → ${newUrl.substring(0, 60)}...`);
            } else {
                failedImages++;
                // Garder l'URL originale en fallback
                newImages.push(img);
            }

            // Petit délai pour ne pas surcharger Cloudinary
            await new Promise(resolve => setTimeout(resolve, 200));
        }

        if (modified) {
            await pool.query(
                'UPDATE products SET images = $1, updated_at = NOW() WHERE id = $2',
                [newImages, row.id]
            );
            console.log(`   ✅ Produit mis à jour`);
        }
    }

    console.log('\n========================================');
    console.log('📊 RÉSUMÉ');
    console.log(`   Total produits analysés: ${totalProducts}`);
    console.log(`   Produits avec images externes: ${externalProducts}`);
    if (!DRY_RUN) {
        console.log(`   Images migrées: ${migratedImages}`);
        console.log(`   Images échouées: ${failedImages}`);
    }
    console.log('========================================\n');

    process.exit(0);
}

main().catch(err => {
    console.error('❌ Erreur fatale:', err);
    process.exit(1);
});
