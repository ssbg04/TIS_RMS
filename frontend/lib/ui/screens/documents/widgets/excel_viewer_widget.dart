import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sheetifye/sheetifye.dart';
import '../../../../core/constants/app_colors.dart';

class ExcelViewerWidget extends StatefulWidget {
  final File? localFile;
  final String? networkUrl;
  final String fileName;
  final bool isMobile;

  const ExcelViewerWidget({
    super.key,
    this.localFile,
    this.networkUrl,
    required this.fileName,
    required this.isMobile,
  });

  @override
  State<ExcelViewerWidget> createState() => _ExcelViewerWidgetState();
}

class _ExcelViewerWidgetState extends State<ExcelViewerWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _fileBytes;

  @override
  void initState() {
    super.initState();
    _loadSpreadsheet();
  }

  Future<void> _loadSpreadsheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List bytes;
      if (widget.localFile != null) {
        bytes = await widget.localFile!.readAsBytes();
      } else if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
        final token = await const FlutterSecureStorage().read(key: 'jwt_token');
        final dio = Dio();
        final response = await dio.get<List<int>>(
          widget.networkUrl!,
          options: Options(
            responseType: ResponseType.bytes,
            headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          ),
        );
        if (response.data == null) {
          throw Exception('Failed to download spreadsheet file.');
        }
        bytes = Uint8List.fromList(response.data!);
      } else {
        throw Exception('No file source provided.');
      }

      if (mounted) {
        setState(() {
          _fileBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load spreadsheet: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 12),
            Text(
              'Loading spreadsheet preview...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null || _fileBytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Preview Error',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unable to display spreadsheet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Sheetifye.memory(
      _fileBytes!,
      readOnly: true,
    );
  }
}
