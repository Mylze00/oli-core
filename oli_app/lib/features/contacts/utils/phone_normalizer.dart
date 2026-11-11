/// Normalise un numéro de téléphone en format international (E.164).
///
/// Un numéro local commençant par 0 est rattaché à la RDC (+243), « 00 »
/// devient « + » et un « 243… » sans « + » est complété.
/// Renvoie null si le numéro n'est pas valide.
///
/// Doit rester identique à `normalizePhone` côté backend (src/utils/phone.js).
String? normalizePhone(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('0')) s = '+243${s.substring(1)}';
  if (RegExp(r'^243\d{9}$').hasMatch(s)) s = '+$s';
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(s) ? s : null;
}
