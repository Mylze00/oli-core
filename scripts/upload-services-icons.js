require('dotenv').config();
const fs = require('fs');
const path = require('path');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

const servicesMap = {
    'snel.png': 'SNEL',
    'regideso.png': 'Regideso',
    'canal_plus.png': 'Canal+',
    'kelasipay.png': 'Kelasipay',
    'rawsur.png': 'RAWSUR'
};

const assetsDir = path.resolve(__dirname, '..', 'oli_app', 'assets', 'images', 'services');

async function uploadToCloudinary(filePath, fileName) {
    try {
        console.log(`☁️ Uploading: ${fileName}...`);
        const result = await cloudinary.uploader.upload(filePath, {
            folder: 'oli_app/services',
            resource_type: 'image',
        });
        return result.secure_url;
    } catch (err) {
        console.warn(`⚠️ Failed to upload ${fileName}: ${err.message}`);
        return null;
    }
}

async function main() {
    console.log('🔄 Uploading Service Icons to Cloudinary...\n');

    if (!fs.existsSync(assetsDir)) {
        console.error(`❌ Directory not found: ${assetsDir}`);
        process.exit(1);
    }

    const files = fs.readdirSync(assetsDir);
    let sqlQueries = '-- Run this file to update the database\n';

    for (const file of files) {
        if (!servicesMap[file]) {
            console.log(`⏩ Skipping ${file} (No matching service found)`);
            continue;
        }

        const serviceName = servicesMap[file];
        const filePath = path.join(assetsDir, file);
        
        const newUrl = await uploadToCloudinary(filePath, file);

        if (newUrl) {
            console.log(`✅ Uploaded ${serviceName}: ${newUrl}`);
            
            // Generate SQL string
            const safeUrl = newUrl.replace("'", "''");
            const safeName = serviceName.replace("'", "''");
            sqlQueries += `UPDATE services SET logo_url = '${safeUrl}', updated_at = NOW() WHERE name = '${safeName}';\n`;
        }
    }

    // Write to a SQL file
    const sqlPath = path.resolve(__dirname, '..', 'run_services_update.sql');
    fs.writeFileSync(sqlPath, sqlQueries);

    console.log('\n📝 SQL file generated: run_services_update.sql');
    console.log('✨ Vous pouvez maintenant exécuter ce fichier SQL sur votre base de données Render !');
    process.exit(0);
}

main().catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
});
