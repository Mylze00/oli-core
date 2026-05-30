/**
 * Routes Admin - Gestion Utilisateurs
 * GET /admin/users/*
 */
const express = require('express');
const router = express.Router();
const { BASE_URL } = require('../../config');
const pool = require('../../config/db');

/**
 * GET /admin/users
 * Liste tous les utilisateurs avec filtres, pagination et stats
 */
router.get('/', async (req, res) => {
    try {
        const { search, role, status, limit = 30, offset = 0 } = req.query;

        const conditions = [];
        const params = [];
        let paramIndex = 1;

        if (search) {
            conditions.push(`(phone ILIKE $${paramIndex} OR name ILIKE $${paramIndex} OR id_oli ILIKE $${paramIndex})`);
            params.push(`%${search}%`);
            paramIndex++;
        }

        if (role === 'admin') conditions.push('is_admin = TRUE');
        if (role === 'seller') conditions.push('is_seller = TRUE');
        if (role === 'deliverer') conditions.push('is_deliverer = TRUE');
        if (role === 'verified') conditions.push('is_verified = TRUE');

        if (status === 'suspended') conditions.push('is_suspended = TRUE');
        if (status === 'active') conditions.push('(is_suspended = FALSE OR is_suspended IS NULL)');

        const whereClause = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';

        const countResult = await pool.query(
            `SELECT COUNT(*) as total FROM users ${whereClause}`,
            params.slice(0, paramIndex - 1)
        );

        const listParams = [...params.slice(0, paramIndex - 1)];
        const limitIdx = paramIndex++;
        const offsetIdx = paramIndex++;
        listParams.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(`
            SELECT 
                u.id, u.phone, u.name, u.id_oli, u.avatar_url,
                u.is_admin, u.is_seller, u.is_deliverer, u.is_suspended, u.is_verified,
                u.account_type, u.has_certified_shop,
                u.created_at, u.last_profile_update,
                COALESCE(w.balance, u.wallet::DECIMAL, 0) as wallet
            FROM users u
            LEFT JOIN wallets w ON w.user_id = u.id
            ${whereClause}
            ORDER BY u.created_at DESC 
            LIMIT $${limitIdx} OFFSET $${offsetIdx}
        `, listParams);

        const statsResult = await pool.query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE is_seller = TRUE) as sellers,
                COUNT(*) FILTER (WHERE is_admin = TRUE) as admins,
                COUNT(*) FILTER (WHERE is_deliverer = TRUE) as deliverers,
                COUNT(*) FILTER (WHERE is_suspended = TRUE) as suspended,
                COUNT(*) FILTER (WHERE is_verified = TRUE) as verified,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_this_week
            FROM users
        `);

        res.json({
            users: result.rows,
            total: parseInt(countResult.rows[0].total),
            stats: {
                total: parseInt(statsResult.rows[0].total),
                sellers: parseInt(statsResult.rows[0].sellers),
                admins: parseInt(statsResult.rows[0].admins),
                deliverers: parseInt(statsResult.rows[0].deliverers),
                suspended: parseInt(statsResult.rows[0].suspended),
                verified: parseInt(statsResult.rows[0].verified),
                new_this_week: parseInt(statsResult.rows[0].new_this_week),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/users:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id
 * Détails complets d'un utilisateur
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const userResult = await pool.query(`SELECT * FROM users WHERE id = $1`, [id]);

        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur non trouvé' });
        }

        // ── Solde réel depuis la table wallets ──
        let walletBalance = parseFloat(userResult.rows[0].wallet || 0);
        try {
            const wRes = await pool.query('SELECT balance FROM wallets WHERE user_id = $1', [id]);
            if (wRes.rows.length > 0) walletBalance = parseFloat(wRes.rows[0].balance);
        } catch (e) { console.warn('wallets query error:', e.message); }

        // ── Transactions wallet depuis wallet_transactions ──
        let walletTransactions = [];
        try {
            const wtRes = await pool.query(
                `SELECT id, type, amount, description, reference, status, created_at
                 FROM wallet_transactions WHERE user_id = $1
                 ORDER BY created_at DESC LIMIT 50`,
                [id]
            );
            walletTransactions = wtRes.rows;
        } catch (e) {
            try {
                const txRes = await pool.query(
                    `SELECT * FROM transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`, [id]
                );
                walletTransactions = txRes.rows;
            } catch (e2) { console.warn('transactions fallback error:', e2.message); }
        }

        // ── Stats produits ──
        const productsCount = await pool.query(
            `SELECT COUNT(*) as count FROM products WHERE seller_id = $1`, [id]
        );

        // ── Stats commandes (acheteur) ──
        let ordersStats = { total: 0, paid: 0, total_spent: 0 };
        try {
            const ordersResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE status = 'paid' OR status = 'delivered' OR status = 'shipped') as paid,
                    COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid' OR status = 'delivered' OR status = 'shipped'), 0) as total_spent
                FROM orders WHERE user_id = $1
            `, [id]);
            ordersStats = {
                total: parseInt(ordersResult.rows[0].total),
                paid: parseInt(ordersResult.rows[0].paid),
                total_spent: parseFloat(ordersResult.rows[0].total_spent),
            };
        } catch (e) { console.warn('orders stats error:', e.message); }

        // ── Stats commandes (vendeur) ──
        let sellerOrdersStats = { total: 0, revenue: 0 };
        try {
            const soResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid' OR status = 'delivered' OR status = 'shipped'), 0) as revenue
                FROM orders WHERE seller_id = $1
            `, [id]);
            sellerOrdersStats = {
                total: parseInt(soResult.rows[0].total),
                revenue: parseFloat(soResult.rows[0].revenue),
            };
        } catch (e) { console.warn('seller orders stats error:', e.message); }

        // ── Stats conversations ──
        let conversationsCount = 0, messagesCount = 0;
        try {
            const convResult = await pool.query(`
                SELECT COUNT(DISTINCT cp.conversation_id) as conv_count
                FROM conversation_participants cp WHERE cp.user_id = $1
            `, [id]);
            conversationsCount = parseInt(convResult.rows[0].conv_count);

            const msgResult = await pool.query(
                `SELECT COUNT(*) as count FROM messages WHERE sender_id = $1`, [id]
            );
            messagesCount = parseInt(msgResult.rows[0].count);
        } catch (e) { console.warn('conversations stats error:', e.message); }

        // ── Boutique ──
        let shops = [];
        try {
            const shopResult = await pool.query(`
                SELECT id, name, description, category, location, logo_url, created_at 
                FROM shops WHERE owner_id = $1 ORDER BY created_at DESC
            `, [id]);
            shops = shopResult.rows;
        } catch (e) { console.warn('shops error:', e.message); }

        // ── Commandes récentes (acheteur) ──
        let recentOrders = [];
        try {
            const roResult = await pool.query(`
                SELECT id, total_amount, status, created_at
                FROM orders WHERE user_id = $1
                ORDER BY created_at DESC LIMIT 10
            `, [id]);
            recentOrders = roResult.rows;
        } catch (e) { console.warn('recent orders error:', e.message); }

        res.json({
            user: userResult.rows[0],
            wallet_balance: walletBalance,      // Solde réel FC depuis wallets
            transactions: walletTransactions,   // Depuis wallet_transactions
            recentOrders,
            shops,
            stats: {
                products_count: parseInt(productsCount.rows[0].count),
                orders: ordersStats,
                seller_orders: sellerOrdersStats,
                conversations: conversationsCount,
                messages: messagesCount,
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/users/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/wallet
 * Modifier le solde du wallet d'un utilisateur (Admin uniquement)
 */
router.patch('/:id/wallet', async (req, res) => {
    const client = await pool.connect();
    try {
        const { id } = req.params;
        const { amount, reason } = req.body;
        const adminId = req.user?.id || 0;

        if (amount === undefined || isNaN(parseFloat(amount))) {
            return res.status(400).json({ error: 'Montant invalide' });
        }
        const newBalance = parseFloat(amount);
        if (newBalance < 0) {
            return res.status(400).json({ error: 'Le solde ne peut pas être négatif' });
        }

        await client.query('BEGIN');

        // Lire le solde actuel
        const currentRes = await client.query(
            'SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE', [id]
        );
        const oldBalance = currentRes.rows.length > 0 ? parseFloat(currentRes.rows[0].balance) : 0;

        if (currentRes.rows.length === 0) {
            // Créer le wallet s'il n'existe pas
            await client.query(
                "INSERT INTO wallets (user_id, balance, currency) VALUES ($1, $2, 'FC') ON CONFLICT (user_id) DO UPDATE SET balance = $2, updated_at = NOW()",
                [id, newBalance]
            );
        } else {
            await client.query(
                'UPDATE wallets SET balance = $1, updated_at = NOW() WHERE user_id = $2',
                [newBalance, id]
            );
        }

        // Sync users.wallet pour compatibilité
        await client.query('UPDATE users SET wallet = $1 WHERE id = $2', [newBalance, id]);

        // Enregistrer la transaction
        const diff = newBalance - oldBalance;
        await client.query(`
            INSERT INTO wallet_transactions
                (user_id, type, amount, balance_before, balance_after, currency, description, status, metadata)
            VALUES ($1, 'system_credit', $2, $3, $4, 'FC', $5, 'completed', $6)
        `, [
            id,
            Math.abs(diff),
            oldBalance,
            newBalance,
            reason || `Ajustement administrateur (#${adminId})`,
            JSON.stringify({ admin_id: adminId, reason: reason || 'manual_adjustment', old_balance: oldBalance, new_balance: newBalance })
        ]);

        await client.query('COMMIT');

        res.json({
            success: true,
            message: `Solde mis à jour : ${oldBalance} FC → ${newBalance} FC`,
            oldBalance,
            newBalance,
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erreur PATCH /admin/users/:id/wallet:', err);
        res.status(500).json({ error: 'Erreur serveur: ' + err.message });
    } finally {
        client.release();
    }
});

