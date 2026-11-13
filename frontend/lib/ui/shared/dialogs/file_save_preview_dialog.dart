import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../widgets/app_button_loader.dart';
import '../widgets/pdf_excel_preview_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE TYPE
// ─────────────────────────────────────────────────────────────────────────────

enum SaveFileType { excel, pdf, image, word, other }

extension SaveFileTypeExt on SaveFileType {
  String get label => switch (this) {
    SaveFileType.excel => 'Excel Spreadsheet',
    SaveFileType.pdf => 'PDF Document',
    SaveFileType.image => 'Image File',
    SaveFileType.word => 'Word Document',
    SaveFileType.other => 'File',
  };

  IconData get icon => switch (this) {
    SaveFileType.excel => Icons.table_chart_outlined,
    SaveFileType.pdf => Icons.picture_as_pdf_outlined,
    SaveFileType.image => Icons.image_outlined,
    SaveFileType.word => Icons.description_outlined,
    SaveFileType.other => Icons.insert_drive_file_outlined,
  };

  Color get color => switch (this) {
    SaveFileType.excel => const Color(0xFF1D6F42),
    SaveFileType.pdf => const Color(0xFFD32F2F),
    SaveFileType.image => const Color(0xFF1565C0),
    SaveFileType.word => const Color(0xFF1976D2),
    SaveFileType.other => AppColors.textSecondary,
  };

  static SaveFileType fromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'xlsx' || 'xls' || 'csv' => SaveFileType.excel,
      'pdf' => SaveFileType.pdf,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'gif' ||
      'bmp' => SaveFileType.image,
      'doc' || 'docx' => SaveFileType.word,
      _ => SaveFileType.other,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// A compact label+value shown as a breadcrumb chip.
class FilePreviewRow {
  final String label;
  final String value;
  const FilePreviewRow(this.label, this.value);
}

/// Table data rendered as a mini spreadsheet in the preview (for Excel/CSV).
class SheetPreviewData {
  /// Name of the sheet.
  final String sheetName;

  /// Column header labels.
  final List<String> headers;

  /// Data rows — each row is a list of cell strings aligned to [headers].
  final List<List<String>> rows;

  /// Max rows to show in preview (default 100).
  final int maxPreviewRows;

