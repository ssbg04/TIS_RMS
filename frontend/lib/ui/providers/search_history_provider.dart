import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchHistoryKey = 'app_search_history';

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(() {
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
        state = decoded.map((e) => e.toString()).toList();
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
    final newList = List<String>.from(state)..remove(query);
    state = newList;
    await _saveHistory(newList);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
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
