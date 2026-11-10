/**
 * Conversion des montants de commande vers la devise des portefeuilles.
 *
 * Les prix des produits et les frais de livraison sont en USD, les portefeuilles en FC.
 * Chaque commande conserve le taux du jour de sa création dans orders.exchange_rate.
 *
 * Les commandes antérieures à ce taux figé n'en ont pas : leur montant reste inchangé,
 * car l'acheteur a lui-même été débité sans conversion.
 *
 * @param {number|string} usdAmount
 * @param {number|string|null} exchangeRate - 1 USD = X FC, null pour une ancienne commande
 * @returns {number} montant à débiter ou créditer sur un portefeuille, en FC entiers
 */
function orderAmountToWallet(usdAmount, exchangeRate) {
    const amount = parseFloat(usdAmount);
    const rate = parseFloat(exchangeRate);
    if (!Number.isFinite(rate) || rate <= 0) {
        return amount;
    }
    return Math.round(amount * rate);
}

module.exports = { orderAmountToWallet };
