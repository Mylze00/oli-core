/**
 * ⚠️  POINT D'ENTRÉE LEGACY — NE PAS UTILISER DIRECTEMENT
 *
 * Ce fichier existait comme serveur alternatif simplifié (routes Unipesa + OLI Bank seulement).
 * Il a été unifié avec server.js (le serveur complet) pour éviter :
 *   - Le double serveur Express sur le même port
 *   - Des routes manquantes (auth, orders, admin, etc.)
 *   - Des configurations CORS incohérentes
 *
 * ✅ Point d'entrée officiel : src/server.js
 * ✅ Package.json "main"   : "server.js"
 * ✅ Package.json "start"  : "node src/server.js"
 *
 * Ce module réexporte l'app de server.js pour assurer la rétrocompatibilité
 * avec tout code existant qui importait `require('./app')`.
 */

// [P1.2] Délégation totale à server.js — plus de double serveur
module.exports = require('./server');
