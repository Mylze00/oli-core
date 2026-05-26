/**
 * DÉTECTION AUTOMATIQUE DES OPÉRATEURS MOBILE MONEY (RDC)
 * 
 * Basé sur les préfixes officiels des opérateurs en République Démocratique du Congo
 * 
 * Utilisation :
 * const operator = detectOperatorFromPhone('+243827088682');
 * console.log(operator); // → 'vodacom'
 */

// Préfixes des opérateurs Mobile Money en RDC
const OPERATOR_PREFIXES = {
    vodacom: ['81', '82', '83', '84'],      // Vodacom M-Pesa
    orange: ['85', '89', '88'],             // Orange Money  
    airtel: ['90', '91', '97', '98', '99'], // Airtel Money
    africell: ['95', '96']                  // Africell Money
};

// Noms complets des opérateurs
const OPERATOR_NAMES = {
    vodacom: 'M-Pesa (Vodacom)',
    orange: 'Orange Money',
    airtel: 'Airtel Money',
    africell: 'Africell Money'
};

// Couleurs des opérateurs (pour l'UI)
const OPERATOR_COLORS = {
    vodacom: '#E31E25',  // Rouge Vodacom
    orange: '#FF6600',   // Orange
    airtel: '#ED1C24',   // Rouge Airtel
    africell: '#0066CC'  // Bleu Africell
};

/**
 * Détecte automatiquement l'opérateur Mobile Money d'après le numéro de téléphone
 * 
 * @param {string} phoneNumber - Numéro au format international (+243XXXXXXXXX) ou local (0XXXXXXXXX)
 * @returns {string|null} - Nom de l'opérateur ('vodacom', 'orange', 'airtel', 'africell') ou null si non détecté
 * 
 * @example
 * detectOperatorFromPhone('+243827088682')  // → 'vodacom'
 * detectOperatorFrom Phone('+243850123456')  // → 'orange'
 * detectOperatorFromPhone('0901234567')      // → 'airtel'
 */
function detectOperatorFromPhone(phoneNumber) {
    if (!phoneNumber) {
        return null;
    }

    // Nettoyer le numéro : enlever espaces, tirets, plus
    const cleaned = phoneNumber.replace(/[\s\-\+]/g, '');
    
    // Extraire le préfixe (2 chiffres après le code pays 243)
    let prefix = '';
    
    if (cleaned.startsWith('243')) {
        // Format international : +243827088682 → 82
        prefix = cleaned.substring(3, 5);
    } else if (cleaned.startsWith('0')) {
        // Format local : 0827088682 → 82
        prefix = cleaned.substring(1, 3);
    } else {
        // Format sans préfixe : 827088682 → 82
        prefix = cleaned.substring(0, 2);
    }
    
    // Chercher l'opérateur correspondant au préfixe
    for (const [operator, prefixes] of Object.entries(OPERATOR_PREFIXES)) {
        if (prefixes.includes(prefix)) {
            return operator;
        }
    }
    
    // Préfixe non reconnu
    return null;
}

/**
 * Obtient le nom complet de l'opérateur
 * 
 * @param {string} operator - Code opérateur ('vodacom', 'orange', etc.)
 * @returns {string} - Nom complet de l'opérateur
 * 
 * @example
 * getOperatorName('vodacom')  // → 'M-Pesa (Vodacom)'
 */
function getOperatorName(operator) {
    return OPERATOR_NAMES[operator] || 'Mobile Money';
}

/**
 * Obtient la couleur de l'opérateur
 * 
 * @param {string} operator - Code opérateur
 * @returns {string} - Code couleur hexadécimal
 */
function getOperatorColor(operator) {
    return OPERATOR_COLORS[operator] || '#FF6B35';
}

/**
 * Valide un numéro de téléphone RDC
 * 
 * @param {string} phoneNumber - Numéro à valider
 * @returns {boolean} - True si le format est valide
 * 
 * @example
 * validateRDCPhone('+243827088682')  // → true
 * validateRDCPhone('0827088682')     // → true
 * validateRDCPhone('123456')         // → false
 */
function validateRDCPhone(phoneNumber) {
    const cleaned = phoneNumber.replace(/[\s\-\+]/g, '');
    
    // Format RDC : 243XXXXXXXXX (9 chiffres après 243) ou 0XXXXXXXXX (9 chiffres après 0)
    // Premier chiffre significatif doit être 8 ou 9
    const patterns = [
        /^243[89]\d{7}$/,   // +243827088682
        /^0[89]\d{7}$/,     // 0827088682
        /^[89]\d{7}$/       // 827088682
    ];
    
    return patterns.some(pattern => pattern.test(cleaned));
}

