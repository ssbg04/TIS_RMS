import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../widgets/app_button_loader.dart';

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

  @override
  void initState() {
    super.initState();
    _fileNameCtrl = TextEditingController(text: widget.initialFileName);
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopBar(accent, isDark),
            _buildBreadcrumbs(accent, isDark),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            // Preview — fills available space
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.p12,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.fileType.icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Text(
              'Preview — ${widget.fileType.label}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 20,
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

  // ── BREADCRUMBS ───────────────────────────────────────────────────────────

  Widget _buildBreadcrumbs(Color accent, bool isDark) {
    // Build all chips: user-supplied rows + auto size
    final allRows = [...widget.previewRows, FilePreviewRow('Size', _sizeLabel)];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
      color: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allRows.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right,
            size: 14,
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ),
        itemBuilder: (_, i) {
          final row = allRows[i];
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: isDark ? 0.32 : 0.18)),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${row.label}: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: row.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── PREVIEW AREA ──────────────────────────────────────────────────────────

  Widget _buildPreviewArea(Color accent, bool isDark) {
    return switch (widget.fileType) {
      SaveFileType.image => _buildImagePreview(isDark),
      SaveFileType.excel => _buildExcelPreview(accent, isDark),
      SaveFileType.pdf => widget.fileBytes != null && widget.fileBytes!.isNotEmpty
          ? _buildPdfPreview(isDark)
          : _buildPlaceholderPreview(
              accent,
              Icons.picture_as_pdf_outlined,
              'PDF Preview',
              'PDF rendering requires an external viewer.\nThe file will open correctly after saving.',
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

  /// Interactive live PDF preview.
  Widget _buildPdfPreview(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFF525659),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: SfPdfViewer.memory(
          Uint8List.fromList(widget.fileBytes!),
          canShowScrollHead: true,
          canShowScrollStatus: true,
        ),
      ),
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

  /// Mini spreadsheet rendered from [SheetPreviewData].
  Widget _buildExcelPreview(Color accent, bool isDark) {
    final sheets = widget.sheets;
    if (sheets.isEmpty) {
      return _buildPlaceholderPreview(
        accent,
        Icons.table_chart_outlined,
        'Excel Spreadsheet',
        'No table data provided for preview.',
        isDark,
      );
    }

    if (sheets.length == 1) {
      return _buildSheet(sheets.first, accent, isDark);
    }

    return DefaultTabController(
      length: sheets.length,
      child: Column(
        children: [
          Container(
            color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: accent,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              indicatorColor: accent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: sheets.map((s) => Tab(text: s.sheetName)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: sheets.map((s) => _buildSheet(s, accent, isDark)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(SheetPreviewData tp, Color accent, bool isDark) {
    if (tp.headers.isEmpty) {
      return _buildPlaceholderPreview(
        accent,
        Icons.table_chart_outlined,
        'Empty Sheet',
        'No data provided for this sheet.',
        isDark,
      );
    }

    final visibleRows = tp.rows.take(tp.maxPreviewRows).toList();
    final hasMore = tp.rows.length > tp.maxPreviewRows;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spreadsheet chrome label
          Row(
            children: [
              Icon(Icons.table_chart, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                'Sheet: ${tp.sheetName}  •  ${tp.rows.length} rows',
                style: TextStyle(
                  fontSize: 11,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p8),

          // Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                  verticalInside: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                    ),
                    children: tp.headers.asMap().entries.map((e) {
                      return _tableCell(
                        e.value.isEmpty ? '#' : e.value,
                        isHeader: true,
                        accent: accent,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                  // Data rows
                  ...visibleRows.asMap().entries.map((rowEntry) {
                    final isEven = rowEntry.key % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven
                            ? (isDark ? AppColors.darkSurfaceCard : Colors.white)
                            : (isDark ? AppColors.darkSurface2 : Colors.grey.shade50),
                      ),
                      children: rowEntry.value.map((cell) {
                        return _tableCell(cell, isDark: isDark);
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ),

          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.p8),
              child: Text(
                '+ ${tp.rows.length - tp.maxPreviewRows} more rows not shown in preview',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? accent, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? (accent ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
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
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p20,
        AppSizes.p12,
        AppSizes.p20,
        AppSizes.p16,
      ),
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
              fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'File Name',
              labelStyle: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              filled: isDark,
              fillColor: isDark ? AppColors.darkSurface2 : null,
              prefixIcon: Icon(widget.fileType.icon, color: accent, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSizes.p8),
            _buildErrorBanner(_error!),
          ],

          const SizedBox(height: AppSizes.p12),

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
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const AppButtonLoader(
                          size: 16,
                          color: Colors.white,
                        )
                      : const Icon(Icons.save_alt_outlined, size: 18),
                  label: Text(
                    _isSaving ? 'Saving…' : 'SAVE FILE',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
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
