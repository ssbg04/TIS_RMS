import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final systemSettingsProvider =
    AsyncNotifierProvider<SystemSettingsNotifier, Map<String, String>>(
  SystemSettingsNotifier.new,
);

class SystemSettingsNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final repository = ref.read(settingsRepositoryProvider);
    return await repository.getSettings();
  }

  Future<void> updateSetting(String key, String value) async {
    final current = state.asData?.value ?? {};
    final updated = Map<String, String>.from(current)..[key] = value;
    state = AsyncData(updated);

    try {
      final repository = ref.read(settingsRepositoryProvider);
      final serverUpdated = await repository.updateSettings({key: value});
      state = AsyncData({
        ...updated,
        ...serverUpdated,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
      ref.invalidateSelf();
    }
  }
}
