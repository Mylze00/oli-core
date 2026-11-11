/**
 * Outils de numéros de téléphone partagés (contacts, portefeuille).
 * `normalizePhone` doit rester identique à
 * oli_app/lib/features/contacts/utils/phone_normalizer.dart.
 */

const E164 = /^\+[1-9]\d{7,14}$/;

/**
 * Normalise un numéro en format international (E.164).
 * Un numéro local commençant par 0 est rattaché à la RDC (+243),
 * « 00 » devient « + » et un « 243… » sans « + » est complété.
 * Renvoie null si le numéro n'est pas valide.
 */
function normalizePhone(raw) {
    if (typeof raw !== 'string') return null;
    let s = raw.trim().replace(/[\s\-().]/g, '');
    if (s.startsWith('00')) s = '+' + s.slice(2);
    if (s.startsWith('0')) s = '+243' + s.slice(1);
    if (/^243\d{9}$/.test(s)) s = '+' + s;
    return E164.test(s) ? s : null;
}

/**
 * Masque le milieu d'un numéro : +243812345678 → +243 81•• ••• 678.
 * Permet de reconnaître la personne sans révéler son numéro.
 */
function maskPhone(phone) {
    if (!phone) return null;
    const p = String(phone);
    const m = p.match(/^\+243(\d{2})\d{4}(\d{3})$/);
    if (m) return `+243 ${m[1]}•• ••• ${m[2]}`;
    if (p.length <= 6) return '•'.repeat(p.length);
    return `${p.slice(0, 4)}${'•'.repeat(p.length - 7)}${p.slice(-3)}`;
}

module.exports = { E164, normalizePhone, maskPhone };
