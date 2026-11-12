/**
 * Routes Candidature Livreur
 * Permet à tout utilisateur authentifié de postuler pour devenir livreur.
 *
 * Le gage est réellement prélevé sur le wallet Oli (en FC) et bloqué :
 * il est rendu si la candidature est refusée (voir admin/delivery.routes.js).
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const pool = require('../config/db');
const { requireAuth } = require('../middlewares/auth.middleware');
const walletRepository = require('../repositories/wallet.repository');
const notificationService = require('../services/notification.service');

const VEHICLE_TYPES = ['moto', 'velo', 'voiture', 'pied'];
const VEHICLES_WITH_PLATE = ['moto', 'voiture'];
const MIN_PLEDGE_FC = 100;
const PLEDGE_PROVIDER = 'OLI_DELIVERY';

// ─── Auto-migration : créer la table et ses colonnes si besoin ──────

(async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS deliverer_applications (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) UNIQUE,
                pledge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                phone VARCHAR(20),
                motivation TEXT,
                status VARCHAR(20) DEFAULT 'pending',
                admin_note TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                reviewed_at TIMESTAMP
            )
        `);
        // Identité, véhicule et gage réel. pledge_amount reste pour les anciennes
        // candidatures, dont le gage (en USD) était seulement déclaré.
        await pool.query(`
            ALTER TABLE deliverer_applications
                ADD COLUMN IF NOT EXISTS full_name VARCHAR(120),
                ADD COLUMN IF NOT EXISTS id_document_url TEXT,
                ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(20),
                ADD COLUMN IF NOT EXISTS vehicle_plate VARCHAR(20),
                ADD COLUMN IF NOT EXISTS zone VARCHAR(120),
                ADD COLUMN IF NOT EXISTS pledge_fc DECIMAL(14,2) NOT NULL DEFAULT 0,
                ADD COLUMN IF NOT EXISTS pledge_status VARCHAR(16) NOT NULL DEFAULT 'none',
                ADD COLUMN IF NOT EXISTS pledge_reference VARCHAR(80)
        `);
        console.log('✅ Table deliverer_applications prête');
    } catch (err) {
        console.error('❌ Erreur migration deliverer_applications:', err.message);
    }
})();

// ─── Photo de la pièce d'identité ──────────────────────────────────

const documentUpload = multer({
    storage: new CloudinaryStorage({
        cloudinary,
        params: {
            folder: 'deliverer-documents',
            allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        },
    }),
    limits: { fileSize: 8 * 1024 * 1024 },
});

const receiveDocument = (req, res, next) => {
    documentUpload.single('id_document')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ error: "Photo refusée : format non pris en charge ou fichier trop lourd (8 Mo max)" });
        }
        next();
    });
};

function cleanText(value, maxLength) {
    return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}

/** Les admins sont prévenus de chaque candidature, sans jamais bloquer la réponse. */
async function notifyAdmins(io, fullName, pledgeFc) {
    try {
        const { rows } = await pool.query('SELECT id FROM users WHERE is_admin = TRUE');
        await Promise.all(rows.map((admin) => notificationService.send(
            admin.id,
            'system',
            '🛵 Nouvelle candidature livreur',
            `${fullName} a postulé avec un gage de ${Math.round(pledgeFc).toLocaleString('fr-FR')} FC.`,
            { kind: 'deliverer_application' },
            io
        ).catch((e) => console.warn(`⚠️ Admin #${admin.id} non prévenu:`, e.message))));
    } catch (e) {
        console.warn('⚠️ Alerte candidature livreur non envoyée:', e.message);
    }
}

/**
 * POST /delivery/apply  (multipart/form-data)
 * Champs : full_name, vehicle_type, vehicle_plate?, zone, pledge_fc, motivation?
 * Fichier : id_document (photo de la pièce d'identité)
 */
