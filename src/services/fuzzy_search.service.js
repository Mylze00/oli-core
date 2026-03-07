/**
 * FuzzySearchService
 * 
 * Gère la recherche tolérante aux fautes de frappe en combinant :
 * - pg_trgm (similarité trigram) pour les fautes phonétiques/orthographiques
 * - Expansion de synonymes/variantes pour les termes courants
 * - Normalisation des accents pour une recherche sans accent
 */

const SYNONYM_MAP = {
    // Vêtements & chaussures
    'chossure': ['chaussure', 'soulier', 'basket'],
    'chausure': ['chaussure', 'soulier', 'basket'],
    'chaussure': ['chaussure', 'soulier', 'basket', 'sandale', 'mocassin', 'botte'],
    'chaussures': ['chaussure', 'soulier', 'basket', 'sandale', 'mocassin', 'botte'],
    'vetement': ['vêtement', 'habit', 'tenue', 'robe', 'pantalon', 'chemise', 'veste'],
    'vêtement': ['vêtement', 'habit', 'tenue', 'robe', 'pantalon', 'chemise', 'veste'],
    'habit': ['vêtement', 'habit', 'tenue', 'robe', 'pantalon', 'chemise'],
    'sac': ['sac', 'sacoche', 'sac à main', 'cartable', 'tote bag', 'pochette'],
    'robe': ['robe', 'robe de soirée', 'robe de mariée', 'robe courte'],
    'chemise': ['chemise', 'chemisier', 'blouse', 't-shirt'],

    // Électronique
    'tlephone': ['téléphone', 'smartphone', 'portable', 'mobile'],
    'télphone': ['téléphone', 'smartphone', 'portable', 'mobile'],
    'telephone': ['téléphone', 'smartphone', 'portable', 'mobile'],
    'téléphone': ['téléphone', 'smartphone', 'portable', 'mobile'],
    'phone': ['téléphone', 'smartphone', 'portable', 'mobile'],
    'ordi': ['ordinateur', 'laptop', 'pc', 'computer'],
    'ordinateur': ['ordinateur', 'laptop', 'pc', 'computer'],
    'laptop': ['laptop', 'ordinateur portable', 'pc portable'],
    'ecran': ['écran', 'moniteur', 'display', 'hdmi'],
    'écran': ['écran', 'moniteur', 'display'],
    'tv': ['télévision', 'tv', 'téléviseur', 'écran plat'],
    'television': ['télévision', 'tv', 'téléviseur', 'écran plat'],
    'télévision': ['télévision', 'tv', 'téléviseur'],
    'frigo': ['réfrigérateur', 'frigo', 'congélateur', 'frigidaire'],
    'refrigerateur': ['réfrigérateur', 'frigo', 'congélateur'],
    'réfrigérateur': ['réfrigérateur', 'frigo', 'congélateur'],

    // Maison & mobilier
    'meuble': ['meuble', 'table', 'chaise', 'buffet', 'armoire', 'canapé', 'lit'],
    'canape': ['canapé', 'sofa', 'divan', 'banquette'],
    'canapé': ['canapé', 'sofa', 'divan'],
    'lit': ['lit', 'matelas', 'sommier', 'bunk bed', 'bed'],
    'matela': ['matelas', 'matelas mousse', 'sommier'],
    'matelas': ['matelas', 'matelas mousse', 'sommier'],

    // Alimentaire
    'savon': ['savon', 'gel douche', 'shampoing', 'détergent', 'lessive'],
    'lessive': ['lessive', 'détergent', 'savon', 'produit ménager'],
    'huile': ['huile', 'huile de palme', 'huile végétale', 'margarine'],
    'riz': ['riz', 'céréale', 'farine', 'maïs'],
    'farine': ['farine', 'semoule', 'biscuit', 'céréale'],

    // Beauté & cosmétique
    'creme': ['crème', 'lotion', 'beurre de karité', 'huile corporelle'],
    'crème': ['crème', 'lotion', 'beurre de karité'],
    'parfum': ['parfum', 'eau de toilette', 'déodorant', 'cologne'],
    'maquillage': ['maquillage', 'fond de teint', 'rouge à lèvres', 'mascara'],

    // Divers courants
    'velo': ['vélo', 'bicyclette', 'moto', 'trottinette'],
    'vélo': ['vélo', 'bicyclette', 'trottinette'],
    'moto': ['moto', 'scooter', 'motocyclette'],
    'voiture': ['voiture', 'véhicule', 'automobile', 'auto'],
};

