import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/user/user_provider.dart';

final callHistoryProvider = StateNotifierProvider<CallHistoryNotifier, AsyncValue<List<dynamic>>>((ref) {
  return CallHistoryNotifier(ref);
});

class CallHistoryNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;

  CallHistoryNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchCallHistory();
  }

  Future<void> fetchCallHistory() async {
    final user = ref.read(userProvider).value;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/calls/history');
      
      if (response.statusCode == 200) {
        state = AsyncValue.data(response.data);
      } else {
        state = AsyncValue.error('Erreur de chargement', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
