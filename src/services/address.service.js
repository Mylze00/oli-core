const pool = require('../config/db');

/**
 * Service pour la gestion des adresses utilisateur
 */

/**
 * Récupère toutes les adresses d'un utilisateur
 * @param {number} userId 
 */
async function getUserAddresses(userId) {
    const query = `
        SELECT * FROM addresses 
        WHERE user_id = $1 
        ORDER BY is_default DESC, created_at DESC
    `;
    const result = await pool.query(query, [userId]);
    return result.rows;
}

/**
 * Ajoute une nouvelle adresse
 * @param {number} userId 
 * @param {Object} addressData 
 */
async function addAddress(userId, { label, address, city, phone, is_default = false }) {
    // Si définie comme par défaut, on enlève le flag des autres
    if (is_default) {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    } else {
        // Si c'est la première adresse, elle devient par défaut automatiquement
        const count = await pool.query('SELECT COUNT(*) FROM addresses WHERE user_id = $1', [userId]);
        if (parseInt(count.rows[0].count) === 0) {
            is_default = true;
        }
    }

    const query = `
        INSERT INTO addresses (user_id, label, address, city, phone, is_default)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
    `;

    const result = await pool.query(query, [userId, label, address, city, phone, is_default]);
    return result.rows[0];
}

/**
 * Met à jour une adresse
 * @param {number} userId 
 * @param {number} addressId 
 * @param {Object} addressData 
 */
async function updateAddress(userId, addressId, { label, address, city, phone, is_default }) {
    if (is_default) {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    }

    const query = `
        UPDATE addresses 
        SET label = $1, address = $2, city = $3, phone = $4, is_default = $5
        WHERE id = $6 AND user_id = $7
        RETURNING *
    `;

    const result = await pool.query(query, [label, address, city, phone, is_default, addressId, userId]);

    if (result.rows.length === 0) {
        throw new Error('Adresse non trouvée ou non autorisée');
    }

    return result.rows[0];
}

/**
 * Supprime une adresse
 * @param {number} userId 
 * @param {number} addressId 
 */
async function deleteAddress(userId, addressId) {
    const query = 'DELETE FROM addresses WHERE id = $1 AND user_id = $2 RETURNING id';
    const result = await pool.query(query, [addressId, userId]);

    if (result.rows.length === 0) {
        throw new Error('Adresse non trouvée ou impossible à supprimer');
    }

    return true;
}

/**
 * Définit une adresse comme par défaut
 * @param {number} userId 
 * @param {number} addressId 
 */
async function setDefaultAddress(userId, addressId) {
    await pool.query('BEGIN');
    try {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);

        const result = await pool.query(`
            UPDATE addresses SET is_default = TRUE 
            WHERE id = $1 AND user_id = $2 
            RETURNING *
        `, [addressId, userId]);

        if (result.rows.length === 0) {
            throw new Error('Adresse non trouvée');
        }

        await pool.query('COMMIT');
        return result.rows[0];
    } catch (e) {
        await pool.query('ROLLBACK');
        throw e;
    }
}

module.exports = {
    getUserAddresses,
    addAddress,
    updateAddress,
    deleteAddress,
    setDefaultAddress
};