class FuzzySearchService {
    /**
     * Normalise un texte (minuscules + suppression des accents)
     * "Chôssure" → "chossure"
     */
    normalizeText(text) {
        return text
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, ''); // Enlever les diacritiques
    }

    /**
     * Étend un terme de recherche avec des synonymes et variantes.
     * "chossure" → ["chossure", "chaussure", "soulier", "basket"]
     */
    expandQuery(query) {
        const normalized = this.normalizeText(query.trim());
        const terms = new Set([query.trim()]); // Toujours inclure le terme original

        // Chercher des synonymes pour le terme normalisé
        if (SYNONYM_MAP[normalized]) {
            SYNONYM_MAP[normalized].forEach(s => terms.add(s));
        }

        // Chercher aussi si un mot du terme correspond à un synonyme (ex: "vieille chossure")
        const words = normalized.split(/\s+/);
        for (const word of words) {
            if (SYNONYM_MAP[word]) {
                SYNONYM_MAP[word].forEach(s => terms.add(s));
            }
        }

        return [...terms];
    }

    /**
     * Construit la condition SQL pour une recherche floue.
     * Combine ILIKE (exact substring) et similarity() pg_trgm (tolérance fautes).
     * 
     * @param {string} query - Terme de recherche original
     * @param {number} paramIndex - Index de départ des paramètres SQL
     * @param {number} [threshold=0.25] - Seuil de similarité (0.0–1.0)
     * @returns {{ condition: string, params: string[], nextIndex: number, expandedTerms: string[] }}
     */
    getFuzzySearchCondition(query, paramIndex, threshold = 0.25) {
        const expandedTerms = this.expandQuery(query);
        const normalizedQuery = this.normalizeText(query.trim());
        const conditions = [];
        const params = [];
        let idx = paramIndex;

        for (const term of expandedTerms) {
            // Condition 1 : Correspondance partielle exacte (ILIKE classique)
            conditions.push(`(
                p.name ILIKE $${idx}
                OR p.description ILIKE $${idx}
                OR p.category ILIKE $${idx}
                OR p.brand ILIKE $${idx}
            )`);
            params.push(`%${term}%`);
            idx++;

            // Condition 2 : Similarité trigram sur le nom (pour les fautes)
            // similarity() retourne un score entre 0 et 1
            conditions.push(`(
                similarity(LOWER(p.name), $${idx}) > $${idx + 1}
                OR similarity(LOWER(p.category), $${idx}) > $${idx + 1}
            )`);
            params.push(term.toLowerCase(), threshold);
            idx += 2;
        }

        // Condition de fallback sur le terme normalisé (sans accents)
        conditions.push(`(
            similarity(LOWER(unaccent_text(p.name)), $${idx}) > $${idx + 1}
        )`);
        params.push(normalizedQuery, threshold);
        idx += 2;

        const condition = `(${conditions.join(' OR ')})`;

        return {
            condition,
            params,
            nextIndex: idx,
            expandedTerms,
            fuzzyUsed: expandedTerms.length > 1 || normalizedQuery !== query.trim().toLowerCase(),
        };
    }

    /**
     * Version simplifiée de getFuzzySearchCondition sans unaccent_text
     * (fallback si l'extension unaccent n'est pas dispo)
     */
    getFuzzySearchConditionSimple(query, paramIndex, threshold = 0.25) {
        const expandedTerms = this.expandQuery(query);
        const conditions = [];
        const params = [];
        let idx = paramIndex;

        for (const term of expandedTerms) {
            // ILIKE classique
            conditions.push(`(
                p.name ILIKE $${idx}
                OR p.description ILIKE $${idx}
                OR p.category ILIKE $${idx}
                OR p.brand ILIKE $${idx}
            )`);
            params.push(`%${term}%`);
            idx++;

            // Similarité trigram
            conditions.push(`similarity(LOWER(p.name), $${idx}) > $${idx + 1}`);
            params.push(term.toLowerCase(), threshold);
            idx += 2;
        }

        return {
            condition: `(${conditions.join(' OR ')})`,
            params,
            nextIndex: idx,
            expandedTerms,
            fuzzyUsed: expandedTerms.length > 1,
        };
    }
}

module.exports = new FuzzySearchService();