router.post('/', requireAuth, receiveDocument, async (req, res) => {
    const userId = req.user.id;
    const fullName = cleanText(req.body.full_name, 120);
    const vehicleType = cleanText(req.body.vehicle_type, 20).toLowerCase();
    const vehiclePlate = cleanText(req.body.vehicle_plate, 20).toUpperCase();
    const zone = cleanText(req.body.zone, 120);
    const motivation = cleanText(req.body.motivation, 1000);
    const pledgeFc = Math.round(parseFloat(req.body.pledge_fc) || 0);
    const documentUrl = req.file?.path || null;

    if (fullName.length < 3) return res.status(400).json({ error: 'Indiquez votre nom complet' });
    if (!VEHICLE_TYPES.includes(vehicleType)) return res.status(400).json({ error: 'Choisissez votre moyen de déplacement' });
    if (VEHICLES_WITH_PLATE.includes(vehicleType) && !vehiclePlate) {
        return res.status(400).json({ error: "Indiquez la plaque d'immatriculation" });
    }
    if (!zone) return res.status(400).json({ error: 'Indiquez votre zone de livraison' });
    if (!documentUrl) return res.status(400).json({ error: "Ajoutez la photo de votre pièce d'identité" });
    if (pledgeFc < MIN_PLEDGE_FC) {
        return res.status(400).json({ error: `Le gage doit être d'au moins ${MIN_PLEDGE_FC} FC` });
    }

    try {
        const userCheck = await pool.query('SELECT is_deliverer FROM users WHERE id = $1', [userId]);
        if (userCheck.rows[0]?.is_deliverer) {
            return res.status(400).json({ error: "Vous êtes déjà un livreur enregistré" });
        }

        const existing = await pool.query(
            'SELECT id, status FROM deliverer_applications WHERE user_id = $1',
            [userId]
        );
        const previous = existing.rows[0];
        // Code explicite : l'app renvoie alors vers le suivi de la candidature au lieu d'afficher une erreur
        if (previous?.status === 'pending') {
            return res.status(409).json({ code: 'already_pending', error: "Vous avez déjà une candidature en attente" });
        }
        if (previous?.status === 'approved') {
            return res.status(409).json({ code: 'already_approved', error: "Votre candidature a déjà été approuvée" });
        }

        // 1. Le gage est prélevé et bloqué avant d'enregistrer la candidature
        const pledgeReference = `DELIVERER_PLEDGE_${userId}_${Date.now()}`;
        try {
            await walletRepository.performDebit(userId, pledgeFc, {
                type: 'escrow_lock',
                provider: PLEDGE_PROVIDER,
                reference: pledgeReference,
                description: 'Gage de candidature livreur (bloqué)',
            });
        } catch (e) {
            const isBalance = /insuffisant/i.test(e.message);
            return res.status(400).json({
                error: isBalance
                    ? `Solde insuffisant pour bloquer un gage de ${pledgeFc} FC. Rechargez votre wallet Oli.`
                    : e.message,
            });
        }

        // 2. Enregistrer la candidature. En cas d'échec, le gage est rendu tout de suite.
        const values = [userId, pledgeFc, req.user.phone || '', motivation, fullName, documentUrl,
            vehicleType, vehiclePlate || null, zone, pledgeReference];
        let saved;
        try {
            saved = previous
                // Ancienne candidature refusée : seule une ligne encore « rejected » est rouverte
                ? await pool.query(`
                    UPDATE deliverer_applications
                    SET pledge_fc = $2, phone = $3, motivation = $4, full_name = $5, id_document_url = $6,
                        vehicle_type = $7, vehicle_plate = $8, zone = $9, pledge_reference = $10,
                        pledge_status = 'held', pledge_amount = 0, status = 'pending',
                        admin_note = NULL, reviewed_at = NULL, created_at = NOW()
                    WHERE user_id = $1 AND status = 'rejected'
                    RETURNING id
                `, values)
                : await pool.query(`
                    INSERT INTO deliverer_applications
                        (user_id, pledge_fc, phone, motivation, full_name, id_document_url,
                         vehicle_type, vehicle_plate, zone, pledge_reference, pledge_status, status)
                    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'held','pending')
                    ON CONFLICT (user_id) DO NOTHING
                    RETURNING id
                `, values);
        } catch (e) {
            saved = { rows: [], error: e };
        }

        if (!saved.rows.length) {
            // Double envoi ou erreur : la candidature existe déjà, le gage prélevé est rendu
            await walletRepository.performDeposit(userId, pledgeFc, {
                type: 'escrow_refund',
                provider: PLEDGE_PROVIDER,
                reference: `${pledgeReference}_REFUND`,
                description: 'Gage livreur rendu (candidature non enregistrée)',
            });
            if (saved.error) throw saved.error;
            return res.status(409).json({ code: 'already_pending', error: 'Votre candidature est déjà en cours de traitement' });
        }

        notifyAdmins(req.app.get('io'), fullName, pledgeFc);

        res.status(201).json({
            success: true,
            message: `Candidature envoyée. Votre gage de ${pledgeFc} FC est bloqué et vous sera rendu en cas de refus.`,
        });
    } catch (err) {
        console.error('❌ Erreur candidature livreur:', err.message);
        res.status(500).json({ error: "Erreur lors de la soumission" });
    }
});

/**
 * GET /delivery/apply/status
 * Vérifier le statut de sa candidature
 */
router.get('/status', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, pledge_amount, pledge_fc, pledge_status, status, admin_note,
                    vehicle_type, zone, created_at, reviewed_at
             FROM deliverer_applications WHERE user_id = $1`,
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.json({ status: 'none', message: "Aucune candidature trouvée" });
        }

        const row = result.rows[0];
        res.json({ ...row, pledge_fc: parseFloat(row.pledge_fc) || 0 });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
