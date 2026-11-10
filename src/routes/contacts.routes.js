/**
 * Contacts de l'utilisateur
 *
 * POST /contacts/match  — reçoit les numéros du carnet d'adresses de l'utilisateur
 * et renvoie UNIQUEMENT les comptes Oli existants correspondants.
 * GET /contacts, POST /contacts, DELETE /contacts/:contactId — liste « Mes contacts ».
 *
 * Aucun numéro n'est stocké ni journalisé : la liste relie seulement deux comptes Oli.
 * Les contacts non inscrits ne sont jamais enregistrés et restent sur le téléphone.
 */
const express = require('express');
const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const pool = require('../config/db');

const router = express.Router();

const MAX_PHONES_PER_REQUEST = 1000;
const E164 = /^\+[1-9]\d{7,14}$/;

/**
 * Normalise un numéro en format international (E.164).
 * Par défaut, un numéro local commençant par 0 est rattaché à la RDC (+243).
 * Renvoie null si le numéro n'est pas valide.
 */
function normalizePhone(raw) {
    if (typeof raw !== 'string') return null;
    let s = raw.replace(/[\s\-().]/g, '');
    if (s.startsWith('00')) s = '+' + s.slice(2);
    if (s.startsWith('0') && !s.startsWith('+')) s = '+243' + s.slice(1);
    return E164.test(s) ? s : null;
}

// Limite par utilisateur (et non par IP) : 20 synchronisations par heure
const contactsMatchLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => (req.user && req.user.id ? `user:${req.user.id}` : ipKeyGenerator(req.ip)),
    message: { error: 'Trop de synchronisations de contacts. Réessayez plus tard.' },
    skip: () => process.env.NODE_ENV === 'test',
});

router.post('/match', contactsMatchLimiter, async (req, res) => {
    try {
        const phones = req.body && req.body.phones;
        if (!Array.isArray(phones)) {
            return res.status(400).json({ error: 'phones doit être un tableau' });
        }
        if (phones.length > MAX_PHONES_PER_REQUEST) {
            return res.status(400).json({ error: `Maximum ${MAX_PHONES_PER_REQUEST} numéros par requête` });
        }

        const normalized = [...new Set(phones.map(normalizePhone).filter(Boolean))];
        if (normalized.length === 0) {
            return res.json({ matches: [] });
        }

        const { rows } = await pool.query(
            `SELECT id, name, avatar_url, id_oli, phone
             FROM users
             WHERE phone = ANY($1::text[])
               AND deleted_at IS NULL
               AND id <> $2`,
            [normalized, req.user.id]
        );

        res.json({
            matches: rows.map((r) => ({
                id: r.id,
                name: r.name,
                avatar_url: r.avatar_url,
                id_oli: r.id_oli,
                phone: r.phone,
            })),
        });
    } catch (err) {
        // Pas de numéros dans le journal
        console.error('Erreur POST /contacts/match:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// Un numéro testé révèle si le compte existe : le débit reste limité par utilisateur
const contactsAddLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => (req.user && req.user.id ? `user:${req.user.id}` : ipKeyGenerator(req.ip)),
    message: { error: "Trop d'ajouts de contacts. Réessayez plus tard.", code: 'rate_limited' },
    skip: () => process.env.NODE_ENV === 'test',
});

const MAX_POSTGRES_INT = 2147483647;

router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT u.id, u.name, u.avatar_url, u.id_oli, u.phone
             FROM user_contacts c
             JOIN users u ON u.id = c.contact_id
             WHERE c.owner_id = $1
               AND u.deleted_at IS NULL
             ORDER BY LOWER(COALESCE(u.name, '')), u.id`,
            [req.user.id]
        );
        res.json({ contacts: rows });
    } catch (err) {
        console.error('Erreur GET /contacts:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.post('/', contactsAddLimiter, async (req, res) => {
    try {
        const phone = normalizePhone(req.body && req.body.phone);
        if (!phone) {
            return res.status(400).json({ error: 'Numéro invalide', code: 'invalid_phone' });
        }

        const { rows } = await pool.query(
            `SELECT id, name, avatar_url, id_oli, phone
             FROM users
             WHERE phone = $1
               AND deleted_at IS NULL`,
            [phone]
        );
        const contact = rows[0];
        if (!contact) {
            return res.status(404).json({ error: "Ce numéro n'est pas sur Oli", code: 'not_on_oli' });
        }
        if (String(contact.id) === String(req.user.id)) {
            return res.status(400).json({ error: "C'est votre propre numéro", code: 'own_number' });
        }

        await pool.query(
            `INSERT INTO user_contacts (owner_id, contact_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [req.user.id, contact.id]
        );
        res.status(201).json({ contact });
    } catch (err) {
        console.error('Erreur POST /contacts:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.delete('/:contactId', async (req, res) => {
    try {
        const contactId = Number(req.params.contactId);
        if (!Number.isInteger(contactId) || contactId < 1 || contactId > MAX_POSTGRES_INT) {
            return res.status(400).json({ error: 'Contact invalide' });
        }

        const { rowCount } = await pool.query(
            'DELETE FROM user_contacts WHERE owner_id = $1 AND contact_id = $2',
            [req.user.id, contactId]
        );
        res.json({ removed: rowCount > 0 });
    } catch (err) {
        console.error('Erreur DELETE /contacts:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.normalizePhone = normalizePhone;
module.exports = router;
