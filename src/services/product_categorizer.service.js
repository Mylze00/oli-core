/**
 * Service d'auto-catégorisation des produits
 * Analyse le nom et la description d'un produit pour détecter
 * automatiquement sa catégorie et sous-catégorie.
 *
 * Fonctionne 100% offline — aucune API externe.
 * Stratégie : scoring par correspondance de mots-clés tokenisés (FR/EN/anglicismes).
 */

// ─────────────────────────────────────────────────────────────────────────────
// DICTIONNAIRE : catégorie → sous-catégorie → mots-clés
// ─────────────────────────────────────────────────────────────────────────────
const CATEGORY_DICT = {

    electronics: {
        smartphones: [
            'iphone', 'samsung', 'galaxy', 'android', 'smartphone', 'téléphone', 'telephone',
            'phone', 'redmi', 'xiaomi', 'oppo', 'tecno', 'itel', 'infinix', 'realme',
            'huawei', 'nokia', 'motorola', 'oneplus', 'vivo', 'pixel', 'blackberry',
            'sim', 'dual sim', '4g', '5g', 'mobile', 'portable', 'gsm',
        ],
        tv: [
            'tv', 'televiseur', 'télévision', 'television', 'smart tv', 'led tv', 'oled',
            'qled', 'nanocell', 'uhd', '4k', '8k', '1080p', 'full hd', 'hd', 'ecran',
            'écran', 'hisense', 'lg', 'sony', 'tcl', 'aucune', 'beko', 'skyworth',
            'moniteur', 'monitor', 'display',
        ],
        audio: [
            'casque', 'ecouteur', 'écouteur', 'bluetooth', 'enceinte', 'speaker',
            'sono', 'jbl', 'harman', 'bose', 'sony wh', 'airpods', 'earbuds',
            'subwoofer', 'ampli', 'amplificateur', 'home theater', 'home cinéma',
            'dvd', 'soundbar', 'hifi', 'hi-fi', 'radio', 'fm', 'stereo',
            'microphone', 'micro', 'karaoke', 'karaoke',
        ],
        climatisation: [
            'climatiseur', 'climatisation', 'clim', 'ac', 'inverter', 'btu', 'split',
            'cassette', 'gainable', 'armoire frigorifique', 'vmc', 'pompe à chaleur',
            'ventilateur', 'ventilo', 'fan', 'purificateur d\'air',
        ],
        electromenager: [
            'réfrigérateur', 'refrigerateur', 'frigo', 'congélateur', 'congelateur',
            'lave-linge', 'machine à laver', 'lave linge', 'sèche-linge', 'seche linge',
            'lave-vaisselle', 'four', 'micro-onde', 'micro onde', 'cuisinière', 'cuisiniere',
            'plaque', 'hotte', 'aspirateur', 'robot ménager', 'mixeur', 'blender',
            'cafetière', 'bouilloire', 'grille-pain', 'fer à repasser', 'pressing',
            'generatrice', 'groupe électrogène', 'groupe electrogene', 'onduleur', 'ups',
        ],
        informatique: [
            'laptop', 'ordinateur', 'pc', 'macbook', 'lenovo', 'dell', 'hp', 'asus',
            'acer', 'toshiba', 'thinkpad', 'gaming', 'bureau', 'desktop', 'processeur',
            'cpu', 'gpu', 'carte graphique', 'ram', 'ssd', 'disque dur', 'clavier',
            'souris', 'imprimante', 'printer', 'scanner', 'modem', 'routeur', 'router',
            'switch', 'hub', 'câble', 'hdmi', 'usb', 'internet',
        ],
        photo_video: [
            'appareil photo', 'camera', 'camescope', 'caméscope', 'canon', 'nikon',
            'gopro', 'drone', 'dji', 'objectif', 'trepied', 'trépied', 'flash',
            'webcam', 'action cam',
        ],
        accessoires_elec: [
            'chargeur', 'batterie externe', 'power bank', 'powerbank', 'câble usb',
            'adaptateur', 'etui', 'coque', 'verre trempé', 'film protecteur',
            'support', 'dock', 'clé usb', 'carte mémoire', 'sd card', 'manette',
            'joystick', 'console', 'playstation', 'xbox', 'nintendo', 'ps4', 'ps5',
        ],
    },

    fashion: {
        vetements_femme: [
            'robe', 'jupe', 'pagne', 'wax', 'bazin', 'tenue', 'blouse', 'tunique',
            'chemisier', 'ensemble femme', 'combinaison', 'legging', 'body', 'bustier',
            'corsage', 'sari', 'boubou femme',
        ],
        vetements_homme: [
            'chemise', 'pantalon', 'costume', 'costume homme', 'veste', 'blazer',
            'suit', 'cravate', 'boubou', 'gandoura', 'djellaba', 'polo', 'tshirt',
            't-shirt', 'short', 'bermuda', 'survêtement', 'jogging',
        ],
        chaussures: [
            'chaussure', 'basket', 'sneaker', 'sandale', 'escarpin', 'botte', 'mocassin',
            'talon', 'tong', 'claquette', 'adidas', 'nike', 'puma', 'skechers',
            'timberland', 'reebok', 'converse', 'jordan', 'sous-vêtement',
        ],
        sacs_accessoires: [
            'sac', 'sacoche', 'sac a main', 'sac a dos', 'sac dos', 'backpack', 'cartable',
            'valise', 'bagage', 'portefeuille',
            'ceinture', 'lunette', 'montre', 'bijou', 'collier', 'bague', 'bracelet',
            'boucle d\'oreille', 'chapeau', 'casquette', 'bonnet', 'echarpe', 'foulard',
            'gant', 'gucci', 'louis vuitton', 'coach', 'michael kors', 'zara',
        ],
        lingerie: [
            'lingerie', 'soutien-gorge', 'culotte', 'string', 'boxeur', 'caleçon',
            'pyjama', 'nuisette', 'déshabillé', 'sous-vêtement',
        ],
        enfants_mode: [
            'bébé vêtement', 'habit enfant', 'barboteuse', 'grenouillère', 'body bébé',
            'vêtement enfant', 'école uniforme', 'tenue scolaire',
        ],
    },

    home: {
        meubles: [
            'canapé', 'canape', 'salon', 'fauteuil', 'chaise', 'table', 'bureau',
            'lit', 'armoire', 'placard', 'étagère', 'bibliotheque', 'commode',
            'buffet', 'vitrine', 'meuble', 'furniture', 'bois', 'rattan', 'rotin',
        ],
        literie: [
            'matelas', 'sommier', 'drap', 'couette', 'oreiller', 'couverture',
            'traversin', 'housse de couette', 'literie',
        ],
        cuisine: [
            'casserole', 'poele', 'faitout', 'service de table', 'assiette', 'verre',
            'tasse', 'couverts', 'ustensile', 'planche', 'couteau', 'presse agrume',
            'moule', 'cocotte', 'wok', 'sauteuse', 'théière',
        ],
        decoration: [
            'tableau', 'miroir', 'tapis', 'rideau', 'coussin', 'vase', 'bougie',
            'cadre', 'horloge', 'lampe', 'lustre', 'décoration', 'decoration',
            'statue', 'plante artificielle', 'fleur artificielle', 'toile',
        ],
        salle_de_bain: [
            'douche', 'baignoire', 'lavabo', 'toilette', 'robinetterie', 'serviette',
            'peignoir', 'porte-serviette', 'miroir salle de bain', 'meuble sdb',
        ],
        linge_maison: [
            'nappe', 'torchon', 'essuie-tout', 'serviette de table', 'voilage',
        ],
    },

    vehicles: {
        voitures: [
            'voiture', 'auto', 'berline', 'suv', 'monospace', 'citadine', 'break',
            'toyota', 'honda', 'hyundai', 'kia', 'ford', 'renault', 'peugeot',
            'mercedes', 'bmw', 'audi', 'volkswagen', 'mitsubishi', 'nissan', '4x4',
            'crossover', 'pickup', 'camion', 'camionnette', 'bus', 'minibus',
        ],
        motos: [
            'moto', 'mocopé', 'mototaxi', 'scooter', 'yamaha', 'kawasaki', 'bajaj',
            'tvs', 'hero', 'lifan', 'haojue', 'tricycle',
        ],
        pieces_auto: [
            'pneu', 'jante', 'amortisseur', 'batterie voiture', 'filtre', 'huile moteur',
            'frein', 'disque', 'plaquette', 'alternateur', 'démarreur', 'carburateur',
            'courroie', 'radiateur', 'pare-choc', 'rétroviseur', 'phare', 'feu',
            'pare-brise', 'vitre', 'siège auto', 'autoradio',
        ],
        bateaux: [
            'bateau', 'pirogue', 'canot', 'moteur hors-bord', 'outboard', 'chaloupe',
        ],
    },

    sports: {
        fitness: [
            'haltère', 'haltere', 'développé couché', 'musculation', 'barre', 'disque',
            'tapis roulant', 'vélo elliptique', 'rameur', 'velo appartement',
            'banc fitness', 'kettlebell', 'corde à sauter', 'elastique', 'yoga',
        ],
        football: [
            'ballon football', 'maillot foot', 'crampon', 'gardien', 'but', 'filet',
        ],
        basketball: [
            'ballon basket', 'panier', 'basketball', 'maillot basket',
        ],
        natation: [
            'maillot bain', 'lunette natation', 'bonnet natation', 'palme', 'tuba',
        ],
        velo: [
            'vélo', 'velo', 'bicycle', 'mtb', 'vtt', 'route', 'cyclisme', 'casque vélo',
            'chambre à air',
        ],
        arts_martiaux: [
            'gant boxe', 'kimono', 'judo', 'karate', 'muay thai', 'mma', 'sac frappe',
        ],
        camping: [
            'tente', 'sleeping bag', 'sac de couchage', 'randonnée', 'sac à dos sport',
            'gourde', 'lampe frontale', 'camping',
        ],
    },

    beauty: {
        soins_peau: [
            'crème', 'creme', 'lotion', 'serum', 'hydratant', 'éclaircissant',
            'eclaircissant', 'savon', 'gel douche', 'exfoliant', 'masque visage',
            'contour des yeux', 'fond de teint', 'bb cream', 'toner', 'micellair',
            'vaseline', 'beurre de karité', 'huile de coco', 'aloe vera',
        ],
        maquillage: [
            'rouge à lèvres', 'lipstick', 'mascara', 'fard', 'ombre à paupières',
            'blush', 'poudre', 'anticernes', 'eyeliner', 'khol', 'correcteur',
            'gloss', 'palette maquillage', 'bronzer', 'highlighter',
        ],
        cheveux: [
            'shampoing', 'après-shampoing', 'masque capillaire', 'huile cheveux',
            'lisseur', 'fer à lisser', 'sèche-cheveux', 'brosse', 'peigne', 'extension',
            'perruque', 'tresse', 'wigs', 'lace front', 'braids', 'tissage', 'rajout',
        ],
        parfum: [
            'parfum', 'eau de toilette', 'déodorant', 'antiperspirant', 'cologne',
            'fragrance',
        ],
        ongles: [
            'vernis', 'nail art', 'gel ongles', 'faux ongles', 'lime', 'manucure',
        ],
        rasage: [
            'rasoir', 'mousse à raser', 'after shave', 'tondeuse', 'barbe',
        ],
    },

    health: {
        medicaments: [
            'médicament', 'medicament', 'paracétamol', 'ibuprofène', 'antibiotique',
            'vitamines', 'complément alimentaire', 'omega', 'zinc', 'fer',
        ],
        medical: [
            'tensiomètre', 'tensiometre', 'glucometre', 'glycémie', 'thermomètre',
            'stéthoscope', 'fauteuil roulant', 'béquille', 'déambulateur',
            'oxymètre', 'masque chirurgical', 'gant medicale', 'lit medical',
        ],
        sport_sante: [
            'gel antidouleur', 'bande de soutien', 'genouillère', 'chevillière',
            'dorsalgie', 'ceinture lombaire',
        ],
    },

    tools: {
        electrique: [
            'perceuse', 'visseuse', 'meuleuse', 'scie', 'ponceuse', 'rabot',
            'makita', 'bosch', 'dewalt', 'stanley', 'black decker', 'ryobi',
        ],
        main: [
            'marteau', 'tournevis', 'clé', 'pince', 'niveau', 'mètre ruban',
            'burin', 'ciseaux', 'soin de coupe', 'masse', 'chalumeau',
        ],
        echelle: [
            'echelle', 'échafaudage', 'escabeau', 'plateforme',
        ],
        jardinage: [
            'tronçonneuse', 'débroussailleuse', 'tondeuse', 'taille haie', 'souffleur',
            'arrosoir', 'tuyau arrosage', 'brouette',
        ],
        soudure: [
            'poste à souder', 'soudure', 'electrode', 'masque soudure', 'fil soudure',
        ],
    },

    construction: {
        materiaux: [
            'ciment', 'béton', 'beton', 'sable', 'gravier', 'brique', 'parpaing',
            'pierre', 'ardoise', 'carrelage', 'faience', 'dalle', 'fer à béton',
            'treillis', 'poutre', 'bois construction', 'planche', 'contreplaqué',
        ],
        plomberie: [
            'tuyau', 'robinet', 'vanne', 'siphon', 'ballon eau', 'chauffe-eau',
            'pompe eau', 'compteur', 'fosse septique',
        ],
        electricite_bat: [
            'câble électrique', 'disjoncteur', 'tableau électrique', 'prise', 'interrupteur',
            'fil électrique', 'ampoule', 'néon', 'led', 'spot', 'projecteur',
        ],
        peinture: [
            'peinture', 'enduit', 'vernis', 'laque', 'rouleau', 'pinceau', 'couleur mur',
        ],
        toiture: [
            'tôle', 'tole', 'bac acier', 'tuile', 'gouttière', 'zinguerie',
        ],
    },

    garden: {
        plantes: [
            'plante', 'fleur', 'arbre', 'arbuste', 'graines', 'semence', 'pot de fleur',
            'terreau', 'compost', 'engrais',
        ],
        mobilier_jardin: [
            'table jardin', 'chaise jardin', 'transat', 'salon jardin', 'parasol',
            'barbecue', 'plancha', 'piscine gonflable',
        ],
        arrosage: [
            'arrosoir', 'tuyau irriguation', 'pulvérisateur', 'pompe arrosage',
        ],
    },

    office: {
        fournitures: [
            'stylo', 'cahier', 'classeur', 'chemise', 'ramette', 'cartouche encre',
            'toner', 'agenda', 'bloc-notes', 'post-it', 'ciseaux bureau',
            'calculatrice', 'calculette', 'agrafeuse', 'perforeuse',
        ],
        mobilier_bureau: [
            'bureau professionnel', 'chaise bureau', 'armoire bureau', 'classeur tiroir',
            'étagère bureau', 'caisson', 'siège ergonomique',
        ],
        equipements: [
            'photocopieur', 'fax', 'téléphone fixe', 'central téléphonique', 'projecteur bureau',
            'tableau blanc', 'écran projection', 'badge', 'pointeuse',
        ],
    },

    industry: {
        machines: [
            'machine industrielle', 'compresseur', 'générateur', 'groupe electrogene',
            'pompe industrielle', 'convoyeur', 'grue', 'chariot élévateur', 'forklift',
            'perceuse industrielle', 'tour', 'fraiseuse', 'presse',
        ],
        emballage: [
            'carton', 'emballage', 'film plastique', 'sac kraft', 'ruban adhésif',
            'palette', 'bulle', 'mousse protection',
        ],
        agriculture: [
            'tracteur', 'motoculteur', 'pulvérisateur agricole', 'semoir', 'moissonneuse',
            'fertilisant', 'pesticide', 'herbicide', 'élevage', 'aliment bétail',
        ],
    },

    security: {
        surveillance: [
            'camera surveillance', 'cctv', 'dvr', 'nvr', 'camera ip', 'alarme',
            'detecteur mouvement', 'sirène', 'badge access', 'controle accès',
        ],
        serrurerie: [
            'serrure', 'cadenas', 'verrou', 'coffre-fort', 'blindage',
        ],
        protection: [
            'gilet pare-balle', 'gilet de sécurité', 'casque chantier', 'harnais',
            'extincteur', 'détecteur fumée', 'exutoire',
        ],
    },

    baby: {
        puériculture: [
            'poussette', 'landau', 'siège auto bébé', 'couffin', 'berceau',
            'transat bébé', 'chaise haute', 'parc bébé',
        ],
        alimentation_bebe: [
            'lait bébé', 'lait maternisé', 'nestlé bébé', 'biberon', 'tétine',
            'chauffe-biberon', 'stérilisateur', 'petits pots',
        ],
        hygiene_bebe: [
            'couche', 'lingette bébé', 'talc bébé', 'crème fesses', 'baignoire bébé',
        ],
        jouets_eveil: [
            'hochet', 'mobile musical', 'tapis eveil', 'livre bébé',
        ],
    },

    toys: {
        jeux_enfants: [
            'jouet', 'voiture jouet', 'poupée', 'lego', 'playmobil', 'puzzle',
            'jeu société', 'jeu construction', 'peluche', 'marionette',
        ],
        jeux_electroniques: [
            'console portable', 'jeu video', 'manette enfant', 'tablette enfant',
        ],
        plein_air: [
            'vélo enfant', 'trottinette', 'kart', 'trampoline', 'piscine enfant',
            'toboggan', 'balançoire',
        ],
    },

    pets: {
        chiens_chats: [
            'laisse', 'collier animaux', 'gamelle', 'aquarium', 'cage', 'litière',
            'griffoir', 'croquettes', 'nourriture chien', 'nourriture chat', 'brosse animal',
            'panier animal', 'jouet animal', 'chien', 'chat', 'perroquet',
        ],
        veterinaire: [
            'antiparasitaire', 'vermifuge', 'vaccin animal', 'consultation vétérinaire',
        ],
    },

    food: {
        epicerie: [
            'riz', 'farine', 'huile alimentaire', 'sucre', 'sel', 'tomate', 'haricot',
            'soja', 'maïs', 'manioc', 'fufu', 'semoule', 'pâte tomate', 'sardine',
            'thon', 'conserve', 'lait', 'beurre', 'fromage', 'oeuf', 'spaghetti',
            'macaroni', 'pain', 'café', 'thé', 'chocolat', 'biscuit', 'confiture',
        ],
        boissons: [
            'eau minérale', 'jus', 'soda', 'coca', 'bière', 'vin', 'whisky', 'champagne',
            'boisson energisante', 'sirop',
        ],
        condiments: [
            'épice', 'piment', 'maggi', 'moutarde', 'mayonnaise', 'vinaigre',
            'sauce soja', 'ketchup', 'cube', 'bouillon',
        ],
    },

    other: {
        divers: [
            'autre', 'divers', 'varia',
        ],
    },
};

