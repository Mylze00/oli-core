const db = require('../config/db');

async function checkSchema() {
    try {
        console.log('🐘 Inspection du schéma...');

        // Check shops.id type
        const shopIdType = await db.query(`
            SELECT data_type 
            FROM information_schema.columns 
            WHERE table_name = 'shops' AND column_name = 'id'
        `);
        console.log('🏪 Shops ID Type:', shopIdType.rows[0]?.data_type);

        // Check products.shop_id type
        const prodShopIdType = await db.query(`
            SELECT data_type 
            FROM information_schema.columns 
            WHERE table_name = 'products' AND column_name = 'shop_id'
        `);
        console.log('📦 Products shop_id Type:', prodShopIdType.rows[0]?.data_type);

    } catch (error) {
        console.error('❌ Erreur:', error);
    } finally {
        process.exit();
    }
}

checkSchema();
