import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/biometric_service.dart';

const _lockedConversationsKey = 'locked_conversations';

/// Discussions verrouillées sur cet appareil par empreinte, Face ID ou code du téléphone.
final lockedConversationsProvider =
    StateNotifierProvider<LockedConversationsNotifier, Set<String>>((ref) => LockedConversationsNotifier());

class LockedConversationsNotifier extends StateNotifier<Set<String>> {
  LockedConversationsNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_lockedConversationsKey) ?? const <String>[];
    if (mounted) state = saved.toSet();
  }

  Future<bool> authenticate(String reason) => BiometricService().authenticate(reason: reason);

  /// Renvoie false si l'utilisateur n'a pas pu confirmer son identité.
  Future<bool> setLocked(String conversationId, bool locked) async {
    final confirmed = await authenticate(
      locked ? 'Confirmez pour verrouiller cette discussion' : 'Confirmez pour déverrouiller cette discussion',
    );
    if (!confirmed) return false;

    final updated = {...state};
    locked ? updated.add(conversationId) : updated.remove(conversationId);
    state = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lockedConversationsKey, updated.toList());
    return true;
  }
}
