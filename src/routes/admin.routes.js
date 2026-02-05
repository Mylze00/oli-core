/**
 * Routes Admin - Point d'entrée pour toutes les routes administrateur
 * Toutes les routes sont protégées par requireAuth + requireAdmin
 */
const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const { requireAdmin } = require('../middlewares/admin.middleware');

// Appliquer middleware auth + admin sur TOUTES les routes /admin/*
router.use(requireAuth);
router.use(requireAdmin);

// Import des sous-routes
const statsRoutes = require('./admin/stats.routes');
const usersRoutes = require('./admin/users.routes');
const productsRoutes = require('./admin/products.routes');
const ordersRoutes = require('./admin/orders.routes');
const disputesRoutes = require('./admin/disputes.routes');
const shopsRoutes = require('./admin/shops.routes');
const requestsRoutes = require('./admin/requests.routes');
const servicesRoutes = require('./admin/services.routes');
const supportRoutes = require('./admin/support.routes'); // 🆕

// Montage des routes
router.use('/stats', statsRoutes);
router.use('/users', usersRoutes);
router.use('/products', productsRoutes);
router.use('/orders', ordersRoutes);
router.use('/disputes', disputesRoutes);
router.use('/shops', shopsRoutes);
router.use('/requests', requestsRoutes);
router.use('/services', servicesRoutes);
router.use('/verifications', require('./admin/verifications.routes'));
router.use('/support', supportRoutes); // 🆕


// Route de test
router.get('/ping', (req, res) => {
    res.json({
        message: 'Admin routes OK',
        admin: {
            id: req.user.id,
            phone: req.user.phone,
            is_admin: req.user.is_admin
        }
    });
});

module.exports = router;
