import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Centralized service for dynamic hardware vibration and haptic feedback across Android devices.
class HapticService {
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Success dynamic pattern: Crisp double vibration pulse
  static Future<void> success() async {
    if (!_isMobile) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        final hasCustomSupport =
            await Vibration.hasCustomVibrationsSupport();
        if (hasCustomSupport == true) {
          await Vibration.vibrate(
            pattern: [0, 80, 80, 100],
            intensities: [0, 150, 0, 255],
          );
        } else {
          await Vibration.vibrate(duration: 100);
        }
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  /// Error dynamic pattern: Strong multi-burst urgent alert vibration
  static Future<void> error() async {
    if (!_isMobile) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        final hasCustomSupport =
            await Vibration.hasCustomVibrationsSupport();
        if (hasCustomSupport == true) {
          await Vibration.vibrate(
            pattern: [0, 120, 80, 120, 80, 250],
            intensities: [0, 255, 0, 255, 0, 255],
          );
        } else {
          await Vibration.vibrate(duration: 400);
        }
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  /// Warning dynamic pattern: Distinct double strong vibration (e.g. logout, delete dialog)
  static Future<void> warning() async {
    if (!_isMobile) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        final hasCustomSupport =
            await Vibration.hasCustomVibrationsSupport();
        if (hasCustomSupport == true) {
          await Vibration.vibrate(
            pattern: [0, 150, 100, 150],
            intensities: [0, 220, 0, 220],
          );
        } else {
          await Vibration.vibrate(duration: 250);
        }
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  /// Info / Notice dynamic pattern: Gentle single notification vibration
  static Future<void> info() async {
    if (!_isMobile) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 90);
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  /// Normal vibration: Standard continuous device buzz
  static Future<void> vibrate({int duration = 250}) async {
    if (!_isMobile) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: duration);
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  /// Light haptic impact: Ideal for buttons, tab switches, and interactions
  static Future<void> light() async {
    if (!_isMobile) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium haptic impact: Ideal for modal opens, important toggles
  static Future<void> medium() async {
    if (!_isMobile) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Selection click: Ideal for pickers and list item taps
  static Future<void> selection() async {
    if (!_isMobile) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
