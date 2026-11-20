import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/app_colors.dart';
import '../../ui/providers/auth_provider.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Storage keys (Per-user namespaced)
  static const String _keyEnrolledUsers = 'biometric_enrolled_users';
  static const String _keyLastUsername = 'biometric_last_username';

  // Legacy single-user keys for automatic migration
  static const String _legacyKeyEnabled = 'biometric_enabled';
  static const String _legacyKeyDeclined = 'biometric_prompt_declined';
  static const String _legacyKeyUsername = 'biometric_username';
  static const String _legacyKeyToken = 'biometric_token';
  static const String _legacyKeyPassword = 'biometric_password';

  static String _tokenKey(String username) =>
      'biometric_token_${username.toLowerCase().trim()}';
  static String _enabledKey(String username) =>
      'biometric_enabled_${username.toLowerCase().trim()}';
  static String _declinedKey(String username) =>
      'biometric_declined_${username.toLowerCase().trim()}';

  static bool _migrated = false;

  /// Migrates legacy single-user biometric storage to per-user storage
  static Future<void> _migrateLegacyIfNeeded() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final legacyUser = await _storage.read(key: _legacyKeyUsername);
      final legacyToken = await _storage.read(key: _legacyKeyToken);
      final legacyEnabled = await _storage.read(key: _legacyKeyEnabled);

      if (legacyUser != null &&
          legacyUser.isNotEmpty &&
          legacyToken != null &&
          legacyToken.isNotEmpty &&
          legacyEnabled == 'true') {
        final norm = legacyUser.toLowerCase().trim();
        await _storage.write(key: _tokenKey(norm), value: legacyToken);
        await _storage.write(key: _enabledKey(norm), value: 'true');
        await _storage.write(key: _keyLastUsername, value: legacyUser);

        final enrolled = <String>[legacyUser];
        await _storage.write(
            key: _keyEnrolledUsers, value: jsonEncode(enrolled));

        // Clean up legacy keys
        await _storage.delete(key: _legacyKeyUsername);
        await _storage.delete(key: _legacyKeyToken);
        await _storage.delete(key: _legacyKeyEnabled);
      }

      await _storage.delete(key: _legacyKeyDeclined);
      await _storage.delete(key: _legacyKeyPassword);
    } catch (e) {
      debugPrint('[BiometricAuthService] Migration error: $e');
    }
  }

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

  /// Returns whether biometrics is enabled specifically for [username].
  static Future<bool> isEnabledFor(String username) async {
    await _migrateLegacyIfNeeded();
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return false;
    try {
      return (await _storage.read(key: _enabledKey(norm))) == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Returns whether valid credentials exist specifically for [username].
  static Future<bool> hasSavedCredentialsFor(String username) async {
    await _migrateLegacyIfNeeded();
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return false;
    try {
      final enabled = await isEnabledFor(norm);
      if (!enabled) return false;
      final token = await _storage.read(key: _tokenKey(norm));
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Backwards-compatible check: returns true if ANY user is enrolled on this device.
  static Future<bool> hasSavedCredentials() async {
    final users = await getEnrolledUsernames();
    return users.isNotEmpty;
  }

  /// Returns list of all usernames with enrolled biometrics on this device.
  static Future<List<String>> getEnrolledUsernames() async {
    await _migrateLegacyIfNeeded();
    try {
      final raw = await _storage.read(key: _keyEnrolledUsers);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Returns the most recently logged-in biometric username.
  static Future<String?> getLastUsername() async {
    await _migrateLegacyIfNeeded();
    try {
      final last = await _storage.read(key: _keyLastUsername);
      if (last != null && last.isNotEmpty) return last;
      final users = await getEnrolledUsernames();
      return users.isNotEmpty ? users.first : null;
    } catch (_) {
      return null;
    }
  }

  /// Backwards-compatible: returns last active username.
  static Future<String?> getSavedUsername() => getLastUsername();

  /// Gets stored token specifically for [username].
  static Future<String?> getSavedTokenFor(String username) async {
    await _migrateLegacyIfNeeded();
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return null;
    try {
      return await _storage.read(key: _tokenKey(norm));
    } catch (_) {
      return null;
    }
  }

  /// Backwards-compatible: gets token for last active user.
  static Future<String?> getSavedToken() async {
    final lastUser = await getLastUsername();
    if (lastUser == null) return null;
    return getSavedTokenFor(lastUser);
  }

  static Future<bool> wasPromptDeclinedFor(String username) async {
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return false;
    try {
      return (await _storage.read(key: _declinedKey(norm))) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPromptDeclinedFor(
      String username, bool declined) async {
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return;
    try {
      await _storage.write(
          key: _declinedKey(norm), value: declined ? 'true' : 'false');
    } catch (_) {}
  }

  /// Saves biometric token specifically for [username].
  static Future<void> saveBiometricToken(String username, String token) async {
    await _migrateLegacyIfNeeded();
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return;

    await _storage.write(key: _tokenKey(norm), value: token);
    await _storage.write(key: _enabledKey(norm), value: 'true');
    await _storage.write(key: _declinedKey(norm), value: 'false');
    await _storage.write(key: _keyLastUsername, value: username);

    final users = await getEnrolledUsernames();
    if (!users.any((u) => u.toLowerCase() == norm)) {
      users.add(username);
      await _storage.write(key: _keyEnrolledUsers, value: jsonEncode(users));
    }
  }

  /// Clears biometric credentials specifically for [username].
  static Future<void> clearCredentialsFor(String username) async {
    await _migrateLegacyIfNeeded();
    final norm = username.toLowerCase().trim();
    if (norm.isEmpty) return;

    try {
      await _storage.delete(key: _tokenKey(norm));
      await _storage.delete(key: _enabledKey(norm));

      final users = await getEnrolledUsernames();
      users.removeWhere((u) => u.toLowerCase() == norm);
      await _storage.write(key: _keyEnrolledUsers, value: jsonEncode(users));

      final lastUser = await _storage.read(key: _keyLastUsername);
      if (lastUser != null && lastUser.toLowerCase() == norm) {
        if (users.isNotEmpty) {
          await _storage.write(key: _keyLastUsername, value: users.last);
        } else {
          await _storage.delete(key: _keyLastUsername);
        }
      }
    } catch (_) {}
  }

  /// Clears all biometric credentials across all users on this device.
  static Future<void> clearAllCredentials() async {
    try {
      final users = await getEnrolledUsernames();
      for (final u in users) {
        final norm = u.toLowerCase().trim();
        await _storage.delete(key: _tokenKey(norm));
        await _storage.delete(key: _enabledKey(norm));
        await _storage.delete(key: _declinedKey(norm));
      }
      await _storage.delete(key: _keyEnrolledUsers);
      await _storage.delete(key: _keyLastUsername);
    } catch (_) {}
  }

  /// Triggers biometric prompt and returns stored biometric token on success.
  /// If [requestedUsername] is provided, authenticates specifically for that user.
  static Future<({String username, String token})?> authenticateAndGetToken({
    String? requestedUsername,
  }) async {
    final enrolled = await getEnrolledUsernames();
    if (enrolled.isEmpty) return null;

    String? targetUser;
    if (requestedUsername != null && requestedUsername.trim().isNotEmpty) {
      targetUser = requestedUsername.trim();
      final hasCreds = await hasSavedCredentialsFor(targetUser);
      if (!hasCreds) return null;
    } else {
      final last = await getLastUsername();
      targetUser =
          (last != null && enrolled.contains(last)) ? last : enrolled.first;
    }

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Verify your identity to sign in to TIS RMS as $targetUser',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!didAuthenticate) return null;

      final token = await getSavedTokenFor(targetUser);
      if (token == null || token.isEmpty) return null;

      await _storage.write(key: _keyLastUsername, value: targetUser);
      return (username: targetUser, token: token);
    } catch (_) {
      return null;
    }
  }

  /// Authenticate device owner (e.g. before registering new biometric token).
  static Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason:
            reason ?? 'Verify your identity to enable biometric sign-in',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Shows the biometric enrollment modal on Dashboard if the device supports
  /// biometrics, [username] hasn't enrolled yet, and [username] hasn't chosen "Don't Ask".
  static Future<void> promptEnableIfEligible(
    BuildContext context,
    WidgetRef ref,
    String username,
  ) async {
    if (!await isSupported() || !context.mounted) return;
    if (await hasSavedCredentialsFor(username) || !context.mounted) return;
    if (await wasPromptDeclinedFor(username) || !context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: AppColors.primaryGreen),
            SizedBox(width: 10),
            Expanded(child: Text('Enable Biometric Login?')),
          ],
        ),
        content: Text(
          'Use your fingerprint or device biometrics to sign in faster as @$username next time on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('never'),
            child: const Text('Don\'t Ask'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('enable'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (result == 'enable') {
      final verified = await authenticate(
        reason: 'Scan your fingerprint or face to enable biometric sign-in',
      );
      if (!verified || !context.mounted) return;

      try {
        final token =
            await ref.read(authProvider.notifier).registerBiometrics();
        await saveBiometricToken(username, token);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Sign in with biometrics enabled for @$username on this device.'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to register biometrics: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to enable biometrics: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (result == 'never') {
      await setPromptDeclinedFor(username, true);
    }
  }
}
