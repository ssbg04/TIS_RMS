import 'dart:ffi' show Abi;
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// Structured information about an available app update.
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseTitle;
  final String releaseNotes;
  final String htmlUrl;
  final String? downloadUrl;
  final String? assetName;
  final String? architecture;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.htmlUrl,
    this.downloadUrl,
    this.assetName,
    this.architecture,
    this.publishedAt,
  });
}

class AppUpdateService {
  static const String _repoReleasesUrl =
      'https://api.github.com/repos/ssbg04/TIS_RMS/releases/latest';

  /// Fallback version if PackageInfo fails to resolve on platform.
  static const String defaultFallbackVersion = '1.0.22';

  /// Detects the target CPU architecture on Android devices.
  /// Returns 'arm64', 'arm32', 'x86_64', or 'x86'.
  static Future<String?> getAndroidArchitecture() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final supportedAbis = androidInfo.supportedAbis.map((a) => a.toLowerCase()).toList();
      final supported64BitAbis = androidInfo.supported64BitAbis.map((a) => a.toLowerCase()).toList();

      // Check 64-bit ARM first (arm64-v8a)
      if (supported64BitAbis.any((abi) => abi.contains('arm64') || abi.contains('aarch64')) ||
          supportedAbis.any((abi) => abi.contains('arm64') || abi.contains('aarch64'))) {
        return 'arm64';
      }

      // Check 64-bit x86 (x86_64)
      if (supported64BitAbis.any((abi) => abi.contains('x86_64')) ||
          supportedAbis.any((abi) => abi.contains('x86_64'))) {
        return 'x86_64';
      }

      // Check 32-bit ARM (armeabi-v7a / armeabi)
      if (supportedAbis.any((abi) => abi.contains('armeabi') || abi.contains('armv7') || abi.contains('armv8l'))) {
        return 'arm32';
      }

