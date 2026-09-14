import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchHistoryKey = 'app_search_history';

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(() {
      return SearchHistoryNotifier();
    });

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_searchHistoryKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        final loaded = decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final merged = [...state];
        for (final item in loaded) {
          if (!merged.contains(item)) {
            merged.add(item);
          }
        }
        if (merged.length > 10) {
          merged.removeRange(10, merged.length);
        }
        state = merged;
      }
    } catch (e) {
      // Ignore errors on load
    }
  }

  Future<void> addSearch(String query) async {
    final trimQuery = query.trim();
    if (trimQuery.isEmpty) return;

    // Remove if exists to push to top
    final newList = List<String>.from(state)..remove(trimQuery);

    // Add to top
    newList.insert(0, trimQuery);

    // Keep max 10
    if (newList.length > 10) {
      newList.removeLast();
    }

    state = newList;
    await _saveHistory(newList);
  }

  Future<void> removeSearch(String query) async {
    final trimQuery = query.trim();
    final newList = List<String>.from(state)..remove(trimQuery);
    state = newList;
    await _saveHistory(newList);
  }

  Future<void> clearHistory() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      // Ignore errors on clear
    }
  }

  Future<void> _saveHistory(List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_searchHistoryKey, jsonEncode(list));
    } catch (e) {
      // Ignore errors on save
    }
  }
}
