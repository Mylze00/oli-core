/**
 * Routes Admin - Gestion de la Base de Données
 * Permet de monitorer, explorer et gérer la base de données PostgreSQL
 */
const express = require('express');
const router = express.Router();
const { pool } = require('../../config/db');

// ============================================================
// GET /admin/database/stats - Statistiques globales
// ============================================================
router.get('/stats', async (req, res) => {
    try {
        // Taille de la base de données
        const dbSize = await pool.query(`
            SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size,
                   pg_database_size(current_database()) AS db_size_bytes
        `);

        // Nombre de tables
        const tableCount = await pool.query(`
            SELECT COUNT(*) AS count 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);

        // Nombre total de lignes (estimé)
        const rowEstimates = await pool.query(`
            SELECT SUM(n_live_tup) AS total_rows
            FROM pg_stat_user_tables
        `);

        // Nombre d'index
        const indexCount = await pool.query(`
            SELECT COUNT(*) AS count 
            FROM pg_indexes 
            WHERE schemaname = 'public'
        `);

        // Connexions actives
        const connections = await pool.query(`
            SELECT COUNT(*) AS active,
                   (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max
            FROM pg_stat_activity
            WHERE state = 'active'
        `);

        // Version PostgreSQL
        const version = await pool.query(`SELECT version()`);

        // Top 5 plus grosses tables
        const topTables = await pool.query(`
            SELECT relname AS table_name,
                   n_live_tup AS row_count,
                   pg_size_pretty(pg_total_relation_size(relid)) AS total_size
            FROM pg_stat_user_tables
            ORDER BY n_live_tup DESC
            LIMIT 5
        `);

        res.json({
            database: {
                size: dbSize.rows[0].db_size,
                size_bytes: parseInt(dbSize.rows[0].db_size_bytes),
                tables: parseInt(tableCount.rows[0].count),
                total_rows: parseInt(rowEstimates.rows[0].total_rows || 0),
                indexes: parseInt(indexCount.rows[0].count),
                version: version.rows[0].version.split(' ').slice(0, 2).join(' '),
            },
            connections: {
                active: parseInt(connections.rows[0].active),
                max: parseInt(connections.rows[0].max),
            },
            top_tables: topTables.rows,
        });
    } catch (error) {
        console.error('❌ [DB Admin] Stats error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// GET /admin/database/tables - Liste des tables
// ============================================================
router.get('/tables', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                t.table_name,
                COALESCE(s.n_live_tup, 0) AS row_count,
                pg_size_pretty(pg_total_relation_size(quote_ident(t.table_name))) AS total_size,
                pg_total_relation_size(quote_ident(t.table_name)) AS size_bytes,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_name = t.table_name AND c.table_schema = 'public') AS column_count
            FROM information_schema.tables t
            LEFT JOIN pg_stat_user_tables s ON t.table_name = s.relname
            WHERE t.table_schema = 'public'
            AND t.table_type = 'BASE TABLE'
            ORDER BY COALESCE(s.n_live_tup, 0) DESC
        `);

        res.json(result.rows);
    } catch (error) {
        console.error('❌ [DB Admin] Tables list error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// GET /admin/database/tables/:name - Détails d'une table
// ============================================================
router.get('/tables/:name', async (req, res) => {
    try {
        const tableName = req.params.name;

        // Vérifier que la table existe
        const exists = await pool.query(`
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = $1
        `, [tableName]);

        if (exists.rows.length === 0) {
            return res.status(404).json({ error: 'Table not found' });
        }

        // Colonnes
        const columns = await pool.query(`
            SELECT column_name, data_type, is_nullable, column_default,
                   character_maximum_length
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = $1
            ORDER BY ordinal_position
        `, [tableName]);

        // Contraintes
        const constraints = await pool.query(`
            SELECT tc.constraint_name, tc.constraint_type,
                   kcu.column_name,
                   ccu.table_name AS foreign_table,
                   ccu.column_name AS foreign_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            LEFT JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name AND tc.constraint_type = 'FOREIGN KEY'
            WHERE tc.table_schema = 'public' AND tc.table_name = $1
        `, [tableName]);

        // Index
        const indexes = await pool.query(`
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE schemaname = 'public' AND tablename = $1
        `, [tableName]);

        // Nombre de lignes
        const count = await pool.query(`
            SELECT n_live_tup AS row_count
            FROM pg_stat_user_tables
            WHERE relname = $1
        `, [tableName]);

        res.json({
            table_name: tableName,
            row_count: count.rows[0]?.row_count || 0,
            columns: columns.rows,
            constraints: constraints.rows,
            indexes: indexes.rows,
        });
    } catch (error) {
        console.error('❌ [DB Admin] Table detail error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// GET /admin/database/tables/:name/data - Données paginées
// ============================================================
router.get('/tables/:name/data', async (req, res) => {
    try {
        const tableName = req.params.name;
        const page = parseInt(req.query.page) || 1;
        const limit = Math.min(parseInt(req.query.limit) || 50, 100);
        const offset = (page - 1) * limit;
        const sortBy = req.query.sort || 'id';
        const sortOrder = req.query.order === 'asc' ? 'ASC' : 'DESC';
        const search = req.query.search || '';

        // Vérifier que la table existe
        const exists = await pool.query(`
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = $1
        `, [tableName]);

        if (exists.rows.length === 0) {
            return res.status(404).json({ error: 'Table not found' });
        }

        // Vérifier que la colonne de tri existe
        const colCheck = await pool.query(`
            SELECT column_name FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2
        `, [tableName, sortBy]);

        const safeSort = colCheck.rows.length > 0 ? sortBy : 'id';

        // Si fallback 'id' n'existe pas non plus, on prend la première colonne
        let orderClause;
        if (safeSort === 'id') {
            const firstCol = await pool.query(`
                SELECT column_name FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = $1
                ORDER BY ordinal_position LIMIT 1
            `, [tableName]);
            orderClause = `"${firstCol.rows[0].column_name}" ${sortOrder}`;
        } else {
            orderClause = `"${safeSort}" ${sortOrder}`;
        }

        // Compter le total
        const countResult = await pool.query(
            `SELECT COUNT(*) AS total FROM "${tableName}"`
        );

        // Récupérer les données
        const dataResult = await pool.query(
            `SELECT * FROM "${tableName}" ORDER BY ${orderClause} LIMIT $1 OFFSET $2`,
            [limit, offset]
        );

        res.json({
            data: dataResult.rows,
            pagination: {
                page,
                limit,
                total: parseInt(countResult.rows[0].total),
                total_pages: Math.ceil(countResult.rows[0].total / limit),
            },
        });
    } catch (error) {
        console.error('❌ [DB Admin] Table data error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// POST /admin/database/query - Exécuter une requête SQL (SELECT uniquement)
// ============================================================
router.post('/query', async (req, res) => {
    try {
        const { sql } = req.body;

        if (!sql || typeof sql !== 'string') {
            return res.status(400).json({ error: 'SQL query required' });
        }

        // Sécurité : Vérifier que c'est une requête SELECT
        const trimmed = sql.trim().toUpperCase();
        const dangerousKeywords = ['INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE', 'TRUNCATE', 'GRANT', 'REVOKE'];
        
        for (const keyword of dangerousKeywords) {
            if (trimmed.startsWith(keyword)) {
                return res.status(403).json({ 
                    error: `Requêtes ${keyword} non autorisées. Seules les requêtes SELECT sont permises.` 
                });
            }
        }

        const startTime = Date.now();
        const result = await pool.query(sql);
        const duration = Date.now() - startTime;

        res.json({
            rows: result.rows.slice(0, 500), // Limiter à 500 résultats
            row_count: result.rowCount,
            fields: result.fields?.map(f => ({ name: f.name, dataTypeID: f.dataTypeID })) || [],
            duration_ms: duration,
        });
    } catch (error) {
        console.error('❌ [DB Admin] Query error:', error.message);
        res.status(400).json({ error: error.message });
    }
});

// ============================================================
// DELETE /admin/database/tables/:name/rows/:id - Supprimer une ligne
// ============================================================
router.delete('/tables/:name/rows/:id', async (req, res) => {
    try {
        const { name, id } = req.params;

        // Vérifier que la table existe
        const exists = await pool.query(`
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = $1
        `, [name]);

        if (exists.rows.length === 0) {
            return res.status(404).json({ error: 'Table not found' });
        }

        const result = await pool.query(
            `DELETE FROM "${name}" WHERE id = $1 RETURNING *`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Row not found' });
        }

        res.json({ message: 'Row deleted', deleted: result.rows[0] });
    } catch (error) {
        console.error('❌ [DB Admin] Delete row error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
