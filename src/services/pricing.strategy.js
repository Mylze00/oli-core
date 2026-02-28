/**
 * pricing.strategy.js
 * Calcul de stratégie de prix + matching avec CSV concurrent (Alibaba/AliExpress)
 */

const fs = require('fs');
const path = require('path');
const csv = require('csv-parse/sync');

// ── Chemin du dossier des CSV concurrents ──────────────────────────────────
const COMPETITORS_DIR = path.join(__dirname, '../../data/competitors');

// ── Cache du CSV (chargé une fois au démarrage) ───────────────────────────
let _competitorCache = null; // { title: string, price: number }[]

/**
 * Charge tous les CSV du dossier data/competitors/
 * et retourne une liste de { title, price }
 */
function loadCompetitorCSV() {
    if (_competitorCache) return _competitorCache;

    const results = [];
    if (!fs.existsSync(COMPETITORS_DIR)) {
        console.warn('⚠️ pricing: dossier data/competitors/ introuvable');
        _competitorCache = [];
        return [];
    }

    const files = fs.readdirSync(COMPETITORS_DIR).filter(f => f.endsWith('.csv'));
    for (const file of files) {
        try {
            const content = fs.readFileSync(path.join(COMPETITORS_DIR, file), 'utf8');
            const rows = csv.parse(content, {
                columns: true,
                skip_empty_lines: true,
                relax_quotes: true,
                trim: true,
            });
            for (const row of rows) {
                const title = row['title'] || row['Title'] || '';
                // Prix minimum = pricing/0/dollarPrice (colonne Alibaba scraper)
                const rawPrice = row['pricing/0/dollarPrice'] || row['pricing/0/price'] ||
                    row['salePrice'] || row['price'] || '';
                const price = parseFloat(String(rawPrice).replace(/[^0-9.]/g, ''));
                if (title && !isNaN(price) && price > 0) {
                    results.push({ title: title.toLowerCase(), price });
                }
            }
        } catch (e) {
            console.warn(`⚠️ pricing: erreur lecture ${file}:`, e.message);
        }
    }
    _competitorCache = results;
    console.log(`✅ pricing: ${results.length} produits concurrents chargés`);
    return results;
}

/**
 * Invalide le cache (utile après upload d'un nouveau CSV)
 */
function invalidateCache() {
    _competitorCache = null;
}

/**
 * Trouve le meilleur prix concurrent pour un produit par matching de mots-clés
 * Retourne null si aucun match satisfaisant (score < 2 mots communs)
 * @param {string} productName - Nom du produit Oli
 * @returns {{ price: number, matchTitle: string, score: number } | null}
 */
function findCompetitorPrice(productName) {
    const competitors = loadCompetitorCSV();
    if (!competitors.length) return null;

    const searchWords = productName.toLowerCase()
        .replace(/[^\w\s]/g, ' ')
        .split(/\s+/)
        .filter(w => w.length > 3); // ignorer mots courts (les, des, etc.)

    if (!searchWords.length) return null;

    let bestMatch = null;
    let bestScore = 0;

    for (const comp of competitors) {
        let score = 0;
        for (const word of searchWords) {
            if (comp.title.includes(word)) score++;
        }
        if (score > bestScore) {
            bestScore = score;
            bestMatch = comp;
        }
    }

    // On exige au moins 2 mots en commun pour éviter les faux positifs
    if (bestScore < 2 || !bestMatch) return null;

    return {
        price: bestMatch.price,
        matchTitle: bestMatch.title.substring(0, 80),
        score: bestScore,
    };
}

/**
 * Calcule la stratégie de prix pour un produit
 * @param {Object} params
 * @param {string} params.nom
 * @param {number} params.prixAchat
 * @param {number} params.poids       - en kg
 * @param {number} params.longueur    - en cm
 * @param {number} params.largeur     - en cm
 * @param {number} params.hauteur     - en cm
 * @param {number} [params.prixConcurrent] - optionnel, sinon trouvé via CSV
 * @returns {Object} résultat de la stratégie
 */
function calculerStrategieProduit({ nom, prixAchat, poids, longueur, largeur, hauteur, prixConcurrent }) {
    // Valeurs par défaut sécurisées
    prixAchat = parseFloat(prixAchat) || 0;
    poids = parseFloat(poids) || 0.5;
    longueur = parseFloat(longueur) || 20;
    largeur = parseFloat(largeur) || 20;
    hauteur = parseFloat(hauteur) || 10;

    // Volume en m³ (jamais 0 pour éviter division par zéro)
    const volumeM3 = Math.max((longueur * largeur * hauteur) / 1_000_000, 0.001);

    // ── Transport ──────────────────────────────────────────────────────────
    let fraisExpedition = 0;
    let modeTransport = '';
    let delai = '';

    if (poids < 1) {
        modeTransport = 'Maritime (OFFERT)';
        fraisExpedition = 0;
        delai = '60 jours';
    } else if (poids <= 5) {
        const coutAerien = poids * 25;
        const coutMaritime = volumeM3 * 750;
        if (coutAerien <= coutMaritime) {
            modeTransport = 'Aérien (Standard)';
            fraisExpedition = coutAerien;
            delai = '10 jours';
        } else {
            modeTransport = 'Maritime (Optimisé)';
            fraisExpedition = coutMaritime;
            delai = '60 jours';
        }
    } else {
        modeTransport = 'Maritime (Lourd)';
        fraisExpedition = volumeM3 * 750;
        delai = '60 jours';
    }

    // ── Prix de vente ──────────────────────────────────────────────────────
    const prixRevient = prixAchat + fraisExpedition;
    const prixVenteCible = prixRevient * 1.35;

    // ── Concurrence ────────────────────────────────────────────────────────
    let matchInfo = null;
    if (!prixConcurrent && nom) {
        const found = findCompetitorPrice(nom);
        if (found) {
            prixConcurrent = found.price;
            matchInfo = found;
        }
    }

    const statut = prixConcurrent ? (prixVenteCible <= prixConcurrent ? 'COMPÉTITIF ✅' : 'TROP CHER ❌') : 'INCONNU';
    const opportunite = prixConcurrent ? (prixConcurrent - prixVenteCible) : null;

    return {
        produit: nom || 'Sans nom',
        mode: modeTransport,
        delai: delai,
        fraisExpe: `$${fraisExpedition.toFixed(2)}`,
        prixVenteConseille: `$${prixVenteCible.toFixed(2)}`,
        prixVenteNumber: parseFloat(prixVenteCible.toFixed(2)),
        prixConcurrent: prixConcurrent ? `$${prixConcurrent.toFixed(2)}` : 'N/A',
        verdict: statut,
        margeVsConc: opportunite !== null ? `$${opportunite.toFixed(2)}` : 'N/A',
        matchConcurrent: matchInfo ? matchInfo.matchTitle : null,
        matchScore: matchInfo ? matchInfo.score : null,
    };
}

module.exports = { calculerStrategieProduit, findCompetitorPrice, loadCompetitorCSV, invalidateCache };
