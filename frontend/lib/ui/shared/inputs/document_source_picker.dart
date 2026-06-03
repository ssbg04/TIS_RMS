import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _pickFile() async {
    try {
      final allowed = widget.allowedExtensions ?? ['pdf', 'jpg', 'png', 'jpeg', 'doc', 'docx', 'xls', 'xlsx'];
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
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        final file = File(photo.path);
        final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
        // Send the data back to the parent screen
        widget.onFileSelected(file, photo.name, '$size MB');
      }
    } catch (e) {
      widget.onError?.call('Failed to access camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 300;
        final iconSize = narrow ? 44.0 : 56.0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.05),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 2),
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
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.document_scanner_outlined,
                  size: iconSize,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              const Text(
                'Select Document Source',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSizes.p4),
              Text(
                'Supports ${(widget.allowedExtensions ?? ['pdf', 'jpg', 'png', 'jpeg', 'doc', 'docx', 'xls', 'xlsx']).map((e) => e.toUpperCase()).join(', ')} (Max 10MB)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                    ),

                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMobile ? Colors.white : AppColors.primaryGreen,
                      foregroundColor: isMobile ? AppColors.primaryGreen : Colors.white,
                      side: isMobile ? const BorderSide(color: AppColors.primaryGreen) : BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}