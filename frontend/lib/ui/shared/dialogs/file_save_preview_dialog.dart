import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE TYPE
// ─────────────────────────────────────────────────────────────────────────────

enum SaveFileType { excel, pdf, image, word, other }

extension SaveFileTypeExt on SaveFileType {
  String get label => switch (this) {
    SaveFileType.excel => 'Excel Spreadsheet',
    SaveFileType.pdf   => 'PDF Document',
    SaveFileType.image => 'Image File',
    SaveFileType.word  => 'Word Document',
    SaveFileType.other => 'File',
  };

  IconData get icon => switch (this) {
    SaveFileType.excel => Icons.table_chart_outlined,
    SaveFileType.pdf   => Icons.picture_as_pdf_outlined,
    SaveFileType.image => Icons.image_outlined,
    SaveFileType.word  => Icons.description_outlined,
    SaveFileType.other => Icons.insert_drive_file_outlined,
  };

  Color get color => switch (this) {
    SaveFileType.excel => const Color(0xFF1D6F42),
    SaveFileType.pdf   => const Color(0xFFD32F2F),
    SaveFileType.image => const Color(0xFF1565C0),
    SaveFileType.word  => const Color(0xFF1976D2),
    SaveFileType.other => AppColors.textSecondary,
  };

  static SaveFileType fromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'xlsx' || 'xls' || 'csv'                           => SaveFileType.excel,
      'pdf'                                               => SaveFileType.pdf,
      'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' || 'bmp' => SaveFileType.image,
      'doc' || 'docx'                                     => SaveFileType.word,
      _                                                   => SaveFileType.other,
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
  SaveFileType?   fileType,
  List<int>?      fileBytes,
  List<FilePreviewRow> previewRows = const [],
  List<SheetPreviewData> sheets = const [],
  File?           imageFile,
  required Future<void> Function(String resolvedFileName) onSave,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FileSavePreviewDialog(
      initialFileName: fileName,
      fileType:        fileType ?? SaveFileTypeExt.fromExtension(fileName),
      fileBytes:       fileBytes,
      previewRows:     previewRows,
      sheets:          sheets,
      imageFile:       imageFile,
      onSave:          onSave,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _FileSavePreviewDialog extends StatefulWidget {
  final String               initialFileName;
  final SaveFileType         fileType;
  final List<int>?           fileBytes;
  final List<FilePreviewRow> previewRows;
  final List<SheetPreviewData> sheets;
  final File?                imageFile;
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
  bool    _isSaving = false;
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
    setState(() { _isSaving = true; _error = null; });
    try {
      await widget.onSave(name);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _isSaving = false;
        _error    = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ki       = MediaQuery.viewInsetsOf(context);
    final sh       = MediaQuery.sizeOf(context).height;
    final maxH     = (sh * 0.92 - ki.bottom).clamp(400.0, double.infinity);
    final accent   = widget.fileType.color;

    return Dialog(
      insetPadding:    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopBar(accent),
            _buildBreadcrumbs(accent),
            const Divider(height: 1),
            // Preview — fills available space
            Flexible(child: _buildPreviewArea(accent)),
            const Divider(height: 1),
            _buildBottom(accent),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical:   AppSizes.p12,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:  accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.fileType.icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Text(
              'Preview — ${widget.fileType.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  // ── BREADCRUMBS ───────────────────────────────────────────────────────────

  Widget _buildBreadcrumbs(Color accent) {
    // Build all chips: user-supplied rows + auto size
    final allRows = [
      ...widget.previewRows,
      FilePreviewRow('Size', _sizeLabel),
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
      color: AppColors.pageBackground,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:  allRows.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
        ),
        itemBuilder: (_, i) {
          final row = allRows[i];
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${row.label}: ',
                      style: const TextStyle(
                        fontSize: 11,
                        color:    AppColors.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: row.value,
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.bold,
                        color:      accent,
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

  Widget _buildPreviewArea(Color accent) {
    return switch (widget.fileType) {
      SaveFileType.image => _buildImagePreview(),
      SaveFileType.excel => _buildExcelPreview(accent),
      SaveFileType.pdf   => _buildPlaceholderPreview(
          accent,
          Icons.picture_as_pdf_outlined,
          'PDF Preview',
          'PDF rendering requires an external viewer.\nThe file will open correctly after saving.',
        ),
      SaveFileType.word  => _buildPlaceholderPreview(
          accent,
          Icons.description_outlined,
          'Word Document',
          'Word preview not available in-app.\nThe document will open correctly after saving.',
        ),
      _                  => _buildPlaceholderPreview(
          accent,
          Icons.insert_drive_file_outlined,
          'File Preview',
          'No preview available for this file type.',
        ),
    };
  }

  /// Full-size image preview.
  Widget _buildImagePreview() {
    if (widget.imageFile == null) {
      return _buildPlaceholderPreview(
        widget.fileType.color,
        Icons.image_not_supported_outlined,
        'No Image',
        'No image file was provided.',
      );
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        widget.imageFile!,
        width:  double.infinity,
        fit:    BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholderPreview(
          widget.fileType.color,
          Icons.broken_image_outlined,
          'Preview Failed',
          'Could not load image.',
        ),
      ),
    );
  }

  /// Mini spreadsheet rendered from [SheetPreviewData].
  Widget _buildExcelPreview(Color accent) {
    final sheets = widget.sheets;
    if (sheets.isEmpty) {
      return _buildPlaceholderPreview(
        accent,
        Icons.table_chart_outlined,
        'Excel Spreadsheet',
        'No table data provided for preview.',
      );
    }

    if (sheets.length == 1) {
      return _buildSheet(sheets.first, accent);
    }

    return DefaultTabController(
      length: sheets.length,
      child: Column(
        children: [
          Container(
            color: accent.withValues(alpha: 0.05),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: accent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: sheets.map((s) => Tab(text: s.sheetName)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: sheets.map((s) => _buildSheet(s, accent)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(SheetPreviewData tp, Color accent) {
    if (tp.headers.isEmpty) {
      return _buildPlaceholderPreview(
        accent,
        Icons.table_chart_outlined,
        'Empty Sheet',
        'No data provided for this sheet.',
      );
    }

    final visibleRows = tp.rows.take(tp.maxPreviewRows).toList();
    final hasMore     = tp.rows.length > tp.maxPreviewRows;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spreadsheet chrome label
          Row(children: [
            Icon(Icons.table_chart, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(
              'Sheet: ${tp.sheetName}  •  ${tp.rows.length} rows',
              style: TextStyle(
                fontSize: 11,
                color:    accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: AppSizes.p8),

          // Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade200),
                  verticalInside:   BorderSide(color: Colors.grey.shade200),
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.10)),
                    children: tp.headers.asMap().entries.map((e) {
                      return _tableCell(
                        e.value.isEmpty ? '#' : e.value,
                        isHeader: true,
                        accent: accent,
                      );
                    }).toList(),
                  ),
                  // Data rows
                  ...visibleRows.asMap().entries.map((rowEntry) {
                    final isEven = rowEntry.key % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven ? Colors.white : Colors.grey.shade50,
                      ),
                      children: rowEntry.value.map((cell) {
                        return _tableCell(cell);
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
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? accent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize:   12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color:      isHeader ? (accent ?? AppColors.textPrimary) : AppColors.textPrimary,
        ),
      ),
    );
  }

  /// Fallback placeholder for PDF, Word, and unknown types.
  Widget _buildPlaceholderPreview(
    Color accent, IconData icon, String title, String subtitle,
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
                color:  accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: accent),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM: filename + actions ─────────────────────────────────────────────

  Widget _buildBottom(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p20, AppSizes.p12, AppSizes.p20, AppSizes.p16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File name field
          TextField(
            controller:      _fileNameCtrl,
            enabled:         !_isSaving,
            textInputAction: TextInputAction.done,
            scrollPadding:   const EdgeInsets.only(bottom: 120),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense:    true,
              labelText:  'File Name',
              prefixIcon: Icon(widget.fileType.icon, color: accent, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSizes.p8),
            _buildErrorBanner(_error!),
          ],

          const SizedBox(height: AppSizes.p12),

          // Buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt_outlined, size: 18),
                label: Text(_isSaving ? 'Saving…' : 'SAVE FILE',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: AppSizes.p8),
      decoration: BoxDecoration(
        color:        AppColors.error.withValues(alpha: 0.08),
        border:       Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      ]),
    );
  }
}
