const shopRepo = require("../repositories/shop.repository");

// Créer boutique
async function createShop(userId, name, description) {
  return await shopRepo.createShop(userId, name, description);
}

// Lister boutiques d’un utilisateur
async function listUserShops(userId) {
  return await shopRepo.getShopsByUser(userId);
}

// Lister toutes les boutiques publiques
async function listAllShops() {
  return await shopRepo.getAllShops();
}

// Modifier boutique
async function updateShop(userId, shopId, data) {
  return await shopRepo.updateShop(userId, shopId, data);
}

// Supprimer boutique
async function deleteShop(userId, shopId) {
  return await shopRepo.deleteShop(userId, shopId);
}

module.exports = {
  createShop,
  listUserShops,
  listAllShops,
  updateShop,
  deleteShop,
};
