import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/utils/download_service.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../providers/document_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import 'excel_viewer_widget.dart';

/// Shows a fullscreen rich preview dialog for any document type:
/// • Images (jpg/jpeg/png/gif/webp/bmp) → inline image with in-viewer zoom
/// • PDF                               → inline PDF viewer with in-viewer zoom
/// • Excel / CSV                       → inline grid viewer + "Open with" external app CTA
/// • DOCX / others                     → file info + "Open in Browser" CTA
void showDocumentPreview({
  required BuildContext context,
  DocumentModel? document,
  File? localFile,
  String? localFileName,
}) {
  assert(document != null || (localFile != null && localFileName != null));
  showDialog(
    context: context,
    useSafeArea: false,
    builder: (ctx) => _DocumentPreviewDialog(
      document: document,
      localFile: localFile,
      localFileName: localFileName,
    ),
  );
}

// ──────────────────────────────────────────────────────────────
// Internal dialog widget
// ──────────────────────────────────────────────────────────────
class _DocumentPreviewDialog extends ConsumerStatefulWidget {
  final DocumentModel? document;
  final File? localFile;
  final String? localFileName;

  const _DocumentPreviewDialog({
    this.document,
    this.localFile,
    this.localFileName,
  });

  @override
  ConsumerState<_DocumentPreviewDialog> createState() =>
      _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState
    extends ConsumerState<_DocumentPreviewDialog> {
  bool _imageError = false;
  String? _token;
  bool _isOpeningExternal = false;

  final PdfViewerController _pdfViewerController = PdfViewerController();
  final TransformationController _imageTransformationController =
      TransformationController();

  void _zoomImageIn() {
    final matrix = _imageTransformationController.value.clone();
    matrix.scaleByDouble(1.25, 1.25, 1.0, 1.0);
    _imageTransformationController.value = matrix;
  }

  void _zoomImageOut() {
    final matrix = _imageTransformationController.value.clone();
    matrix.scaleByDouble(1 / 1.25, 1 / 1.25, 1.0, 1.0);
    _imageTransformationController.value = matrix;
  }

  void _zoomPdfIn() {
    _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.5;
  }

  void _zoomPdfOut() {
    final newZoom = _pdfViewerController.zoomLevel - 0.5;
    _pdfViewerController.zoomLevel = newZoom < 1.0 ? 1.0 : newZoom;
  }

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _imageTransformationController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await const FlutterSecureStorage().read(key: 'jwt_token');
    if (mounted) {
      setState(() => _token = token);
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  String get _fileUrl {
    if (widget.document == null || _token == null) return '';
    return '${ApiConstants.baseUrl}/documents/${widget.document!.id}/view?token=$_token';
  }

  String get _fileName => widget.document?.fileName ?? widget.localFileName!;

  String get _ext => _fileName.toLowerCase().split('.').last;

  bool get _isImage =>
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(_ext);

  bool get _isPdf => _ext == 'pdf';

  bool get _isExcel =>
      const {'xls', 'xlsx', 'csv'}.contains(_ext);

  bool get _isOffice =>
      const {'doc', 'docx', 'ppt', 'pptx'}.contains(_ext);

  Color get _typeColor {
    if (_isPdf) return Colors.redAccent;
    if (_isImage) return Colors.blueAccent;
    if (const {'xls', 'xlsx', 'csv'}.contains(_ext)) return Colors.green.shade700;
    if (const {'doc', 'docx'}.contains(_ext)) return Colors.blue.shade700;
    if (const {'ppt', 'pptx'}.contains(_ext)) return Colors.orange;
    return AppColors.primaryGreen;
  }

  IconData get _typeIcon {
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    if (_isImage) return Icons.image_rounded;
    if (const {'xls', 'xlsx', 'csv'}.contains(_ext)) return Icons.table_chart_rounded;
    if (const {'doc', 'docx'}.contains(_ext)) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String get _typeLabel {
    if (_isPdf) return 'PDF Document';
    if (_isImage) return 'Image File';
    if (const {'xls', 'xlsx', 'csv'}.contains(_ext)) return 'Excel Spreadsheet';
    if (const {'doc', 'docx'}.contains(_ext)) return 'Word Document';
    if (const {'ppt', 'pptx'}.contains(_ext)) return 'PowerPoint';
    return 'Document';
  }

  String get _downloadUrl {
    if (widget.document == null || _token == null) return '';
    return '${ApiConstants.baseUrl}/documents/${widget.document!.id}/view?token=$_token&download=true';
  }

  Future<void> _downloadFile() async {
    try {
      await DownloadService.downloadFile(
        url: _downloadUrl,
        fileName: _fileName,
      );
      if (!mounted) return;
      showSuccessDialog(context, message: 'Document downloaded successfully.');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Download Failed', e.toString());
    }
  }

  Future<void> _addToPrintList() async {
    if (widget.document == null) return;
    try {
      await ref
          .read(printQueueMutationProvider.notifier)
          .addToQueue(widget.document!.id);
      if (!mounted) return;
      showSuccessDialog(context, message: 'Added to Print List.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showErrorDialog(context, 'Failed to Add', msg);
    }
  }

  Future<void> _openExternalExcel() async {
    if (_isOpeningExternal) return;
    setState(() => _isOpeningExternal = true);
    try {
      if (widget.localFile != null) {
        final path = widget.localFile!.path;
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '""', path], runInShell: true);
        } else {
          final uri = Uri.file(path);
          if (!await launchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        return;
      }

      if (_token == null || widget.document == null) return;

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}${Platform.pathSeparator}$_fileName';
      final file = File(tempFilePath);
      
      if (!await file.exists()) {
        final dio = Dio();
        await dio.download(_downloadUrl, tempFilePath);
      }

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', tempFilePath], runInShell: true);
      } else {
        final uri = Uri.file(tempFilePath);
        if (!await launchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Launch Failed', 'Could not open external viewer: $e');
      }
    } finally {
      if (mounted) setState(() => _isOpeningExternal = false);
    }
  }

  Future<void> _openInGoogleDocs() async {
    final encodedUrl = Uri.encodeComponent(_fileUrl);
    final gdocUrl =
        'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';
    final uri = Uri.parse(gdocUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Launch Failed',
        'Could not open Google Docs viewer.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.document != null && _token == null) {
      return const Dialog.fullscreen(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.pageBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Icon(_typeIcon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (_isExcel)
              IconButton(
                icon: _isOpeningExternal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.open_in_new, color: Colors.white),
                tooltip: 'Open in External Viewer',
                onPressed: _isOpeningExternal ? null : _openExternalExcel,
              ),
            if (widget.document != null)
              IconButton(
                icon: const Icon(Icons.print_outlined, color: Colors.white),
                tooltip: 'Add to Print List',
                onPressed: _addToPrintList,
              ),
            if (widget.document != null)
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                tooltip: 'Download File',
                onPressed: _downloadFile,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _buildContent(isMobile),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    Widget content;
    if (_isImage) {
      content = _buildImagePreview();
    } else if (_isPdf) {
      content = _buildPdfInfo(isMobile);
    } else if (_isExcel) {
      content = _buildExcelViewer(isMobile);
    } else if (_isOffice) {
      content = _buildOfficeInfo(isMobile);
    } else {
      content = _buildGenericInfo(isMobile);
    }

    return content;
  }

  // ── Floating Zoom Overlay Controls ────────────────────────
  Widget _buildZoomControls({
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    VoidCallback? onReset,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
            onPressed: onZoomOut,
            tooltip: 'Zoom Out',
            splashRadius: 18,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          if (onReset != null)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: Colors.white, size: 18),
              onPressed: onReset,
              tooltip: 'Reset Zoom',
              splashRadius: 18,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
            onPressed: onZoomIn,
            tooltip: 'Zoom In',
            splashRadius: 18,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Excel viewer panel ────────────────────────────────────
  Widget _buildExcelViewer(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
      child: ExcelViewerWidget(
        localFile: widget.localFile,
        networkUrl: widget.localFile != null ? null : _fileUrl,
        fileName: _fileName,
        isMobile: isMobile,
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────
  Widget _buildImagePreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
      child: _imageError
          ? _buildImageError()
          : Stack(
              alignment: Alignment.center,
              children: [
                // Main image
                InteractiveViewer(
                  transformationController: _imageTransformationController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  constrained: true,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: widget.localFile != null
                          ? Image.file(widget.localFile!, fit: BoxFit.contain)
                          : Image.network(
                              _fileUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                            : null,
                                        color: AppColors.primaryGreen,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Loading image…',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) setState(() => _imageError = true);
                                });
                                return _buildImageError();
                              },
                            ),
                    ),
                  ),
                ),
                // Floating Zoom Controls
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: _buildZoomControls(
                    onZoomIn: _zoomImageIn,
                    onZoomOut: _zoomImageOut,
                    onReset: () {
                      _imageTransformationController.value = Matrix4.identity();
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImageError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load image',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _downloadFile,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download File'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ── PDF info panel ────────────────────────────────────────
  Widget _buildPdfInfo(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
      child: Stack(
        children: [
          widget.localFile != null
              ? SfPdfViewer.file(
                  widget.localFile!,
                  controller: _pdfViewerController,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  interactionMode: PdfInteractionMode.pan,
                )
              : SfPdfViewer.network(
                  _fileUrl,
                  controller: _pdfViewerController,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  interactionMode: PdfInteractionMode.pan,
                ),
          // Floating Zoom Controls
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildZoomControls(
              onZoomIn: _zoomPdfIn,
              onZoomOut: _zoomPdfOut,
              onReset: () {
                _pdfViewerController.zoomLevel = 1.0;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Office doc info panel ─────────────────────────────────
  Widget _buildOfficeInfo(bool isMobile) {
    return _buildDocInfoPanel(
      icon: _typeIcon,
      iconColor: _typeColor,
      title: _typeLabel,
      subtitle: _fileName,
      detail: widget.document?.size ?? 'Size unknown',
      actions: [
        _actionButton(
          icon: Icons.download_rounded,
          label: 'DOWNLOAD',
          color: _typeColor,
          onTap: _downloadFile,
        ),
        _actionButton(
          icon: Icons.view_in_ar_rounded,
          label: 'VIEWER',
          color: AppColors.primaryGreen,
          onTap: _openInGoogleDocs,
        ),
      ],
    );
  }

  // ── Generic info panel ────────────────────────────────────
  Widget _buildGenericInfo(bool isMobile) {
    return _buildDocInfoPanel(
      icon: Icons.insert_drive_file_rounded,
      iconColor: AppColors.primaryGreen,
      title: 'Document File',
      subtitle: _fileName,
      detail: widget.document?.size ?? 'Size unknown',
      actions: [
        _actionButton(
          icon: Icons.download_rounded,
          label: 'DOWNLOAD',
          color: AppColors.primaryGreen,
          onTap: _downloadFile,
        ),
      ],
    );
  }

  Widget _buildDocInfoPanel({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String detail,
    required List<Widget> actions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Big icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, size: 52, color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (detail.isNotEmpty && detail != 'Size unknown') ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This file type cannot be previewed inline. '
                        'Use the buttons below to view or download it.',
                        style: TextStyle(
                          color: isDark ? Colors.blue.shade300 : Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