// ─────────────────────────────────────────────────────────────────────────────
// MAPPING catégorie → sous-catégorie par défaut (si pas de sous-catégorie matchée)
// ─────────────────────────────────────────────────────────────────────────────
const DEFAULT_SUBCATEGORY = {
    electronics: 'accessoires_elec',
    fashion: 'vetements_homme',
    home: 'meubles',
    vehicles: 'voitures',
    sports: 'fitness',
    beauty: 'soins_peau',
    health: 'medical',
    tools: 'main',
    construction: 'materiaux',
    garden: 'plantes',
    office: 'fournitures',
    industry: 'machines',
    security: 'surveillance',
    baby: 'puériculture',
    toys: 'jeux_enfants',
    pets: 'chiens_chats',
    food: 'epicerie',
    other: 'divers',
};

// ─────────────────────────────────────────────────────────────────────────────
// Normalisation : supprime accents, minuscules, garde alphanumériques + espaces
// ─────────────────────────────────────────────────────────────────────────────
function normalize(str) {
    return (str || '')
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '') // supprimer les diacritiques
        .replace(/[^a-z0-9\s'-]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Mise en cache du dictionnaire normalisé (construit une seule fois au démarrage)
// ─────────────────────────────────────────────────────────────────────────────
let _normalizedDict = null;

function getNormalizedDict() {
    if (_normalizedDict) return _normalizedDict;
    _normalizedDict = {};
    for (const [cat, subcats] of Object.entries(CATEGORY_DICT)) {
        _normalizedDict[cat] = {};
        for (const [subcat, keywords] of Object.entries(subcats)) {
            _normalizedDict[cat][subcat] = keywords.map(normalize);
        }
    }
    return _normalizedDict;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fonction principale d'analyse
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Analyse le nom et la description d'un produit pour en déduire
 * la catégorie et la sous-catégorie.
 *
 * @param {string} name - Nom du produit
 * @param {string} [description=''] - Description optionnelle
 * @returns {{ category: string, subcategory: string, confidence: number, matched: string[] }}
 */
function categorizeByName(name, description = '') {
    const dict = getNormalizedDict();
    const text = normalize(name + ' ' + description);
    const words = text.split(' ').filter(Boolean);

    // Scores : { category: { subcat: score } }
    const scores = {};
    const matchedKeywords = [];

    for (const [cat, subcats] of Object.entries(dict)) {
        scores[cat] = {};
        for (const [subcat, keywords] of Object.entries(subcats)) {
            let score = 0;
            for (const kw of keywords) {
                // Correspondance exacte de mot-clé (y compris multi-mots)
                if (text.includes(kw)) {
                    // Bonus si le mot-clé est une marque ou terme long (> 4 caractères)
                    const bonus = kw.length >= 5 ? 3 : (kw.length >= 3 ? 2 : 1);
                    score += bonus;
                    if (!matchedKeywords.includes(kw)) matchedKeywords.push(kw);
                }
                // Correspondance partielle sur les tokens simples
                else {
                    const kwTokens = kw.split(' ');
                    if (kwTokens.length === 1 && words.includes(kw)) {
                        score += 1;
                    }
                }
            }
            scores[cat][subcat] = score;
        }
    }

    // Trouver la meilleure catégorie + sous-catégorie
    let bestCat = 'other';
    let bestSubcat = 'divers';
    let bestScore = 0;

    for (const [cat, subcats] of Object.entries(scores)) {
        for (const [subcat, score] of Object.entries(subcats)) {
            if (score > bestScore) {
                bestScore = score;
                bestCat = cat;
                bestSubcat = subcat;
            }
        }
    }

    // Si score trop bas → other
    if (bestScore < 2) {
        bestCat = 'other';
        bestSubcat = 'divers';
    }

    // Si on a trouvé la catégorie mais pas de sous-catégorie (score sous-cat = 0 pour tous)
    const allSubcatScores = Object.values(scores[bestCat] || {});
    const maxSubcatScore = Math.max(...allSubcatScores, 0);
    if (maxSubcatScore === 0) {
        bestSubcat = DEFAULT_SUBCATEGORY[bestCat] || 'divers';
    }

    // Confiance en % : rapport score max / score max théorique (plafonné à 100)
    if (bestScore === 0) {
        return { category: 'other', subcategory: 'divers', confidence: 0, matched: [] };
    }
    const maxPossible = Object.values(dict[bestCat] || {})
        .flat()
        .reduce((acc, kw) => acc + (kw.length >= 5 ? 3 : kw.length >= 3 ? 2 : 1), 0);
    const confidence = maxPossible > 0
        ? Math.min(100, Math.round((bestScore / Math.max(bestScore * 3, 1)) * 100))
        : 0;


    return {
        category: bestCat,
        subcategory: bestSubcat,
        confidence,
        matched: matchedKeywords.slice(0, 10), // max 10 pour la lisibilité
    };
}

module.exports = { categorizeByName, normalize, CATEGORY_DICT };
