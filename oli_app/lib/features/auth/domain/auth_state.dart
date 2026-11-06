// Bug #2 fix: Ce fichier est un doublon de la classe AuthState définie dans
// features/auth/providers/auth_controller.dart. Il est conservé pour la
// compatibilité mais redirige vers la vraie définition.
//
// ⚠️ NE PAS utiliser ce fichier directement. Importer toujours depuis :
// package:oli_app/features/auth/providers/auth_controller.dart

export '../providers/auth_controller.dart' show AuthState;
