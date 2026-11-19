import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_icon_helper.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../providers/document_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';

/// Computes the canonical renamed filename based on [document]'s document type
/// (matching the initial upload naming rule in [UploadOcrModal]).
String computeNormalizedVersionFileName(
  DocumentModel document,
  String pickedFileName,
) {
  final ext = pickedFileName.contains('.')
      ? pickedFileName.split('.').last.trim()
      : '';
  final docType = (document.documentType ?? '').trim();
  final baseName = docType.isNotEmpty
      ? docType
      : document.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
  if (baseName.isEmpty) return pickedFileName;
  return ext.isNotEmpty ? '$baseName.$ext' : baseName;
}

class UploadVersionModal extends ConsumerStatefulWidget {
  final DocumentModel document;

  const UploadVersionModal({super.key, required this.document});

  static Future<bool?> show(
    BuildContext context, {
    required DocumentModel document,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: MediaQuery.of(context).size.height < 600 ? 16 : 32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: UploadVersionModal(document: document),
        ),
      ),
    );
  }

  @override
  ConsumerState<UploadVersionModal> createState() => _UploadVersionModalState();
}

class _UploadVersionModalState extends ConsumerState<UploadVersionModal> {
  final _notesController = TextEditingController();
  final _docRepo = DocumentRepository();

  File? _pickedFile;
  String? _pickedFileName;
  String? _pickedFileSize;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickFile() async {
    if (_isUploading) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'xls',
        'xlsx',
        'doc',
        'docx',
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final pf = result.files.single;
    final file = File(pf.path!);
    final byteCount = pf.size > 0 ? pf.size : (await file.length());
    if (!mounted) return;
    setState(() {
      _pickedFile = file;
      _pickedFileName = pf.name;
      _pickedFileSize = _formatSize(byteCount);
    });
  }

  Future<void> _submitUpload() async {
    if (_pickedFile == null || _pickedFileName == null || _isUploading) return;

    final renamedFileName = computeNormalizedVersionFileName(
      widget.document,
      _pickedFileName!,
    );

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final nextVersion = await _docRepo.uploadDocumentVersion(
        widget.document.id,
        _pickedFile!.path,
        customFileName: renamedFileName,
        studentId: widget.document.studentId,
        documentType: widget.document.documentType,
        requirementId: widget.document.requirementId,
        notes: _notesController.text,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = (sent / total).clamp(0.0, 1.0));
        },
      );

      ref.invalidate(documentPageProvider);
      if (!mounted) return;
      final rootNavigator = Navigator.of(context);
      final rootContext = rootNavigator.context;
      rootNavigator.pop(true);
      if (rootContext.mounted) {
        showSuccessDialog(
          rootContext,
          message: 'Version $nextVersion uploaded successfully.',
          notes: 'Saved as "$renamedFileName".',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      showErrorDialog(
        context,
        'Upload Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final subtitle = (widget.document.documentType ?? '').trim().isNotEmpty
        ? widget.document.documentType!.trim()
        : widget.document.fileName;

    final renamedPreview = _pickedFileName != null
        ? computeNormalizedVersionFileName(widget.document, _pickedFileName!)
        : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isUploading) Navigator.of(context).pop(false);
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: AppColors.darkBorder) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload New Version',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                      tooltip: 'Close (Esc)',
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current file banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface2
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FileIconHelper.getIcon(widget.document.fileName),
                              size: 18,
                              color: FileIconHelper.getColor(
                                widget.document.fileName,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current file',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    widget.document.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // File picker drop/tap zone
                      if (_pickedFile == null)
                        InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 26,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: isDark ? 0.08 : 0.04,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.45,
                                ),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 36,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Click to choose replacement file',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF, JPG, PNG, DOC/DOCX, XLS/XLSX (max 10 MB)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: isDark ? 0.12 : 0.06,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    FileIconHelper.getIcon(_pickedFileName!),
                                    color: FileIconHelper.getColor(
                                      _pickedFileName!,
                                    ),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _pickedFileName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        if (_pickedFileSize != null)
                                          Text(
                                            _pickedFileSize!,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isUploading ? null : _pickFile,
                                    child: const Text('Change'),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    color: textSecondary,
                                    tooltip: 'Remove file',
                                    onPressed: _isUploading
                                        ? null
                                        : () => setState(() {
                                            _pickedFile = null;
                                            _pickedFileName = null;
                                            _pickedFileSize = null;
                                          }),
                                  ),
                                ],
                              ),
                              if (renamedPreview != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceCard
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.drive_file_rename_outline_rounded,
                                        size: 15,
                                        color: AppColors.primaryGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Will be saved as: $renamedPreview',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF76BA8A)
                                                : AppColors.primaryGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),
                      Text(
                        'Version Notes (Optional)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        enabled: !_isUploading,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13.5, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Optional notes about this revision...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: textSecondary.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurface2
                              : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),

                      if (_isUploading) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            minHeight: 6,
                            color: AppColors.primaryGreen,
                            backgroundColor: AppColors.primaryGreen.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Uploading new version... ${(_uploadProgress * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: (_pickedFile == null || _isUploading)
                          ? null
                          : _submitUpload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Version'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
