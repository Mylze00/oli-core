/**
 * Routes Vendeur
 * Endpoints spécifiques pour les vendeurs
 */

const express = require('express');
const router = express.Router();
const sellerRepo = require('../repositories/seller.repository');
const productRepo = require('../repositories/product.repository');
const certificationService = require('../services/seller-certification.service');
const { requireAuth } = require('../middlewares/auth.middleware');

/**
 * Middleware pour vérifier que l'utilisateur est vendeur
 * Vérifie en DB (le JWT peut être stale)
 */
const db = require('../config/db');
const requireSeller = async (req, res, next) => {
    try {
        const result = await db.query(
            `SELECT u.is_seller, (SELECT COUNT(*) FROM products WHERE seller_id = u.id) as product_count
             FROM users u WHERE u.id = $1`,
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(403).json({ error: 'Utilisateur introuvable' });
        }

        const user = result.rows[0];
        if (!user.is_seller && parseInt(user.product_count) === 0) {
            return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
        }

        if (!user.is_seller && parseInt(user.product_count) > 0) {
            await db.query('UPDATE users SET is_seller = true WHERE id = $1', [req.user.id]);
            console.log(`✅ User #${req.user.id} auto-promu vendeur (${user.product_count} produits)`);
        }

        next();
    } catch (err) {
        console.error('Erreur requireSeller:', err.message);
        return res.status(500).json({ error: 'Erreur vérification vendeur' });
    }
};

/**
 * GET /seller/dashboard
 * Statistiques du tableau de bord vendeur
 */
router.get('/dashboard', requireAuth, requireSeller, async (req, res) => {
    try {
        const stats = await sellerRepo.getSellerDashboard(req.user.id);
        res.json(stats);
    } catch (error) {
        console.error('Error GET /seller/dashboard:', error);
        // RETOURNER L'ERREUR DÉTAILLÉE POUR LE DÉBOGAGE
        res.status(500).json({
            error: error.message,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined,
            details: 'Erreur détaillée dashboard'
        });
    }
});

/**
 * GET /seller/products
 * Liste des produits du vendeur
 */
router.get('/products', requireAuth, requireSeller, async (req, res) => {
    try {
        // Limite plus élevée pour le Seller Center (500) car interface de gestion
        const { status, category, search, limit = 500, offset = 0 } = req.query;

        const filters = {
            seller_id: req.user.id,
            is_active: status === 'active' ? true : status === 'inactive' ? false : undefined,
            category: category || undefined,
            search: search || undefined
        };

        const products = await productRepo.findAll(filters, limit, offset);
        res.json(products);
    } catch (error) {
        console.error('Error GET /seller/products:', error);
        res.status(500).json({
            error: error.message,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined,
            details: 'Erreur détaillée produits'
        });
    }
});

/**
 * PATCH /seller/products/:id/toggle
 * Activer/Désactiver un produit
 */
