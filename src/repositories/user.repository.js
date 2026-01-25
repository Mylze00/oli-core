const pool = require("../config/db");

/**
 * Trouver un utilisateur par son numéro de téléphone
 */
async function findByPhone(phone) {
  const query = `
    SELECT *
    FROM users
    WHERE phone = $1
    LIMIT 1
  `;
  const { rows } = await pool.query(query, [phone]);
  return rows[0] || null;
}

/**
 * Trouver un utilisateur par son ID
 */
async function findById(userId) {
  const query = "SELECT * FROM users WHERE id = $1";
  const { rows } = await pool.query(query, [userId]);
  return rows[0];
}

/**
 * Generate a unique ID OLI
 */
function generateIdOli(phone) {
  const last4 = phone ? phone.slice(-4) : '0000';
  const random = Math.floor(1000 + Math.random() * 9000);
  return `OLI-${last4}-${random}`;
}

/**
 * Créer un nouvel utilisateur
 */
async function createUser(phone) {
  let idOli = generateIdOli(phone);

  // Petite boucle de sécurité pour l'unicité (simple retry)
  let retries = 3;
  while (retries > 0) {
    try {
      const query = `
        INSERT INTO users (phone, id_oli, is_verified, created_at, updated_at)
        VALUES ($1, $2, false, NOW(), NOW())
        RETURNING *
      `;
      const { rows } = await pool.query(query, [phone, idOli]);
      return rows[0];
    } catch (err) {
      if (err.code === '23505' && err.constraint === 'users_id_oli_key') { // Unique violation
        idOli = generateIdOli(phone);
        retries--;
        continue;
      }
      throw err;
    }
  }
  throw new Error("Impossible de générer un ID unique après plusieurs essais.");
}

/**
 * Sauvegarder l'OTP pour un utilisateur
 */
async function saveOtp(userId, otpCode, otpExpiresAt) {
  const query = `
    UPDATE users
    SET
      otp_code = $2::text,
      otp_expires_at = $3,
      updated_at = NOW()
    WHERE id = $1
  `;
  // On s'assure que otpCode est une string et on passe la date
  await pool.query(query, [userId, String(otpCode), otpExpiresAt]);
}

/**
 * Vérifier l'OTP
 */
async function verifyOtp(phone, otpCode) {
  const query = `
    SELECT *
    FROM users
    WHERE phone = $1
      AND otp_code = $2::text
      AND otp_expires_at > NOW()
    LIMIT 1
  `;

  // Utilisation de .trim() pour éviter les espaces invisibles
  const { rows } = await pool.query(query, [
    phone,
    String(otpCode).trim(),
  ]);

  return rows[0] || null;
}

/**
 * Nettoyer l'OTP après vérification réussie
 * IMPORTANT: Ne PAS marquer l'utilisateur comme vérifié automatiquement
 * La vérification (badge) doit être accordée manuellement par l'admin
 */
async function clearOtp(userId) {
  const query = `
    UPDATE users
    SET
      otp_code = NULL,
      otp_expires_at = NULL,
      updated_at = NOW()
    WHERE id = $1
  `;
  await pool.query(query, [userId]);
}

/**
 * Récupérer les produits visités
 */
async function findVisitedProducts(userId, limit) {
  const query = `
        SELECT 
            p.id,
            p.name,
            p.price,
            p.images,
            p.description,
            upv.viewed_at,
            u.name as seller_name
        FROM user_product_views upv
        INNER JOIN products p ON upv.product_id = p.id
        LEFT JOIN users u ON p.seller_id = u.id
        WHERE upv.user_id = $1
        ORDER BY upv.viewed_at DESC
        LIMIT $2
    `;
  const { rows } = await pool.query(query, [userId, limit]);
  return rows;
}

/**
 * Enregistrer une vue produit
 */
async function trackProductView(userId, productId) {
  const query = `
        INSERT INTO user_product_views (user_id, product_id, viewed_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id, product_id) 
        DO UPDATE SET viewed_at = NOW();
    `;
  await pool.query(query, [userId, productId]);
}

/**
 * Mettre à jour le nom
 */
async function updateName(userId, name) {
  const query = `
        UPDATE users 
        SET name = $1, updated_at = NOW(), last_profile_update = NOW()
        WHERE id = $2
        RETURNING id, name, phone, id_oli, avatar_url, wallet, is_seller, is_deliverer, last_profile_update
    `;
  const { rows } = await pool.query(query, [name, userId]);
  return rows[0];
}

module.exports = {
  findByPhone,
  findById,
  createUser,
  saveOtp,
  verifyOtp,
  clearOtp,
  findVisitedProducts,
  trackProductView,
  updateName
};