  const SheetPreviewData({
    required this.sheetName,
    required this.headers,
    required this.rows,
    this.maxPreviewRows = 100,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a "preview before save" dialog with a live document/image preview.
///
/// - [fileName]       – Suggested file name (editable by user).
/// - [fileType]       – Auto-detected from extension if omitted.
/// - [fileBytes]      – Used for size breadcrumb.
/// - [previewRows]    – Compact breadcrumb chips (label: value).
/// - [sheets]         – List of sheet previews for Excel/CSV files.
/// - [imageFile]      – Image file for visual preview.
/// - [onSave]         – Async callback receiving the resolved file name.
///                      Throw to surface errors inside the dialog.
Future<bool?> showFileSavePreviewDialog(
  BuildContext context, {
  required String fileName,
  SaveFileType? fileType,
  List<int>? fileBytes,
  List<FilePreviewRow> previewRows = const [],
  List<SheetPreviewData> sheets = const [],
  File? imageFile,
  required Future<void> Function(String resolvedFileName) onSave,
}) {
  if (!context.mounted) return Future.value(null);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FileSavePreviewDialog(
      initialFileName: fileName,
      fileType: fileType ?? SaveFileTypeExt.fromExtension(fileName),
      fileBytes: fileBytes,
      previewRows: previewRows,
      sheets: sheets,
      imageFile: imageFile,
      onSave: onSave,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _FileSavePreviewDialog extends StatefulWidget {
  final String initialFileName;
  final SaveFileType fileType;
  final List<int>? fileBytes;
  final List<FilePreviewRow> previewRows;
  final List<SheetPreviewData> sheets;
  final File? imageFile;
  final Future<void> Function(String) onSave;

  const _FileSavePreviewDialog({
    required this.initialFileName,
    required this.fileType,
    required this.fileBytes,
    required this.previewRows,
    required this.sheets,
    required this.imageFile,
    required this.onSave,
  });

  @override
  State<_FileSavePreviewDialog> createState() => _FileSavePreviewDialogState();
}

class _FileSavePreviewDialogState extends State<_FileSavePreviewDialog> {
  late TextEditingController _fileNameCtrl;
  bool _isSaving = false;
  String? _error;
  Future<Uint8List>? _excelPdfFuture;
  List<FilePreviewRow> _excelStatsRows = const [];

  @override
  void initState() {
    super.initState();
    _fileNameCtrl = TextEditingController(text: widget.initialFileName);
    if (widget.fileType == SaveFileType.excel) {
      _excelPdfFuture = _buildExcelPdfBytes();
    }
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    super.dispose();
  }

  String get _sizeLabel {
    final b = widget.fileBytes;
    if (b == null || b.isEmpty) return '—';
    final kb = b.length / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(1)} KB'
        : '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  Future<Uint8List> _buildExcelPdfBytes() async {
    final fallback = widget.sheets
        .map(
          (s) => (
            name: s.sheetName,
            rows: <List<String>>[
              if (s.headers.isNotEmpty) s.headers,
              ...s.rows,
            ],
          ),
        )
        .toList();

    final result = await buildPdfFromSpreadsheetBytes(
      widget.fileBytes,
      fallbackSheets: fallback,
    );

    if (mounted) {
      setState(() {
        _excelStatsRows = [
          FilePreviewRow('Sheets', '${result.sheetCount}'),
          if (result.totalRows > 0)
            FilePreviewRow('Total Rows', '${result.totalRows}'),
        ];
      });
    }

    return result.pdfBytes;
  }

  void _showPropertiesDialog(Color accent, bool isDark) {
    final allRows = [
      FilePreviewRow('File Name', _fileNameCtrl.text.trim().isEmpty ? widget.initialFileName : _fileNameCtrl.text.trim()),
      FilePreviewRow('Format', widget.fileType.label),
      FilePreviewRow('File Size', _sizeLabel),
      ...widget.previewRows,
      ..._excelStatsRows,
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: accent, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Document Properties',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: allRows.map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _fileNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'File name cannot be empty.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(name);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ki = MediaQuery.viewInsetsOf(context);
    final sh = MediaQuery.sizeOf(context).height;
    final maxH = (sh * 0.92 - ki.bottom).clamp(400.0, double.infinity);
    final accent = widget.fileType.color;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 660, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopBar(accent, isDark),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            Flexible(child: _buildPreviewArea(accent, isDark)),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            _buildBottom(accent, isDark),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.05),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Icon(widget.fileType.icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.fileType.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _sizeLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Document Properties',
            icon: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            onPressed: () => _showPropertiesDialog(accent, isDark),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Close',
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  // ── PREVIEW AREA ──────────────────────────────────────────────────────────

  Widget _buildPreviewArea(Color accent, bool isDark) {
    return switch (widget.fileType) {
      SaveFileType.image => _buildImagePreview(isDark),
      SaveFileType.excel => _buildExcelPdfPreview(accent, isDark),
      SaveFileType.pdf => widget.fileBytes != null && widget.fileBytes!.isNotEmpty
          ? _buildPdfPreview(isDark)
          : _buildPlaceholderPreview(
              accent,
              Icons.picture_as_pdf_outlined,
              'PDF Preview',
              'No PDF bytes available for preview.\nThe file will open after saving.',
              isDark,
            ),
      SaveFileType.word => _buildPlaceholderPreview(
        accent,
        Icons.description_outlined,
        'Word Document',
        'Word preview not available in-app.\nThe document will open correctly after saving.',
        isDark,
      ),
      _ => _buildPlaceholderPreview(
        accent,
        Icons.insert_drive_file_outlined,
        'File Preview',
        'No preview available for this file type.',
        isDark,
      ),
    };
  }

  /// Interactive live PDF preview (works on Android & Windows, light/dark themed).
  Widget _buildPdfPreview(bool isDark) {
    final bytes = Uint8List.fromList(widget.fileBytes!);
    return MinimalPdfPreviewView(
      buildPdf: (_) async => bytes,
      isDark: isDark,
    );
  }

  /// Excel preview rendered via spreadsheet_decoder + pdf + PdfPreview (no Flutter tables).
  Widget _buildExcelPdfPreview(Color accent, bool isDark) {
    final future = _excelPdfFuture;
    if (future == null) {
      return _buildPlaceholderPreview(
        accent,
        Icons.table_chart_outlined,
        'Excel Spreadsheet',
        'No spreadsheet data provided for preview.',
        isDark,
      );
    }

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: isDark ? AppColors.darkPageBackground : const Color(0xFFF3F4F6),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildPlaceholderPreview(
            accent,
            Icons.table_chart_outlined,
            'Excel Spreadsheet',
            'Preview unavailable. You can still save the Excel file.',
            isDark,
          );
        }
        final pdfBytes = snapshot.data!;
        return MinimalPdfPreviewView(
          buildPdf: (_) async => pdfBytes,
          isDark: isDark,
        );
      },
    );
  }

  /// Full-size image preview.
  Widget _buildImagePreview(bool isDark) {
    if (widget.imageFile == null) {
      return _buildPlaceholderPreview(
        widget.fileType.color,
        Icons.image_not_supported_outlined,
        'No Image',
        'No image file was provided.',
        isDark,
      );
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        widget.imageFile!,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildPlaceholderPreview(
          widget.fileType.color,
          Icons.broken_image_outlined,
          'Preview Failed',
          'Could not load image.',
          isDark,
        ),
      ),
    );
  }

  /// Fallback placeholder for PDF, Word, and unknown types.
  Widget _buildPlaceholderPreview(
    Color accent,
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.p20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: accent),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM: filename + actions ─────────────────────────────────────────────

  Widget _buildBottom(Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File name field
          TextField(
            controller: _fileNameCtrl,
            enabled: !_isSaving,
            textInputAction: TextInputAction.done,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'File Name',
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              filled: isDark,
              fillColor: isDark ? AppColors.darkSurface2 : null,
              prefixIcon: Icon(widget.fileType.icon, color: accent, size: 17),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            _buildErrorBanner(_error!),
          ],

          const SizedBox(height: 10),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textSecondary,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                    backgroundColor: isDark ? AppColors.darkSurface2 : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const AppButtonLoader(
                          size: 15,
                          color: Colors.white,
                        )
                      : const Icon(Icons.save_alt_outlined, size: 17),
                  label: Text(
                    _isSaving ? 'Saving…' : 'SAVE FILE',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical: AppSizes.p8,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSizes.p8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
