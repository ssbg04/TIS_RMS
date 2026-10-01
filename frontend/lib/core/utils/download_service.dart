import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadService {
  static final Dio _dio = Dio();

  /// Requests appropriate storage permissions based on platform and Android API level.
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        // Android 11+ (API 30+): Manage External Storage for public directories
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 and below (API <= 29): standard storage permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    } catch (_) {
      return false;
    }
  }

  /// Gets the best available download directory path.
  /// On Android: tries public /Download/TIS_RMS if permitted, otherwise gracefully
  /// falls back to app-specific external downloads/documents directories that require no permissions.
  static Future<String> getDownloadDirectoryPath() async {
    String? path;
    if (Platform.isAndroid) {
      // 1. Try public Download folder if permissions are granted
      bool canUsePublic = false;
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        if (sdkInt >= 30) {
          canUsePublic = await Permission.manageExternalStorage.isGranted;
        } else {
          canUsePublic = await Permission.storage.isGranted;
        }
      } catch (_) {
        canUsePublic = false;
      }

      if (canUsePublic) {
        try {
          const publicPath = '/storage/emulated/0/Download/TIS_RMS';
          final dir = Directory(publicPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return publicPath;
        } catch (_) {
          // If public dir creation throws permission denied, continue to fallbacks below
        }
      }

      // 2. Fallback: app-specific external downloads directory (zero permissions needed)
      try {
        final externalDirs =
            await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final dir = Directory('${externalDirs.first.path}/TIS_RMS');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir.path;
        }
      } catch (_) {}

      // 3. Fallback: app external storage files directory
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final dir = Directory('${extDir.path}/TIS_RMS');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir.path;
        }
      } catch (_) {}

      // 4. Ultimate fallback: app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/TIS_RMS');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isWindows) {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        path = '${dir.path}\\TIS_RMS';
      } else {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          path = '$userProfile\\Downloads\\TIS_RMS';
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          path = '${docsDir.path}\\TIS_RMS';
        }
      }
    }

    if (path == null) {
      throw Exception(
        'Could not determine download directory for this platform.',
      );
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  /// Returns the platform-specific directory used for temporary documents.
  /// On Windows, returns a private app folder in AppData (not in %TEMP%),
  /// preventing Windows Storage Sense and Disk Cleanup from deleting cached files.
  static Future<Directory> getDocumentTempDirectory() async {
    if (Platform.isWindows) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final privateTemp = Directory('${supportDir.path}\\temp_documents');
        if (!await privateTemp.exists()) {
          await privateTemp.create(recursive: true);
        }
        return privateTemp;
      } catch (_) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          final privateTemp = Directory('$localAppData\\TIS_RMS\\temp_documents');
          if (!await privateTemp.exists()) {
            await privateTemp.create(recursive: true);
          }
          return privateTemp;
        }
      }
    }
    return getTemporaryDirectory();
  }

  /// Resolves an unused file name in [dirPath] by appending (1), (2), etc.
  static Future<String> _resolveUniqueFilePath(String dirPath, String fileName) async {
    final separator = Platform.isWindows ? '\\' : '/';
    String savePath = '$dirPath$separator$fileName';

    int counter = 1;
    while (await File(savePath).exists()) {
      final extensionIndex = fileName.lastIndexOf('.');
      if (extensionIndex != -1) {
        final name = fileName.substring(0, extensionIndex);
        final extension = fileName.substring(extensionIndex);
        savePath = '$dirPath$separator$name ($counter)$extension';
      } else {
        savePath = '$dirPath$separator$fileName ($counter)';
      }
      counter++;
    }
    return savePath;
  }

  /// Saves raw in-memory bytes (e.g., generated PDFs, Excel, CSV) safely to disk.
  /// On Android, automatically requests permissions and falls back to app-specific
  /// storage if permission to public Download is denied.
  static Future<String> saveBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    await requestPermissions();

    final dirPath = await getDownloadDirectoryPath();
    final savePath = await _resolveUniqueFilePath(dirPath, fileName);

    try {
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (Platform.isAndroid) {
        // Fallback directly to app-specific documents directory without failing
        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${docsDir.path}/TIS_RMS');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        final fallbackPath = await _resolveUniqueFilePath(fallbackDir.path, fileName);
        final fallbackFile = File(fallbackPath);
        await fallbackFile.writeAsBytes(bytes);
        return fallbackFile.path;
      }
      rethrow;
    }
  }

  /// Downloads a file from [url] and returns the local save path.
  static Future<String> downloadFile({
    required String url,
    required String fileName,
  }) async {
    await requestPermissions();

    final dirPath = await getDownloadDirectoryPath();
    final savePath = await _resolveUniqueFilePath(dirPath, fileName);

    try {
      await _dio.download(url, savePath);
      return savePath;
    } catch (e) {
      if (Platform.isAndroid) {
        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${docsDir.path}/TIS_RMS');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        final fallbackPath = await _resolveUniqueFilePath(fallbackDir.path, fileName);
        await _dio.download(url, fallbackPath);
        return fallbackPath;
      }
      rethrow;
    }
  }

  /// Opens the downloaded document file directly in the default system viewer.
  static Future<void> openDownloadedFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist at $filePath');
    }
    try {
      final res = await OpenFilex.open(filePath);
      if (res.type != ResultType.done && Platform.isWindows) {
        await Process.run('explorer.exe', [filePath]);
      }
    } catch (_) {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [filePath]);
      }
    }
  }

  /// Opens the storage directory (Download/TIS_RMS) or highlights the file in File Explorer.
  static Future<void> openStorageFolder([String? filePath]) async {
    if (Platform.isAndroid) {
      if (filePath != null && filePath.contains('/Download/TIS_RMS')) {
        const folderUri =
            'content://com.android.externalstorage.documents/document/primary:Download%2FTIS_RMS';
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: folderUri,
          type: 'vnd.android.document/directory',
          flags: [
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );
        try {
          await intent.launch();
          return;
        } catch (_) {}
      }

      // Try system downloads app
      try {
        const fallback = AndroidIntent(
          action: 'android.intent.action.VIEW_DOWNLOADS',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await fallback.launch();
        return;
      } catch (_) {}

      // Fallback: open the file directly if provided
      if (filePath != null) {
        try {
          await openDownloadedFile(filePath);
        } catch (_) {}
      }
    } else if (Platform.isWindows) {
      try {
        if (filePath != null && await File(filePath).exists()) {
          await Process.run('explorer.exe', ['/select,$filePath']);
        } else {
          final dirPath = await getDownloadDirectoryPath();
          await Process.run('explorer.exe', [dirPath]);
        }
      } catch (_) {}
    }
  }
}
