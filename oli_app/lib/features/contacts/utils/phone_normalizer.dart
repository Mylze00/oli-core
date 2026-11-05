/// Normalise un numéro de téléphone en format international (E.164).
///
/// Un numéro local commençant par 0 est rattaché à la RDC (+243).
/// Renvoie null si le numéro n'est pas valide.
///
/// Doit rester identique à `normalizePhone` côté backend (src/routes/contacts.routes.js).
String? normalizePhone(String raw) {
  var s = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('0') && !s.startsWith('+')) s = '+243${s.substring(1)}';
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(s) ? s : null;
}