/**
 * Formate un numéro de téléphone au format international
 * 
 * @param {string} phoneNumber - Numéro à formater
 * @returns {string} - Numéro formaté (+243XXXXXXXXX)
 * 
 * @example
 * formatPhoneNumber('0827088682')    // → '+243827088682'
 * formatPhoneNumber('827088682')     // → '+243827088682'
 * formatPhoneNumber('+243827088682') // → '+243827088682'
 */
function formatPhoneNumber(phoneNumber) {
    const cleaned = phoneNumber.replace(/[\s\-\+]/g, '');
    
    if (cleaned.startsWith('243')) {
        return '+' + cleaned;
    } else if (cleaned.startsWith('0')) {
        return '+243' + cleaned.substring(1);
    } else if (cleaned.length === 9) {
        return '+243' + cleaned;
    }
    
    return phoneNumber; // Retourner tel quel si format inconnu
}

/**
 * Obtient l'ID du provider Unipesa correspondant à l'opérateur
 * 
 * @param {string} operator - Code opérateur ('vodacom', 'orange', etc.)
 * @returns {number} - ID du provider dans l'API Unipesa
 */
function getUnipesaProviderId(operator) {
    const mapping = {
        vodacom: 9,
        mpesa: 9,
        orange: 10,
        orangemoney: 10,
        airtel: 17,
        africell: 19
    };
    
    return mapping[operator] || 14; // 14 = SIMULATOR par défaut
}

/**
 * Détection complète avec toutes les informations
 * 
 * @param {string} phoneNumber - Numéro de téléphone
 * @returns {object} - Objet avec toutes les infos de l'opérateur
 * 
 * @example
 * detectOperatorInfo('+243827088682')
 * // → {
 * //   operator: 'vodacom',
 * //   name: 'M-Pesa (Vodacom)',
 * //   color: '#E31E25',
 * //   prefix: '82',
 * //   unipesaId: 9,
 * //   isValid: true,
 * //   formattedPhone: '+243827088682'
 * // }
 */
function detectOperatorInfo(phoneNumber) {
    const operator = detectOperatorFromPhone(phoneNumber);
    const cleaned = phoneNumber.replace(/[\s\-\+]/g, '');
    let prefix = '';
    
    if (cleaned.startsWith('243')) {
        prefix = cleaned.substring(3, 5);
    } else if (cleaned.startsWith('0')) {
        prefix = cleaned.substring(1, 3);
    } else {
        prefix = cleaned.substring(0, 2);
    }
    
    return {
        operator: operator,
        name: operator ? getOperatorName(operator) : 'Opérateur inconnu',
        color: operator ? getOperatorColor(operator) : '#FF6B35',
        prefix: prefix,
        unipesaId: operator ? getUnipesaProviderId(operator) : null,
        isValid: validateRDCPhone(phoneNumber),
        formattedPhone: formatPhoneNumber(phoneNumber)
    };
}

// Export pour Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        detectOperatorFromPhone,
        getOperatorName,
        getOperatorColor,
        validateRDCPhone,
        formatPhoneNumber,
        getUnipesaProviderId,
        detectOperatorInfo,
        OPERATOR_PREFIXES,
        OPERATOR_NAMES,
        OPERATOR_COLORS
    };
}

// Tests automatiques (exécutés si le fichier est lancé directement)
if (typeof require !== 'undefined' && require.main === module) {
    console.log('\n🧪 TESTS DE DÉTECTION D\'OPÉRATEUR\n');
    
    const testCases = [
        { phone: '+243827088682', expected: 'vodacom', description: 'Vodacom (82)' },
        { phone: '+243850123456', expected: 'orange', description: 'Orange (85)' },
        { phone: '+243901234567', expected: 'airtel', description: 'Airtel (90)' },
        { phone: '+243951234567', expected: 'africell', description: 'Africell (95)' },
        { phone: '0827088682', expected: 'vodacom', description: 'Vodacom format local' },
        { phone: '827088682', expected: 'vodacom', description: 'Vodacom sans préfixe' },
        { phone: '+243999999999', expected: 'airtel', description: 'Airtel (99)' },
        { phone: '+243701234567', expected: null, description: 'Préfixe invalide (70)' }
    ];
    
    let passed = 0;
    let failed = 0;
    
    testCases.forEach(test => {
        const result = detectOperatorFromPhone(test.phone);
        const status = result === test.expected ? '✅' : '❌';
        
        if (result === test.expected) {
            passed++;
        } else {
            failed++;
        }
        
        console.log(`${status} ${test.description}`);
        console.log(`   Numéro: ${test.phone}`);
        console.log(`   Attendu: ${test.expected}`);
        console.log(`   Obtenu: ${result}`);
        console.log('');
    });
    
    console.log(`\n📊 Résultats: ${passed} réussis, ${failed} échoués\n`);
    
    // Test de detectOperatorInfo
    console.log('🔍 Test detectOperatorInfo("+243827088682"):\n');
    console.log(JSON.stringify(detectOperatorInfo('+243827088682'), null, 2));
    console.log('');
}
