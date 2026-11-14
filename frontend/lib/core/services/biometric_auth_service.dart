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
  static const String _keyPassword = 'biometric_password';

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
      final pass = await _storage.read(key: _keyPassword);
      return user != null && user.isNotEmpty && pass != null && pass.isNotEmpty;
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

  static Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled, value: 'true');
    await _storage.write(key: _keyDeclined, value: 'false');
  }

  static Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEnabled);
      await _storage.delete(key: _keyUsername);
      await _storage.delete(key: _keyPassword);
    } catch (_) {}
  }

  static Future<({String username, String password})?>
      authenticateAndGetCredentials() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Verify your identity to sign in to TIS RMS',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!didAuthenticate) return null;

      final username = await _storage.read(key: _keyUsername);
      final password = await _storage.read(key: _keyPassword);
      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      return (username: username, password: password);
    } catch (_) {
      return null;
    }
  }
}

