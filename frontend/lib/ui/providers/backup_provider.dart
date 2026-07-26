import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/backup_repository.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository();
});

final backupProvider = AsyncNotifierProvider<BackupNotifier, void>(
  BackupNotifier.new,
);

final backupInfoProvider = FutureProvider.autoDispose<Map<String, String?>>((
  ref,
) async {
  final repo = ref.read(backupRepositoryProvider);
  return await repo.getBackupInfo();
});

class BackupNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> downloadBackup(
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(backupRepositoryProvider);
      await repo.downloadBackup(
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> restoreBackup(
    File file, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(backupRepositoryProvider);
      await repo.restoreBackup(
        file,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
