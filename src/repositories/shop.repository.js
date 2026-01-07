const pool = require("../config/db");

// Créer boutique
async function createShop(userId, name, description) {
  const query = `
    INSERT INTO shops (user_id, name, description)
    VALUES ($1, $2, $3)
    RETURNING *
  `;
  const { rows } = await pool.query(query, [userId, name, description]);
  return rows[0];
}

// Lister boutiques d’un utilisateur
async function getShopsByUser(userId) {
  const query = `
    SELECT *
    FROM shops
    WHERE user_id = $1
  `;
  const { rows } = await pool.query(query, [userId]);
  return rows;
}

// Lister toutes les boutiques publiques
async function getAllShops() {
  const query = `
    SELECT *
    FROM shops
    ORDER BY created_at DESC
  `;
  const { rows } = await pool.query(query);
  return rows;
}

// Modifier boutique
async function updateShop(userId, shopId, data) {
  const { name, description } = data;
  const query = `
    UPDATE shops
    SET name = COALESCE($1, name),
        description = COALESCE($2, description)
    WHERE id = $3 AND user_id = $4
    RETURNING *
  `;
  const { rows } = await pool.query(query, [name, description, shopId, userId]);
  return rows[0];
}

// Supprimer boutique
async function deleteShop(userId, shopId) {
  const query = `
    DELETE FROM shops
    WHERE id = $1 AND user_id = $2
  `;
  await pool.query(query, [shopId, userId]);
}

module.exports = {
  createShop,
  getShopsByUser,
  getAllShops,
  updateShop,
  deleteShop,
};
