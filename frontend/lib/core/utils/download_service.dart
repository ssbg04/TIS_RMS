import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class DownloadService {
  static final Dio _dio = Dio();

  static Future<String> getDownloadDirectoryPath() async {
    String? path;
    if (Platform.isAndroid) {
      path = '/storage/emulated/0/Download/TIS_RMS';
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

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return true;
    }
    return true;
  }

  /// Downloads a file and returns the local save path.
  static Future<String> downloadFile({
    required String url,
    required String fileName,
  }) async {
    await requestPermissions();

    final dirPath = await getDownloadDirectoryPath();
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

    await _dio.download(url, savePath);
    return savePath;
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
      } catch (_) {
        const fallback = AndroidIntent(
          action: 'android.intent.action.VIEW_DOWNLOADS',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await fallback.launch();
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