router.patch('/products/:id/toggle', requireAuth, requireSeller, async (req, res) => {
    try {
        const { id } = req.params;

        // Vérifier que le produit appartient au vendeur
        const product = await productRepo.findById(id);

        if (!product) {
            return res.status(404).json({ error: 'Produit introuvable' });
        }

        if (product.seller_id !== req.user.id) {
            return res.status(403).json({ error: 'Non autorisé' });
        }

        // Toggle le statut (active <-> inactive)
        const newStatus = product.status === 'active' ? 'inactive' : 'active';
        const updatedProduct = await productRepo.update(id, {
            status: newStatus
        });

        res.json({
            success: true,
            product: updatedProduct,
            message: newStatus === 'active' ? 'Produit activé' : 'Produit désactivé'
        });
    } catch (error) {
        console.error('Error PATCH /seller/products/:id/toggle:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /seller/orders
 * Commandes du vendeur
 */
router.get('/orders', requireAuth, requireSeller, async (req, res) => {
    try {
        const { status, limit = 50, offset = 0 } = req.query;

        const orders = await sellerRepo.getSellerOrders(
            req.user.id,
            status || null,
            parseInt(limit),
            parseInt(offset)
        );

        // Compter par statut pour les badges
        const countQuery = `
            SELECT o.status, COUNT(DISTINCT o.id) as count
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
            WHERE p.seller_id = $1
            GROUP BY o.status
        `;
        const countResult = await db.query(countQuery, [parseInt(req.user.id)]);

        const statusCounts = {};
        countResult.rows.forEach(row => {
            statusCounts[row.status] = parseInt(row.count);
        });

        // Convertir les champs DECIMAL (string) en nombres pour Flutter
        const sanitizedOrders = orders.map(order => ({
            ...order,
            total_amount: order.total_amount != null ? parseFloat(order.total_amount) : 0,
            delivery_fee: order.delivery_fee != null ? parseFloat(order.delivery_fee) : 0,
            items_count: order.items_count != null ? parseInt(order.items_count) : 0,
        }));

        res.json({
            orders: sanitizedOrders,
            status_counts: statusCounts,
            total: sanitizedOrders.length
        });
    } catch (error) {
        console.error('Error GET /seller/orders:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /seller/orders/:id
 * Détails d'une commande
 */
router.get('/orders/:id', requireAuth, requireSeller, async (req, res) => {
    try {
        const { id } = req.params;

        const order = await sellerRepo.getSellerOrderDetails(req.user.id, id);

        if (!order) {
            return res.status(404).json({ error: 'Commande introuvable' });
        }

        res.json(order);
    } catch (error) {
        console.error('Error GET /seller/orders/:id:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /seller/stats/sales
 * Graphique des ventes
 */
router.get('/stats/sales', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '7d' } = req.query;

        if (!['7d', '30d', '12m'].includes(period)) {
            return res.status(400).json({ error: 'Période invalide. Utilisez 7d, 30d ou 12m' });
        }

        const salesData = await sellerRepo.getSalesChart(req.user.id, period);
        res.json(salesData);
    } catch (error) {
        console.error('Error GET /seller/stats/sales:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /seller/certification
 * Détails de certification du vendeur connecté
 */
router.get('/certification', requireAuth, requireSeller, async (req, res) => {
    try {
        const details = await certificationService.getCertificationDetails(req.user.id);
        if (!details) {
            return res.status(404).json({ error: 'Certification non trouvée' });
        }

        const benefits = certificationService.getBenefits(details.account_type);
        const levelLabel = certificationService.getLevelLabel(details.account_type);

        res.json({
            ...details,
            benefits,
            level_label: levelLabel
        });
    } catch (error) {
        console.error('Error GET /seller/certification:', error);
        res.status(500).json({
            error: error.message,
            details: 'Erreur détaillée certification'
        });
    }
});

/**
 * POST /seller/certification/recalculate
 * Forcer le recalcul de la certification
 */
router.post('/certification/recalculate', requireAuth, requireSeller, async (req, res) => {
    try {
        const newType = await certificationService.recalculateCertification(req.user.id);
        res.json({
            success: true,
            new_account_type: newType,
            message: 'Certification recalculée avec succès'
        });
    } catch (error) {
        console.error('Error POST /seller/certification/recalculate:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /seller/certification/business-documents
 * Soumettre documents entreprise pour vérification
 */
router.post('/certification/business-documents', requireAuth, requireSeller, async (req, res) => {
    try {
        const { registration_number, tax_id, document_url } = req.body;

        if (!registration_number || !document_url) {
            return res.status(400).json({
                error: 'Numéro d\'enregistrement et document requis'
            });
        }

        const documents = {
            registrationNumber: registration_number,
            taxId: tax_id,
            documentUrls: {
                front: document_url
            }
        };

        const result = await certificationService.submitBusinessDocuments(
            req.user.id,
            documents
        );

        res.json(result);
    } catch (error) {
        console.error('Error POST /seller/certification/business-documents:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
