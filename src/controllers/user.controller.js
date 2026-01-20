const userService = require('../services/user.service');

exports.getVisitedProducts = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;
        const products = await userService.getVisitedProducts(req.user.id, limit);
        res.json(products);
    } catch (error) {
        console.error('Erreur /user/visited-products:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.trackProductView = async (req, res) => {
    try {
        const productId = parseInt(req.params.productId);

        if (!productId || isNaN(productId)) {
            return res.status(400).json({ error: 'Product ID invalide' });
        }

        await userService.trackProductView(req.user.id, productId);
        res.json({ success: true, message: 'Vue enregistrée' });
    } catch (error) {
        console.error('Erreur /user/track-view:', error);
        // On retourne quand même success pour ne pas bloquer l'UX
        res.json({ success: true, message: 'Vue non enregistrée' });
    }
};

exports.updateName = async (req, res) => {
    try {
        const { name } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Le nom est requis' });
        }

        const updatedUser = await userService.updateUserName(req.user.id, name);
        res.json({
            success: true,
            message: 'Nom mis à jour',
            user: updatedUser
        });
    } catch (error) {
        console.error('Erreur /user/update-name:', error);
        res.status(400).json({ error: error.message });
    }
};
