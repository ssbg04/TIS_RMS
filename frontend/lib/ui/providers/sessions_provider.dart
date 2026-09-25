import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final sessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.getSessions();
});

final revokeSessionProvider = Provider.autoDispose((ref) {
  return (dynamic sessionId) async {
    final repository = ref.read(authRepositoryProvider);
    final id = sessionId is int ? sessionId : int.tryParse(sessionId.toString()) ?? 0;
    await repository.revokeSession(id);
    ref.invalidate(sessionsProvider);
  };
});

final revokeAllOtherSessionsProvider = Provider.autoDispose((ref) {
  return () async {
    final repository = ref.read(authRepositoryProvider);
    await repository.revokeAllOtherSessions();
    ref.invalidate(sessionsProvider);
  };
});
