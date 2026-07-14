import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      }
    }
    
    if (path == null) {
      throw Exception('Could not determine download directory for this platform.');
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
}
