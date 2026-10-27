import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/dashboard/models/dashboard_card_config.dart';
import 'auth_provider.dart';

class DashboardLayoutNotifier extends Notifier<List<DashboardCardConfig>> {
  static const String _prefKeyPrefix = 'tis_dashboard_layout_v2_';

  @override
  List<DashboardCardConfig> build() {
    final user = ref.watch(authProvider).value;
    final isAdmin = user?.role == 'admin';
    final initialCards = isAdmin
        ? DashboardCardConfig.defaultAdminCards()
        : DashboardCardConfig.defaultTeacherCards();

    // Trigger async load from SharedPreferences
    _loadSavedLayout(isAdmin, initialCards);

    return initialCards;
  }

  Future<void> _loadSavedLayout(
    bool isAdmin,
    List<DashboardCardConfig> defaults,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefKeyPrefix${isAdmin ? 'admin' : 'teacher'}';
      var jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) {
        // Migration check from v1
        final oldKey = 'tis_dashboard_layout_v1_${isAdmin ? 'admin' : 'teacher'}';
        jsonStr = prefs.getString(oldKey);
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        var savedList = decoded
            .map((e) => DashboardCardConfig.fromJson(e as Map<String, dynamic>))
            .toList();

        // If old 'kpis' ID is present, expand it to the 5 separated KPI cards
        final kpiIndex = savedList.indexWhere((c) => c.id == 'kpis');
        if (kpiIndex != -1) {
          final wasVisible = savedList[kpiIndex].isVisible;
          savedList.removeAt(kpiIndex);
          savedList.insertAll(kpiIndex, [
            DashboardCardConfig(
              id: 'kpi_digitalization',
              title: 'Digitalization Progress',
              colSpan: 6,
              isVisible: wasVisible,
            ),
            DashboardCardConfig(
              id: 'kpi_status',
              title: 'Status Distribution',
              colSpan: 6,
              isVisible: wasVisible,
            ),
            DashboardCardConfig(
              id: 'kpi_doc_types',
              title: 'Document Type Breakdown',
              colSpan: 12,
              isVisible: wasVisible,
            ),
            DashboardCardConfig(
              id: 'kpi_upload_trend',
              title: 'Upload Trends',
              colSpan: 6,
              isVisible: wasVisible,
            ),
            DashboardCardConfig(
              id: 'kpi_storage',
              title: 'Storage Analytics',
              colSpan: 6,
              isVisible: wasVisible,
            ),
          ]);
        }

        // Merge saved list with defaults to ensure any new cards or missing cards exist
        final merged = <DashboardCardConfig>[];
        final savedIds = <String>{};

        for (final item in savedList) {
          final matchingDefault = defaults.firstWhere(
            (d) => d.id == item.id,
            orElse: () => const DashboardCardConfig(id: '', title: ''),
          );
          if (matchingDefault.id.isNotEmpty) {
            merged.add(item.copyWith(title: matchingDefault.title));
            savedIds.add(item.id);
          }
        }

        // Add any defaults that were not in the saved list
        for (final d in defaults) {
          if (!savedIds.contains(d.id)) {
            merged.add(d);
          }
        }

        state = merged;
      }
    } catch (_) {
      // Fallback to defaults on error
    }
  }

  Future<void> _saveLayout(bool isAdmin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefKeyPrefix${isAdmin ? 'admin' : 'teacher'}';
      final jsonStr = jsonEncode(state.map((c) => c.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  /// Reorders card with id [draggedId] to the position of [targetId]
  void reorderCards(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final items = List<DashboardCardConfig>.from(state);
    final oldIndex = items.indexWhere((c) => c.id == draggedId);
    final targetIndex = items.indexWhere((c) => c.id == targetId);
    if (oldIndex == -1 || targetIndex == -1) return;

    final item = items.removeAt(oldIndex);
    items.insert(targetIndex, item);
    state = items;

    final user = ref.read(authProvider).value;
    _saveLayout(user?.role == 'admin');
  }

  /// Moves card up (-1) or down (+1)
  void moveCard(String id, int delta) {
    final items = List<DashboardCardConfig>.from(state);
    final currentIndex = items.indexWhere((c) => c.id == id);
    if (currentIndex == -1) return;

    final newIndex = currentIndex + delta;
    if (newIndex < 0 || newIndex >= items.length) return;

    final item = items.removeAt(currentIndex);
    items.insert(newIndex, item);
    state = items;

    final user = ref.read(authProvider).value;
    _saveLayout(user?.role == 'admin');
  }

  /// Updates the column span (6 or 12) for the given card
  void setCardSpan(String id, int colSpan) {
    state = [
      for (final card in state)
        if (card.id == id) card.copyWith(colSpan: colSpan) else card,
    ];
    final user = ref.read(authProvider).value;
    _saveLayout(user?.role == 'admin');
  }

  /// Toggles visibility for the card
  void toggleCardVisibility(String id, {bool? isVisible}) {
    state = [
      for (final card in state)
        if (card.id == id)
          card.copyWith(isVisible: isVisible ?? !card.isVisible)
        else
          card,
    ];
    final user = ref.read(authProvider).value;
    _saveLayout(user?.role == 'admin');
  }

  /// Resets card order and spans to default
  Future<void> resetToDefault() async {
    final user = ref.read(authProvider).value;
    final isAdmin = user?.role == 'admin';
    final defaults = isAdmin
        ? DashboardCardConfig.defaultAdminCards()
        : DashboardCardConfig.defaultTeacherCards();

    state = defaults;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefKeyPrefix${isAdmin ? 'admin' : 'teacher'}';
      await prefs.remove(key);
    } catch (_) {}
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, List<DashboardCardConfig>>(() {
  return DashboardLayoutNotifier();
});
