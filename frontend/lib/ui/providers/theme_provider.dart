import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';
const _kHighContrastKey = 'high_contrast_mode';

/// Provides the persisted [ThemeMode] for the app.
/// Reads from and writes to [SharedPreferences].
/// Possible values stored: 'system' | 'light' | 'dark'
/// Defaults to 'system' (follows device setting).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Initial load is synchronous — default to light mode until async read completes.
    _loadFromPrefs();
    return ThemeMode.light;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey) ?? 'light';
    state = _fromString(stored);
  }

  /// Set theme mode and persist the preference.
  Future<void> setThemeMode(String mode) async {
    state = _fromString(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode);
  }

  /// Returns the stored key string for the current [ThemeMode].
  String get currentKey {
    switch (state) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Provides the persisted high-contrast mode toggle for the app.
/// Reads from and writes to [SharedPreferences].
class HighContrastNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kHighContrastKey) ?? false;
    state = stored;
  }

  /// Set high-contrast mode and persist the preference.
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrastKey, enabled);
  }

  /// Toggle high-contrast mode and persist the preference.
  Future<void> toggle() => setEnabled(!state);
}

final highContrastProvider = NotifierProvider<HighContrastNotifier, bool>(
  HighContrastNotifier.new,
);
