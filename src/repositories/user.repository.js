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
 * Créer un nouvel utilisateur
 */
async function createUser(phone) {
  const query = `
    INSERT INTO users (phone, is_verified, created_at, updated_at)
    VALUES ($1, false, NOW(), NOW())
    RETURNING *
  `;
  const { rows } = await pool.query(query, [phone]);
  return rows[0];
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