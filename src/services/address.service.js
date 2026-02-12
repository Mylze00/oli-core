const pool = require('../config/db');

/**
 * Service pour la gestion des adresses utilisateur
 * Champs structurés: avenue, numéro, quartier, commune, ville
 * + coordonnées GPS pour calcul de distance
 */

/**
 * Récupère toutes les adresses d'un utilisateur
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
 * Construit l'adresse complète à partir des champs structurés
 */
function buildFullAddress({ avenue, numero, quartier, commune, ville }) {
    const parts = [];
    if (avenue) parts.push(numero ? `${avenue} N°${numero}` : avenue);
    if (quartier) parts.push(`Q/${quartier}`);
    if (commune) parts.push(`C/${commune}`);
    if (ville) parts.push(ville);
    return parts.join(', ') || null;
}

/**
 * Ajoute une nouvelle adresse
 */
async function addAddress(userId, data) {
    const {
        label, address, city, phone, is_default = false,
        avenue, numero, quartier, commune, ville, province,
        reference_point, latitude, longitude
    } = data;

    // Construire l'adresse complète si pas fournie mais champs structurés présents
    const fullAddress = address || buildFullAddress({ avenue, numero, quartier, commune, ville });

    // Si définie comme par défaut, on enlève le flag des autres
    let setDefault = is_default;
    if (setDefault) {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    } else {
        const count = await pool.query('SELECT COUNT(*) FROM addresses WHERE user_id = $1', [userId]);
        if (parseInt(count.rows[0].count) === 0) {
            setDefault = true;
        }
    }

    const query = `
        INSERT INTO addresses (
            user_id, label, address, city, phone, is_default,
            avenue, numero, quartier, commune, ville, province,
            reference_point, latitude, longitude
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING *
    `;

    const result = await pool.query(query, [
        userId, label || null, fullAddress, city || commune || null, phone || null, setDefault,
        avenue || null, numero || null, quartier || null, commune || null,
        ville || 'Kinshasa', province || null,
        reference_point || null, latitude || null, longitude || null
    ]);
    return result.rows[0];
}

/**
 * Met à jour une adresse
 */
async function updateAddress(userId, addressId, data) {
    const {
        label, address, city, phone, is_default,
        avenue, numero, quartier, commune, ville, province,
        reference_point, latitude, longitude
    } = data;

    const fullAddress = address || buildFullAddress({ avenue, numero, quartier, commune, ville });

    if (is_default) {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    }

    const query = `
        UPDATE addresses 
        SET label = $1, address = $2, city = $3, phone = $4, is_default = $5,
            avenue = $6, numero = $7, quartier = $8, commune = $9, ville = $10,
            province = $11, reference_point = $12, latitude = $13, longitude = $14,
            updated_at = NOW()
        WHERE id = $15 AND user_id = $16
        RETURNING *
    `;

    const result = await pool.query(query, [
        label, fullAddress, city || commune || null, phone, is_default,
        avenue || null, numero || null, quartier || null, commune || null,
        ville || 'Kinshasa', province || null,
        reference_point || null, latitude || null, longitude || null,
        addressId, userId
    ]);

    if (result.rows.length === 0) {
        throw new Error('Adresse non trouvée ou non autorisée');
    }

    return result.rows[0];
}

/**
 * Supprime une adresse
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
 */
async function setDefaultAddress(userId, addressId) {
    await pool.query('BEGIN');
    try {
        await pool.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);

        const result = await pool.query(`
            UPDATE addresses SET is_default = TRUE, updated_at = NOW()
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

/**
 * Récupère l'adresse par défaut d'un utilisateur
 */
async function getDefaultAddress(userId) {
    const result = await pool.query(
        'SELECT * FROM addresses WHERE user_id = $1 AND is_default = TRUE LIMIT 1',
        [userId]
    );
    return result.rows[0] || null;
}

module.exports = {
    getUserAddresses,
    addAddress,
    updateAddress,
    deleteAddress,
    setDefaultAddress,
    getDefaultAddress
};
