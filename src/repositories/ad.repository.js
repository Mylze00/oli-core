const pool = require('../config/db');

class AdRepository {
    async findAllActive() {
        const result = await pool.query("SELECT * FROM ads WHERE is_active = TRUE ORDER BY created_at DESC LIMIT 10");
        return result.rows;
    }

    async findAllAdmin() {
        const result = await pool.query("SELECT * FROM ads ORDER BY created_at DESC");
        return result.rows;
    }

    async create(adData) {
        const { image_url, title, link_url } = adData;
        const result = await pool.query(
            "INSERT INTO ads (image_url, title, link_url) VALUES ($1, $2, $3) RETURNING *",
            [image_url, title || '', link_url || '']
        );
        return result.rows[0];
    }

    async delete(id) {
        const result = await pool.query("DELETE FROM ads WHERE id = $1 RETURNING id", [id]);
        return result.rows.length > 0;
    }

    async toggleActive(id, isActive) {
        const result = await pool.query(
            "UPDATE ads SET is_active = $1 WHERE id = $2 RETURNING *",
            [isActive, id]
        );
        return result.rows[0];
    }
}

module.exports = new AdRepository();
