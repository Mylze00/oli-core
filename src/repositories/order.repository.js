const pool = require("../config/db");

/**
 * Créer une nouvelle commande avec ses items
 */
async function createOrder(userId, items, deliveryAddress, paymentMethod, deliveryFee = 0, deliveryMethodId = null) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Calculer le total
    const totalAmount = items.reduce((sum, item) => sum + (item.price * item.quantity), 0) + deliveryFee;

    // Créer la commande
    const orderResult = await client.query(`
      INSERT INTO orders (user_id, total_amount, delivery_address, delivery_fee, payment_method, delivery_method_id, status, payment_status)
      VALUES ($1, $2, $3, $4, $5, $6, 'pending', 'pending')
      RETURNING *
    `, [userId, totalAmount, deliveryAddress, deliveryFee, paymentMethod, deliveryMethodId]);

    const order = orderResult.rows[0];

    // Ajouter les items
    for (const item of items) {
      await client.query(`
        INSERT INTO order_items (order_id, product_id, product_name, product_image_url, product_price, quantity, seller_name)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [order.id, item.productId, item.productName, item.imageUrl, item.price, item.quantity, item.sellerName]);
    }

    await client.query('COMMIT');

    return order;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Récupérer toutes les commandes d'un utilisateur
 */
async function getOrdersByUser(userId) {
  const ordersResult = await pool.query(`
    SELECT o.*, 
           json_agg(json_build_object(
             'id', oi.id,
             'productId', oi.product_id,
             'productName', oi.product_name,
             'imageUrl', oi.product_image_url,
             'price', oi.product_price,
             'quantity', oi.quantity,
             'sellerName', oi.seller_name
           )) as items
    FROM orders o
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE o.user_id = $1
    GROUP BY o.id
    ORDER BY o.created_at DESC
  `, [userId]);

  return ordersResult.rows;
}

/**
 * Récupérer les commandes disponibles pour livraison (paid, processing)
 */
async function getDeliveryOrders() {
  const ordersResult = await pool.query(`
    SELECT o.*, 
           json_agg(json_build_object(
             'id', oi.id,
             'productId', oi.product_id,
             'productName', oi.product_name,
             'imageUrl', oi.product_image_url,
             'price', oi.product_price,
             'quantity', oi.quantity,
             'sellerName', oi.seller_name
           )) as items
    FROM orders o
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE o.status IN ('paid', 'processing')
    GROUP BY o.id
    ORDER BY o.created_at DESC
  `);

  return ordersResult.rows;
}

/**
 * Récupérer une commande par ID
 */
async function getOrderById(orderId, userId) {
  const result = await pool.query(`
    SELECT o.*, 
           json_agg(json_build_object(
             'id', oi.id,
             'productId', oi.product_id,
             'productName', oi.product_name,
             'imageUrl', oi.product_image_url,
             'price', oi.product_price,
             'quantity', oi.quantity,
             'sellerName', oi.seller_name
           )) as items
    FROM orders o
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE o.id = $1 AND o.user_id = $2
    GROUP BY o.id
  `, [orderId, userId]);

  return result.rows[0] || null;
}

/**
 * Mettre à jour le statut d'une commande
 */
async function updateOrderStatus(orderId, status) {
  const result = await pool.query(`
    UPDATE orders 
    SET status = $2, updated_at = NOW()
    WHERE id = $1
    RETURNING *
  `, [orderId, status]);

  return result.rows[0];
}

/**
 * Mettre à jour le statut de paiement
 */
async function updatePaymentStatus(orderId, paymentStatus) {
  const result = await pool.query(`
    UPDATE orders 
    SET payment_status = $2, 
        status = CASE WHEN $3 = 'completed' THEN 'paid' ELSE status END,
        updated_at = NOW()
    WHERE id = $1
    RETURNING *
  `, [orderId, paymentStatus, paymentStatus]);

  return result.rows[0];
}

/**
 * Annuler une commande
 */
async function cancelOrder(orderId, userId) {
  const result = await pool.query(`
    UPDATE orders 
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = $1 AND user_id = $2 AND status IN ('pending', 'paid')
    RETURNING *
  `, [orderId, userId]);

  return result.rows[0];
}

module.exports = {
  createOrder,
  getOrdersByUser,
  getOrderById,
  updateOrderStatus,
  updatePaymentStatus,
  cancelOrder,
  getDeliveryOrders
};
