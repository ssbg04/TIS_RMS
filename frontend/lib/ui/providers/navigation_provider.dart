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