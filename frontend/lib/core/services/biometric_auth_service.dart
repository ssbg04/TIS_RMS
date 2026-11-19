import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyEnabled = 'biometric_enabled';
  static const String _keyDeclined = 'biometric_prompt_declined';
  static const String _keyUsername = 'biometric_username';
  static const String _keyToken = 'biometric_token';
  static const String _legacyKeyPassword = 'biometric_password';

  static Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty || isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _keyEnabled)) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSavedCredentials() async {
    try {
      final enabled = await isEnabled();
      if (!enabled) return false;
      final user = await _storage.read(key: _keyUsername);
      final token = await _storage.read(key: _keyToken);
      // Clean legacy password if it was saved previously
      try {
        await _storage.delete(key: _legacyKeyPassword);
      } catch (_) {}
      return user != null && user.isNotEmpty && token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getSavedUsername() async {
    try {
      return await _storage.read(key: _keyUsername);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSavedToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> wasPromptDeclined() async {
    try {
      return (await _storage.read(key: _keyDeclined)) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPromptDeclined(bool declined) async {
    try {
      await _storage.write(key: _keyDeclined, value: declined ? 'true' : 'false');
    } catch (_) {}
  }

  static Future<void> saveBiometricToken(String username, String token) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyEnabled, value: 'true');
    await _storage.write(key: _keyDeclined, value: 'false');
    // Ensure no plaintext password ever remains
    try {
      await _storage.delete(key: _legacyKeyPassword);
    } catch (_) {}
  }

  static Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEnabled);
      await _storage.delete(key: _keyUsername);
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _legacyKeyPassword);
    } catch (_) {}
  }

  /// Triggers biometric prompt and returns stored biometric token on success.
  static Future<({String username, String token})?>
      authenticateAndGetToken() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Verify your identity to sign in to TIS RMS',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!didAuthenticate) return null;

      final username = await _storage.read(key: _keyUsername);
      final token = await _storage.read(key: _keyToken);
      if (username == null || username.isEmpty || token == null || token.isEmpty) {
        return null;
      }
      return (username: username, token: token);
    } catch (_) {
      return null;
    }
  }

  /// Authenticate device owner (e.g. before registering new biometric token).
  static Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? 'Verify your identity to enable biometric sign-in',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
