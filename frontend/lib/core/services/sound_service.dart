import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized service for low-latency UI sound effects across Windows and Android devices.
class SoundService {
  static AudioPlayer? _player;
  static bool _initialized = false;
  static bool _muted = false;

  /// Whether sound effects are globally muted.
  static bool get isMuted => _muted;
  static set isMuted(bool value) => _muted = value;

  static void _ensureInitialized() {
    if (_initialized && _player != null) return;
    try {
      _player = AudioPlayer();
      _player!.setPlayerMode(PlayerMode.lowLatency);
      _player!.setVolume(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('SoundService: Failed to initialize AudioPlayer: $e');
    }
  }

  static Future<void> _playSound(String assetFileName, {bool isErrorOrAlert = false}) async {
    if (_muted) return;
    try {
      _ensureInitialized();
      if (_player != null) {
        // Stop current sound if playing, then play new sound
        await _player!.stop();
        await _player!.play(AssetSource('sounds/$assetFileName'));
      } else {
        // Fallback to system sound
        if (isErrorOrAlert) {
          await SystemSound.play(SystemSoundType.alert);
        } else {
          await SystemSound.play(SystemSoundType.click);
        }
      }
    } catch (e) {
      debugPrint('SoundService: Play error for $assetFileName: $e');
      try {
        if (isErrorOrAlert) {
          await SystemSound.play(SystemSoundType.alert);
        } else {
          await SystemSound.play(SystemSoundType.click);
        }
      } catch (_) {}
    }
  }

  /// Success sound: Pleasant rising melodic chime
  static Future<void> playSuccess() async {
    await _playSound('success.wav');
  }

  /// Error sound: Urgent alert pulse
  static Future<void> playError() async {
    await _playSound('error.wav', isErrorOrAlert: true);
  }

  /// Warning sound: Two-tone caution alert
  static Future<void> playWarning() async {
    await _playSound('warning.wav', isErrorOrAlert: true);
  }

  /// Info sound: Crisp, subtle notification pop
  static Future<void> playInfo() async {
    await _playSound('info.wav');
  }

  /// Confirm sound: Clean prompt chime
  static Future<void> playConfirm() async {
    await _playSound('confirm.wav');
  }

  /// Disposes player resources if needed
  static Future<void> dispose() async {
    try {
      await _player?.dispose();
      _player = null;
      _initialized = false;
    } catch (_) {}
  }
}
