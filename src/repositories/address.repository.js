const pool = require("../config/db");

/**
 * Repository pour la gestion des adresses
 */

/**
 * Créer une nouvelle adresse
 */
async function createAddress(data) {
    const query = `
        INSERT INTO addresses (
            user_id, label, address, city, phone,
            is_default, latitude, longitude
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
    `;

    const { rows } = await pool.query(query, [
        data.userId,
        data.label,
        data.address,
        data.city,
        data.phone,
        data.isDefault || false,
        data.latitude,
        data.longitude
    ]);

    // Si c'est l'adresse par défaut, désactiver les autres
    if (data.isDefault) {
        await pool.query(
            `UPDATE addresses 
             SET is_default = false 
             WHERE user_id = $1 AND id != $2`,
            [data.userId, rows[0].id]
        );
    }

    return rows[0];
}

/**
 * Récupérer toutes les adresses d'un utilisateur
 */
async function findByUserId(userId) {
    const query = `
        SELECT * FROM addresses
        WHERE user_id = $1
        ORDER BY is_default DESC, created_at DESC
    `;

    const { rows } = await pool.query(query, [userId]);
    return rows;
}

/**
 * Récupérer l'adresse par défaut d'un utilisateur
 */
async function getDefaultAddress(userId) {
    const query = `
        SELECT * FROM addresses
        WHERE user_id = $1 AND is_default = true
        LIMIT 1
    `;

    const { rows } = await pool.query(query, [userId]);
    return rows[0];
}

/**
 * Mettre à jour une adresse
 */
async function updateAddress(addressId, userId, data) {
    const query = `
        UPDATE addresses
        SET 
            label = COALESCE($1, label),
            address = COALESCE($2, address),
            city = COALESCE($3, city),
            phone = COALESCE($4, phone),
            latitude = COALESCE($5, latitude),
            longitude = COALESCE($6, longitude),
            is_default = COALESCE($7, is_default)
        WHERE id = $8 AND user_id = $9
        RETURNING *
    `;

    const { rows } = await pool.query(query, [
        data.label,
        data.address,
        data.city,
        data.phone,
        data.latitude,
        data.longitude,
        data.isDefault,
        addressId,
        userId
    ]);

    // Si c'est l'adresse par défaut, désactiver les autres
    if (data.isDefault && rows.length > 0) {
        await pool.query(
            `UPDATE addresses 
             SET is_default = false 
             WHERE user_id = $1 AND id != $2`,
            [userId, addressId]
        );
    }

    return rows[0];
}

/**
 * Supprimer une adresse
 */
async function deleteAddress(addressId, userId) {
    const query = `
        DELETE FROM addresses
        WHERE id = $1 AND user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [addressId, userId]);
    return rows[0];
}

/**
 * Vérifier une adresse
 */
async function verifyAddress(addressId, method) {
    const query = `
        UPDATE addresses
        SET 
            is_verified = true,
            verified_at = NOW(),
            verification_method = $1
        WHERE id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [method, addressId]);
    return rows[0];
}

module.exports = {
    createAddress,
    findByUserId,
    getDefaultAddress,
    updateAddress,
    deleteAddress,
    verifyAddress
};
