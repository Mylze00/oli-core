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
 * Marquer l'utilisateur comme vérifié et nettoyer l'OTP
 */
async function markVerified(userId) {
  const query = `
    UPDATE users
    SET
      is_verified = true,
      otp_code = NULL,
      otp_expires_at = NULL,
      updated_at = NOW()
    WHERE id = $1
  `;
  await pool.query(query, [userId]);
}

module.exports = {
  findByPhone,
  createUser,
  saveOtp,
  verifyOtp,
  markVerified,
};