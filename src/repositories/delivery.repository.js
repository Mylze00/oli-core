const pool = require('../config/db');

/**
 * Créer une commande de livraison
 */
async function create(deliveryData) {
    const {
        order_id, pickup_address, delivery_address,
        pickup_lat, pickup_lng, delivery_lat, delivery_lng,
        delivery_fee, estimated_time
    } = deliveryData;

    const res = await pool.query(`
        INSERT INTO delivery_orders (
            order_id, pickup_address, delivery_address,
            pickup_lat, pickup_lng, delivery_lat, delivery_lng,
            delivery_fee, estimated_time, status, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending', NOW())
        RETURNING *
    `, [order_id, pickup_address, delivery_address, pickup_lat, pickup_lng, delivery_lat, delivery_lng, delivery_fee, estimated_time]);

    return res.rows[0];
}

/**
 * Trouver les livraisons disponibles (statut 'pending')
 * Optionnel : filtrer par zone géographique (plus tard)
 */
async function findAvailable() {
    const res = await pool.query(`
        SELECT d.*, o.total_amount, u.name as customer_name, u.phone as customer_phone
        FROM delivery_orders d
        JOIN orders o ON d.order_id = o.id
        JOIN users u ON o.user_id = u.id
        WHERE d.status = 'pending'
        ORDER BY d.created_at ASC
    `);
    return res.rows;
}

/**
 * Assigner un livreur à une commande
 */
async function assignDeliverer(deliveryId, delivererId) {
    const res = await pool.query(`
        UPDATE delivery_orders 
        SET deliverer_id = $1, status = 'assigned', updated_at = NOW()
        WHERE id = $2 AND status = 'pending'
        RETURNING *
    `, [delivererId, deliveryId]);

    return res.rows[0];
}

/**
 * Mettre à jour le statut et la position
 */
async function updateStatus(deliveryId, status, currentLat, currentLng) {
    const res = await pool.query(`
        UPDATE delivery_orders 
        SET status = $1, current_lat = $2, current_lng = $3, updated_at = NOW()
        WHERE id = $4
        RETURNING *
    `, [status, currentLat, currentLng, deliveryId]);

    return res.rows[0];
}

/**
 * Livraisons en cours pour un livreur
 */
async function findByDeliverer(delivererId) {
    const res = await pool.query(`
        SELECT d.*, o.total_amount, u.name as customer_name, u.phone as customer_phone 
        FROM delivery_orders d
        JOIN orders o ON d.order_id = o.id
        JOIN users u ON o.user_id = u.id
        WHERE d.deliverer_id = $1 AND d.status NOT IN ('delivered', 'cancelled')
        ORDER BY d.updated_at DESC
    `, [delivererId]);
    return res.rows;
}

module.exports = {
    create,
    findAvailable,
    assignDeliverer,
    updateStatus,
    findByDeliverer
};