      // Check 32-bit x86
      if (supportedAbis.any((abi) => abi.contains('x86'))) {
        return 'x86';
      }
    } catch (e) {
      debugPrint('[AppUpdateService] DeviceInfoPlugin architecture query failed: $e');
    }

    // Fallback to dart:ffi Abi.current()
    try {
      final currentAbi = Abi.current();
      if (currentAbi == Abi.androidArm64) return 'arm64';
      if (currentAbi == Abi.androidArm) return 'arm32';
      if (currentAbi == Abi.androidX64) return 'x86_64';
      if (currentAbi == Abi.androidIA32) return 'x86';
    } catch (_) {}

    return null;
  }

  /// Checks GitHub repository for the latest release tag and compares with installed version.
  static Future<AppUpdateInfo?> checkForUpdate({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // 1. Get current installed app version
      String currentVersion = defaultFallbackVersion;
      String currentBuild = '0';

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        if (packageInfo.version.trim().isNotEmpty) {
          currentVersion = packageInfo.version.trim();
        }
        if (packageInfo.buildNumber.trim().isNotEmpty) {
          currentBuild = packageInfo.buildNumber.trim();
        }
      } catch (e) {
        debugPrint('[AppUpdateService] PackageInfo failed, using fallback $defaultFallbackVersion: $e');
      }

      // 2. Fetch latest release from GitHub Releases API
      final dio = Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'TIS_RMS_Client',
          },
        ),
      );

      final response = await dio.get<Map<String, dynamic>>(_repoReleasesUrl);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data!;
      final rawTagName = (data['tag_name'] as String? ?? '').trim();
      if (rawTagName.isEmpty) return null;

      final releaseTitle = (data['name'] as String? ?? rawTagName).trim();
      final releaseNotes = (data['body'] as String? ?? '').trim();
      final htmlUrl = (data['html_url'] as String? ?? 'https://github.com/ssbg04/TIS_RMS/releases').trim();
      DateTime? publishedAt;
      if (data['published_at'] != null) {
        publishedAt = DateTime.tryParse(data['published_at'].toString());
      }

      // 3. Resolve platform- and architecture-specific download asset
      String? downloadUrl;
      String? assetName;
      String? detectedArch;

      final assets = data['assets'] as List<dynamic>? ?? [];
      final isWindows = !kIsWeb && Platform.isWindows;
      final isAndroid = !kIsWeb && Platform.isAndroid;

      if (isWindows) {
        detectedArch = 'x64';
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final browserUrl = asset['browser_download_url'] as String?;

            if (name.endsWith('.exe')) {
              downloadUrl = browserUrl;
              assetName = asset['name'] as String?;
              break;
            }
          }
        }
      } else if (isAndroid) {
        detectedArch = await getAndroidArchitecture();
        debugPrint('[AppUpdateService] Detected Android architecture: $detectedArch');

        final apkAssets = <Map<String, dynamic>>[];
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkAssets.add(asset);
            }
          }
        }

        Map<String, dynamic>? selectedAsset;

        if (detectedArch == 'arm64') {
          // Look for 64-bit APK (e.g. TIS_RMS_64_*.apk, app-arm64-v8a-release.apk)
          selectedAsset = apkAssets.firstWhere(
            (a) {
              final n = (a['name'] as String? ?? '').toLowerCase();
              return n.contains('arm64') ||
                  n.contains('aarch64') ||
                  n.contains('tis_rms_64') ||
                  RegExp(r'(^|[^0-9])64([^0-9]|$)').hasMatch(n);
            },
            orElse: () => <String, dynamic>{},
          );
        } else if (detectedArch == 'arm32') {
          // Look for 32-bit APK (e.g. TIS_RMS_32bit_*.apk, app-armeabi-v7a-release.apk)
          selectedAsset = apkAssets.firstWhere(
            (a) {
              final n = (a['name'] as String? ?? '').toLowerCase();
              return n.contains('32bit') ||
                  n.contains('armeabi') ||
                  n.contains('v7a') ||
                  n.contains('armv7') ||
                  n.contains('tis_rms_32') ||
                  RegExp(r'(^|[^0-9])32([^0-9]|$)').hasMatch(n);
            },
            orElse: () => <String, dynamic>{},
          );
        } else if (detectedArch == 'x86_64') {
          selectedAsset = apkAssets.firstWhere(
            (a) {
              final n = (a['name'] as String? ?? '').toLowerCase();
              return n.contains('x86_64') || n.contains('x64');
            },
            orElse: () => <String, dynamic>{},
          );
        }

        // If no architecture-specific APK found, fallback to universal APK
        if (selectedAsset == null || selectedAsset.isEmpty) {
          selectedAsset = apkAssets.firstWhere(
            (a) {
              final n = (a['name'] as String? ?? '').toLowerCase();
              return n.contains('universal');
            },
            orElse: () => <String, dynamic>{},
          );
        }

        // If still not found, fallback to first available APK
        if (selectedAsset.isEmpty && apkAssets.isNotEmpty) {
          selectedAsset = apkAssets.first;
        }

        if (selectedAsset.isNotEmpty) {
          downloadUrl = selectedAsset['browser_download_url'] as String?;
          assetName = selectedAsset['name'] as String?;
        }
      }

      // Fallback download URL to html release page if no specific asset found
      downloadUrl ??= htmlUrl;

      // 4. Compare versions
      final hasUpdate = isRemoteNewer(
        remoteTag: rawTagName,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: rawTagName,
        hasUpdate: hasUpdate,
        releaseTitle: releaseTitle,
        releaseNotes: releaseNotes,
        htmlUrl: htmlUrl,
        downloadUrl: downloadUrl,
        assetName: assetName,
        architecture: detectedArch,
        publishedAt: publishedAt,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Update check failed: $e');
      return null;
    }
  }

  /// Determines whether [remoteTag] (e.g. "v1.0.23") is newer than [currentVersion] (e.g. "1.0.22").
  static bool isRemoteNewer({
    required String remoteTag,
    required String currentVersion,
    String currentBuild = '0',
  }) {
    final cleanRemote = remoteTag.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanCurrent = currentVersion.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final remoteParts = cleanRemote.split('+');
    final currentParts = cleanCurrent.split('+');

    final remoteSemVer = remoteParts[0].split('.');
    final currentSemVer = currentParts[0].split('.');

    for (int i = 0; i < 3; i++) {
      final rNum = i < remoteSemVer.length ? int.tryParse(remoteSemVer[i]) ?? 0 : 0;
      final cNum = i < currentSemVer.length ? int.tryParse(currentSemVer[i]) ?? 0 : 0;

      if (rNum > cNum) return true;
      if (rNum < cNum) return false;
    }

    // If semvers match, check build number if available
    final remoteBuildNum = remoteParts.length > 1 ? int.tryParse(remoteParts[1]) : null;
    final currentBuildNum = int.tryParse(currentBuild) ??
        (currentParts.length > 1 ? int.tryParse(currentParts[1]) : null);

    if (remoteBuildNum != null && currentBuildNum != null) {
      return remoteBuildNum > currentBuildNum;
    }

    return false;
  }
}