/**
 * PATCH /admin/users/:id/role
 */
router.patch('/:id/role', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_admin, is_seller, is_deliverer } = req.body;

        const updates = [];
        const values = [];
        let paramIndex = 1;

        if (typeof is_admin === 'boolean') { updates.push(`is_admin = $${paramIndex++}`); values.push(is_admin); }
        if (typeof is_seller === 'boolean') { updates.push(`is_seller = $${paramIndex++}`); values.push(is_seller); }
        if (typeof is_deliverer === 'boolean') { updates.push(`is_deliverer = $${paramIndex++}`); values.push(is_deliverer); }

        if (updates.length === 0) return res.status(400).json({ error: 'Aucune modification fournie' });

        values.push(id);
        const result = await pool.query(`
            UPDATE users SET ${updates.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIndex} RETURNING *
        `, values);

        res.json({ message: 'Rôle mis à jour', user: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/role:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/suspend
 */
router.post('/:id/suspend', async (req, res) => {
    try {
        const { id } = req.params;
        const { suspended } = req.body;
        await pool.query(`UPDATE users SET is_suspended = $1, updated_at = NOW() WHERE id = $2`, [suspended, id]);
        res.json({ message: suspended ? 'Utilisateur suspendu' : 'Utilisateur débloqué' });
    } catch (err) {
        console.error('Erreur POST /admin/users/:id/suspend:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/hide
 */
router.post('/:id/hide', async (req, res) => {
    try {
        const { id } = req.params;
        const { hidden } = req.body;
        const result = await pool.query(`
            UPDATE users SET is_hidden = $1, updated_at = NOW()
            WHERE id = $2 RETURNING id, name, is_hidden
        `, [hidden, id]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Utilisateur non trouvé' });
        res.json({ message: hidden ? 'Utilisateur masqué' : 'Utilisateur visible', user: result.rows[0] });
    } catch (err) {
        console.error('Erreur POST /admin/users/:id/hide:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/verify
 */
router.patch('/:id/verify', async (req, res) => {
    try {
        const { id } = req.params;
        const { verified } = req.body;
        const result = await pool.query(`
            UPDATE users SET is_verified = $1, updated_at = NOW()
            WHERE id = $2 RETURNING id, name, phone, is_verified
        `, [verified, id]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Utilisateur non trouvé' });
        res.json({ message: verified ? 'Utilisateur vérifié' : 'Vérification retirée', user: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/verify:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/account-type
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
            if (!validTypes.includes(account_type)) return res.status(400).json({ error: 'Type de compte invalide' });
            updates.push(`account_type = $${paramIndex++}`);
            values.push(account_type);
        }
        if (typeof has_certified_shop === 'boolean') {
            updates.push(`has_certified_shop = $${paramIndex++}`);
            values.push(has_certified_shop);
        }
        if (updates.length === 0) return res.status(400).json({ error: 'Aucune modification fournie' });

        values.push(id);
        const result = await pool.query(`
            UPDATE users SET ${updates.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIndex} RETURNING id, name, phone, account_type, has_certified_shop
        `, values);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Utilisateur non trouvé' });

        const updatedUser = result.rows[0];

        if (account_type === 'entreprise') {
            const shopRepo = require('../../repositories/shop.repository');
            const userShops = await shopRepo.findByOwnerId(id);
            if (userShops.length === 0) {
                await shopRepo.create({
                    owner_id: id,
                    name: updatedUser.name || 'Boutique Entreprise',
                    description: 'Boutique officielle',
                    category: 'Autres',
                    location: 'En ligne',
                    logo_url: null,
                    banner_url: null
                });
            }
        }

        res.json({ message: 'Type de compte mis à jour', user: updatedUser });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/account-type:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id/products
 */
router.get('/:id/products', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`
            SELECT id, name, description, price, category, images, status, created_at
            FROM products WHERE seller_id = $1 ORDER BY created_at DESC
        `, [id]);

        const products = result.rows.map(p => {
            let image_url = null;
            if (p.images && p.images.length > 0) {
                const first = p.images[0];
                image_url = first.startsWith('http') ? first : `${BASE_URL}/uploads/${first}`;
            }
            return { ...p, image_url };
        });

        res.json(products);
    } catch (err) {
        console.error('Erreur GET /admin/users/:id/products:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id/conversations
 */
router.get('/:id/conversations', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`
            SELECT 
                c.id as conversation_id,
                c.type,
                c.updated_at,
                u.id as other_id,
                u.name as other_name,
                u.phone as other_phone,
                u.avatar_url as other_avatar,
                p.id as product_id,
                p.name as product_name,
                p.price as product_price,
                p.images as product_images,
                m.content as last_message,
                m.type as last_message_type,
                m.created_at as last_time,
                m.sender_id as last_sender_id,
                (SELECT COUNT(*) FROM messages msg WHERE msg.conversation_id = c.id) as total_messages
            FROM conversation_participants cp
            JOIN conversations c ON cp.conversation_id = c.id
            JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
            JOIN users u ON cp2.user_id = u.id
            LEFT JOIN products p ON c.product_id = p.id
            LEFT JOIN LATERAL (
                SELECT content, type, created_at, sender_id 
                FROM messages WHERE conversation_id = c.id 
                ORDER BY created_at DESC LIMIT 1
            ) m ON true
            WHERE cp.user_id = $1
            ORDER BY COALESCE(m.created_at, c.updated_at) DESC
        `, [id]);

        const conversations = result.rows.map(row => {
            let product_image = null;
            if (row.product_images && row.product_images.length > 0) {
                const first = row.product_images[0];
                product_image = first.startsWith('http') ? first : `${BASE_URL}/uploads/${first}`;
            }
            return { ...row, product_image, product_images: undefined, total_messages: parseInt(row.total_messages) };
        });

        res.json(conversations);
    } catch (err) {
        console.error('Erreur GET /admin/users/:id/conversations:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/message
 */
router.post('/:id/message', async (req, res) => {
    const client = await pool.connect();
    try {
        const { id: targetUserId } = req.params;
        const { content } = req.body;
        const adminId = req.user.id;

        if (!content) return res.status(400).json({ error: 'Message vide' });

        await client.query('BEGIN');

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
            const newConv = await client.query(`INSERT INTO conversations (created_at, updated_at) VALUES (NOW(), NOW()) RETURNING id`);
            conversationId = newConv.rows[0].id;
            await client.query(`
                INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
                VALUES ($1, $2, NOW()), ($1, $3, NOW())
            `, [conversationId, adminId, targetUserId]);
        }

        const insertMsg = await client.query(`
            INSERT INTO messages (conversation_id, sender_id, content, type, created_at, is_read)
            VALUES ($1, $2, $3, 'text', NOW(), false) RETURNING *
        `, [conversationId, adminId, content]);

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
