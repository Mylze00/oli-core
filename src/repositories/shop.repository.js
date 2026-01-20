const pool = require("../config/db");

/**
 * Créer une nouvelle boutique
 */
async function create(shopData) {
  const { owner_id, name, description, category, location, logo_url, banner_url } = shopData;

  const query = `
        INSERT INTO shops (
            owner_id, name, description, category, location, 
            logo_url, banner_url, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
        RETURNING *
    `;

  const values = [owner_id, name, description, category, location, logo_url, banner_url];
  const { rows } = await pool.query(query, values);

  // Mettre à jour le flag is_seller de l'utilisateur
  await pool.query("UPDATE users SET is_seller = true WHERE id = $1", [owner_id]);

  return rows[0];
}

/**
 * Trouver une boutique par ID
 */
async function findById(id) {
  const query = `
        SELECT s.*, u.name as owner_name, u.avatar_url as owner_avatar, u.phone as owner_phone
        FROM shops s
        JOIN users u ON s.owner_id = u.id
        WHERE s.id = $1
    `;
  const { rows } = await pool.query(query, [id]);
  return rows[0];
}

/**
 * Trouver les boutiques d'un utilisateur
 */
async function findByOwnerId(ownerId) {
  const query = `SELECT * FROM shops WHERE owner_id = $1 ORDER BY created_at DESC`;
  const { rows } = await pool.query(query, [ownerId]);
  return rows;
}

/**
 * Trouver les boutiques vérifiées (pour Carousel Accueil)
 */
async function findVerified(limit = 10) {
  const query = `
      SELECT s.*, u.name as owner_name, u.avatar_url as owner_avatar
      FROM shops s
      JOIN users u ON s.owner_id = u.id
      WHERE s.is_verified = TRUE OR u.account_type = 'entreprise'
      ORDER BY s.is_verified DESC, s.created_at DESC
      LIMIT $1
  `;
  const { rows } = await pool.query(query, [limit]);
  return rows;
}

/**
 * Lister toutes les boutiques (avec filtres)
 */
async function findAll(limit = 20, offset = 0, category = null, search = null) {
  let query = `
        SELECT s.*, u.name as owner_name, u.avatar_url as owner_avatar
        FROM shops s
        JOIN users u ON s.owner_id = u.id
        WHERE 1=1
    `;
  const params = [];
  let paramIndex = 1;

  if (category) {
    query += ` AND s.category = $${paramIndex++}`;
    params.push(category);
  }

  if (search) {
    query += ` AND (s.name ILIKE $${paramIndex} OR s.description ILIKE $${paramIndex})`;
    params.push(`%${search}%`);
    paramIndex++;
  }

  query += ` ORDER BY s.is_verified DESC, s.rating DESC, s.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
  params.push(limit, offset);

  const { rows } = await pool.query(query, params);
  return rows;
}

/**
 * Mettre à jour une boutique
 */
async function update(id, updates) {
  const fields = Object.keys(updates);
  if (fields.length === 0) return null;

  const setClause = fields.map((field, index) => `${field} = $${index + 2}`).join(', ');
  const values = [id, ...Object.values(updates)];

  const query = `
        UPDATE shops 
        SET ${setClause}, updated_at = NOW() 
        WHERE id = $1 
        RETURNING *
    `;

  const { rows } = await pool.query(query, values);
  return rows[0];
}

/**
 * Supprimer une boutique
 */
async function deleteById(id) {
  await pool.query("DELETE FROM shops WHERE id = $1", [id]);
}

module.exports = {
  create,
  findById,
  findByOwnerId,
  findVerified,
  findAll,
  update,
  deleteById
};
