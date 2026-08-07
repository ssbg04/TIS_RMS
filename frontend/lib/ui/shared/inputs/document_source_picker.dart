import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class DocumentSourcePicker extends StatefulWidget {
  // Callbacks to pass data back to whatever screen is using this widget
  final Function(File file, String fileName, String fileSize) onFileSelected;
  final Function(String error)? onError;
  final List<String>? allowedExtensions;

  const DocumentSourcePicker({
    super.key,
    required this.onFileSelected,
    this.onError,
    this.allowedExtensions,
  });

  @override
  State<DocumentSourcePicker> createState() => _DocumentSourcePickerState();
}

class _DocumentSourcePickerState extends State<DocumentSourcePicker> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isDragOver = false;

  Future<void> _pickFile() async {
    try {
      final allowed =
          widget.allowedExtensions ??
          ['pdf', 'jpg', 'png', 'jpeg', 'doc', 'docx', 'xls', 'xlsx', 'csv'];
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
        // Send the data back to the parent screen
        widget.onFileSelected(file, result.files.single.name, '$size MB');
      }
    } catch (e) {
      widget.onError?.call('Failed to pick file: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.jpeg},
          mode: ScannerMode.full, // Allows edge detection, cropping, filters
          isGalleryImport:
              false, // Prevents importing from gallery since we have a separate button for that
          pageLimit: 1, // Only one document per upload field
        ),
      );

      final result = await scanner.scanDocument();
      scanner.close();

      if (result != null) {
        final images = result.images;
        if (images != null && images.isNotEmpty) {
          final file = File(images.first);
          final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
          final name =
              'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.jpg';

          widget.onFileSelected(file, name, '$size MB');
        }
      }
    } catch (e) {
      widget.onError?.call('Failed to scan document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final allowed =
        widget.allowedExtensions ??
        ['pdf', 'jpg', 'png', 'jpeg', 'doc', 'docx', 'xls', 'xlsx', 'csv'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final narrow = constraints.maxWidth < 300;
        final iconSize = narrow ? 44.0 : 56.0;

        Widget content = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isDragOver
                ? AppColors.primaryGreen.withValues(alpha: 0.15)
                : AppColors.primaryGreen.withValues(alpha: 0.05),
            border: Border.all(
              color: _isDragOver
                  ? AppColors.primaryGreen
                  : AppColors.primaryGreen.withValues(alpha: 0.3),
              width: _isDragOver ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: narrow ? AppSizes.p16 : AppSizes.p24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.p12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isDragOver
                      ? Icons.file_download_outlined
                      : Icons.document_scanner_outlined,
                  size: iconSize,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              Text(
                _isDragOver
                    ? 'Drop File Here'
                    : (isWindows
                        ? 'Select Document or Drag & Drop'
                        : 'Select Document Source'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p4),
              Text(
                'Supports ${allowed.map((e) => e.toUpperCase()).join(', ')} (Max 10MB)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSizes.p16),

              // Wrap instead of Row — stacks buttons on narrow screens
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSizes.p12,
                runSpacing: AppSizes.p8,
                children: [
                  if (isMobile)
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Use Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                    ),

                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMobile
                          ? (isDark
                              ? AppColors.darkSurface2
                              : Colors.white)
                          : AppColors.primaryGreen,
                      foregroundColor: isMobile
                          ? AppColors.primaryGreen
                          : Colors.white,
                      side: isMobile
                          ? const BorderSide(color: AppColors.primaryGreen)
                          : BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (isWindows) {
          content = DropTarget(
            onDragEntered: (details) => setState(() => _isDragOver = true),
            onDragExited: (details) => setState(() => _isDragOver = false),
            onDragDone: (details) {
              setState(() => _isDragOver = false);
              if (details.files.isNotEmpty) {
                final xfile = details.files.first;
                final ext = xfile.path.split('.').last.toLowerCase();
                if (allowed.contains(ext)) {
                  final file = File(xfile.path);
                  final size =
                      (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
                  widget.onFileSelected(file, xfile.name, '$size MB');
                } else {
                  widget.onError?.call(
                      'Unsupported file format: .$ext. Allowed: ${allowed.join(', ')}');
                }
              }
            },
            child: content,
          );
        }

        return content;
      },
    );
  }
}

