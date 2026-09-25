import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/haptic_service.dart';

const _kSoundEnabledKey = 'pref_sound_enabled';
const _kVibrationEnabledKey = 'pref_vibration_enabled';

/// State notifier for global UI sound effects preference.
class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return !SoundService.isMuted;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kSoundEnabledKey) ?? false;
    SoundService.isMuted = !enabled;
    state = enabled;
  }

  /// Toggle sound effects on or off and persist.
  Future<void> setSoundEnabled(bool enabled) async {
    SoundService.isMuted = !enabled;
    state = enabled;
    if (enabled) {
      SoundService.playSuccess();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoundEnabledKey, enabled);
  }
}

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(
  SoundEnabledNotifier.new,
);

/// State notifier for global UI vibration and haptic feedback preference.
class VibrationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return HapticService.isEnabled;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kVibrationEnabledKey) ?? false;
    HapticService.isEnabled = enabled;
    state = enabled;
  }

  /// Toggle vibration on or off and persist.
  Future<void> setVibrationEnabled(bool enabled) async {
    HapticService.isEnabled = enabled;
    state = enabled;
    if (enabled) {
      HapticService.medium();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrationEnabledKey, enabled);
  }
}

final vibrationEnabledProvider = NotifierProvider<VibrationEnabledNotifier, bool>(
  VibrationEnabledNotifier.new,
);
