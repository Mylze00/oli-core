/**
 * Routes Admin - Gestion Utilisateurs
 * GET /admin/users/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/users
 * Liste tous les utilisateurs avec filtres
 */
router.get('/', async (req, res) => {
    try {
        const { search, role, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT 
                id, phone, name, id_oli, wallet, avatar_url,
                is_admin, is_seller, is_deliverer, is_suspended, is_verified,
                created_at, last_profile_update
            FROM users
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        // Filtre recherche
        if (search) {
            query += ` AND (phone ILIKE $${paramIndex} OR name ILIKE $${paramIndex} OR id_oli ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        // Filtre rôle
        if (role === 'admin') query += ` AND is_admin = TRUE`;
        if (role === 'seller') query += ` AND is_seller = TRUE`;
        if (role === 'deliverer') query += ` AND is_deliverer = TRUE`;
        if (role === 'verified') query += ` AND is_verified = TRUE`;

        query += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/users:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id
 * Détails d'un utilisateur spécifique
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const userResult = await pool.query(`
            SELECT * FROM users WHERE id = $1
        `, [id]);

        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur non trouvé' });
        }

        // Stats produits vendus
        const productsCount = await pool.query(`
            SELECT COUNT(*) as count FROM products WHERE seller_id = $1
        `, [id]);

        // Historique des transactions (si la table existe)
        let transactions = [];
        try {
            const txResult = await pool.query(`
                SELECT * FROM transactions 
                WHERE user_id = $1 
                ORDER BY created_at DESC 
                LIMIT 50
            `, [id]);
            transactions = txResult.rows;
        } catch (err) {
            console.warn("Table transactions non trouvée ou erreur:", err.message);
            // On ignore l'erreur pour ne pas bloquer l'affichage du user
        }

        res.json({
            user: userResult.rows[0],
            transactions: transactions,
            stats: {
                products_count: parseInt(productsCount.rows[0].count)
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/users/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/role
 * Modifier les rôles d'un utilisateur
 */
router.patch('/:id/role', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_admin, is_seller, is_deliverer } = req.body;

        const updates = [];
        const values = [];
        let paramIndex = 1;

        if (typeof is_admin === 'boolean') {
            updates.push(`is_admin = $${paramIndex++}`);
            values.push(is_admin);
        }
        if (typeof is_seller === 'boolean') {
            updates.push(`is_seller = $${paramIndex++}`);
            values.push(is_seller);
        }
        if (typeof is_deliverer === 'boolean') {
            updates.push(`is_deliverer = $${paramIndex++}`);
            values.push(is_deliverer);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'Aucune modification fournie' });
        }

        values.push(id);
        const result = await pool.query(`
            UPDATE users 
            SET ${updates.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIndex}
            RETURNING *
        `, values);

        res.json({
            message: 'Rôle mis à jour',
            user: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/role:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/suspend
 * Suspendre/débloquer un utilisateur
 */
router.post('/:id/suspend', async (req, res) => {
    try {
        const { id } = req.params;
        const { suspended } = req.body;

        await pool.query(`
            UPDATE users 
            SET is_suspended = $1, updated_at = NOW()
            WHERE id = $2
        `, [suspended, id]);

        res.json({
            message: suspended ? 'Utilisateur suspendu' : 'Utilisateur débloqué'
        });
    } catch (err) {
        console.error('Erreur POST /admin/users/:id/suspend:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/verify
 * Toggle le statut vérifié d'un utilisateur
 */
router.patch('/:id/verify', async (req, res) => {
    try {
        const { id } = req.params;
        const { verified } = req.body;

        const result = await pool.query(`
            UPDATE users 
            SET is_verified = $1, updated_at = NOW()
            WHERE id = $2
            RETURNING id, name, phone, is_verified
        `, [verified, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur non trouvé' });
        }

        res.json({
            message: verified ? 'Utilisateur vérifié' : 'Vérification retirée',
            user: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/verify:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/account-type
 * Modifier le type de compte d'un utilisateur
 */
router.patch('/:id/account-type', async (req, res) => {
    try {
        const { id } = req.params;
        const { account_type, has_certified_shop } = req.body;

        const updates = [];
        const values = [];
        let paramIndex = 1;

        if (account_type) {
            const validTypes = ['ordinaire', 'certifie', 'premium', 'entreprise'];
            if (!validTypes.includes(account_type)) {
                return res.status(400).json({ error: 'Type de compte invalide' });
            }
            updates.push(`account_type = $${paramIndex++}`);
            values.push(account_type);
        }

        if (typeof has_certified_shop === 'boolean') {
            updates.push(`has_certified_shop = $${paramIndex++}`);
            values.push(has_certified_shop);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'Aucune modification fournie' });
        }

        values.push(id);
        const result = await pool.query(`
            UPDATE users 
            SET ${updates.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIndex}
            RETURNING id, name, phone, account_type, has_certified_shop
        `, values);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur non trouvé' });
        }

        res.json({
            message: 'Type de compte mis à jour',
            user: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/account-type:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id/products
 * Récupérer les produits d'un utilisateur
 */
router.get('/:id/products', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`
            SELECT * FROM products 
            WHERE seller_id = $1 
            ORDER BY created_at DESC
        `, [id]);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/users/:id/products:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/message
 * Envoyer un message interne à l'utilisateur (Chat)
 */
router.post('/:id/message', async (req, res) => {
    const client = await pool.connect();
    try {
        const { id: targetUserId } = req.params;
        const { content } = req.body;
        const adminId = req.user.id; // L'admin connecté

        if (!content) return res.status(400).json({ error: 'Message vide' });

        await client.query('BEGIN');

        // 1. Chercher une conversation existante entre ces deux users
        // On cherche une conversation où les deux users sont participants
        const findConvQuery = `
            SELECT cp1.conversation_id 
            FROM conversation_participants cp1
            JOIN conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
            WHERE cp1.user_id = $1 AND cp2.user_id = $2
            LIMIT 1
        `;
        let convResult = await client.query(findConvQuery, [adminId, targetUserId]);

        let conversationId;

        if (convResult.rows.length > 0) {
            conversationId = convResult.rows[0].conversation_id;
        } else {
            // 2. Créer nouvelle conversation si inexistante
            const newConv = await client.query(`
                INSERT INTO conversations (created_at, updated_at) VALUES (NOW(), NOW()) RETURNING id
            `);
            conversationId = newConv.rows[0].id;

            // Ajouter les participants
            await client.query(`
                INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
                VALUES ($1, $2, NOW()), ($1, $3, NOW())
            `, [conversationId, adminId, targetUserId]);
        }

        // 3. Insérer le message
        const insertMsg = await client.query(`
            INSERT INTO messages (conversation_id, sender_id, content, type, created_at, is_read)
            VALUES ($1, $2, $3, 'text', NOW(), false)
            RETURNING *
        `, [conversationId, adminId, content]);

        // 4. Mettre à jour la date de la conversation
        await client.query(`UPDATE conversations SET updated_at = NOW() WHERE id = $1`, [conversationId]);

        await client.query('COMMIT');

        res.json({ success: true, message: insertMsg.rows[0] });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erreur POST /admin/users/:id/message:', err);
        res.status(500).json({ error: 'Erreur envoi message' });
    } finally {
        client.release();
    }
});

module.exports = router;
