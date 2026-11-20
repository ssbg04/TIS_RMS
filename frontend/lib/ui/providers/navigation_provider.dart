import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Create a strictly typed Notifier class
class ActiveTabNotifier extends Notifier<String> {
  @override
  String build() {
    return 'Dashboard'; // Default active tab
  }

  // 2. Expose a safe method to change the tab
  void setTab(String tabName) {
    state = tabName;
  }
}

// 3. Expose the NotifierProvider
final activeTabProvider = NotifierProvider<ActiveTabNotifier, String>(() {
  return ActiveTabNotifier();
});

/// Coordinates tab-local back handling (e.g., closing an open folder or exiting
/// multi-select) so only the root layout owns a [PopScope] on the [ModalRoute].
class TabBackRegistry {
  final Map<String, bool Function()> _handlers = {};

  void register(String tabName, bool Function() handler) {
    _handlers[tabName] = handler;
  }

  void unregister(String tabName) {
    _handlers.remove(tabName);
  }

  bool tryHandle(String tabName) {
    final handler = _handlers[tabName];
    if (handler == null) return false;
    return handler();
  }
}

final tabBackRegistryProvider = Provider<TabBackRegistry>((ref) {
  return TabBackRegistry();
});

/// Pending username to prompt for biometric enrollment once Dashboard is shown.
final pendingBiometricPromptUsernameProvider = StateProvider<String?>((ref) => null);

/// Optional target category to open automatically when navigating to Settings.
final pendingSettingsCategoryProvider = StateProvider<String?>((ref) => null);
