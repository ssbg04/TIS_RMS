import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/modals/custom_modal.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/utils/download_service.dart';

/// Shows a rich preview dialog for any document type:
/// • Images (jpg/jpeg/png/gif/webp/bmp) → inline network image
/// • PDF / DOCX / XLSX / others        → file info + "Open in Browser" CTA
void showDocumentPreview({
  required BuildContext context,
  DocumentModel? document,
  File? localFile,
  String? localFileName,
}) {
  assert(document != null || (localFile != null && localFileName != null));
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
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
class _DocumentPreviewDialog extends StatefulWidget {
  final DocumentModel? document;
  final File? localFile;
  final String? localFileName;
  const _DocumentPreviewDialog({
    this.document,
    this.localFile,
    this.localFileName,
  });

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  bool _imageError = false;
  bool _imageLoaded = false;
  String? _token;

  final PdfViewerController _pdfViewerController = PdfViewerController();
  final TransformationController _imageTransformationController =
      TransformationController();

  void _zoomImageIn() {
    final matrix = _imageTransformationController.value.clone();
    matrix.scale(1.2, 1.2, 1.0);
    _imageTransformationController.value = matrix;
  }

  void _zoomImageOut() {
    final matrix = _imageTransformationController.value.clone();
    matrix.scale(1 / 1.2, 1 / 1.2, 1.0);
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
    if (widget.localFile != null) {
      _imageLoaded = true;
    }
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

  bool get _isOffice =>
      const {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'}.contains(_ext);

  Color get _typeColor {
    if (_isPdf) return Colors.redAccent;
    if (_isImage) return Colors.blueAccent;
    if (const {'xls', 'xlsx'}.contains(_ext)) return Colors.green.shade700;
    if (const {'doc', 'docx'}.contains(_ext)) return Colors.blue.shade700;
    if (const {'ppt', 'pptx'}.contains(_ext)) return Colors.orange;
    return AppColors.primaryGreen;
  }

  IconData get _typeIcon {
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    if (_isImage) return Icons.image_rounded;
    if (const {'xls', 'xlsx'}.contains(_ext)) return Icons.table_chart_rounded;
    if (const {'doc', 'docx'}.contains(_ext)) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String get _typeLabel {
    if (_isPdf) return 'PDF Document';
    if (_isImage) return 'Image File';
    if (const {'xls', 'xlsx'}.contains(_ext)) return 'Excel Spreadsheet';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download started...')));
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

    if (widget.document != null && _token == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomModal(
      title: _fileName,
      icon: _typeIcon,
      maxWidth: 800,
      headerActions: [
        if (_isImage || _isPdf) ...[
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isImage ? _zoomImageOut : _zoomPdfOut,
            tooltip: 'Zoom Out',
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isImage ? _zoomImageIn : _zoomPdfIn,
            tooltip: 'Zoom In',
          ),
          const SizedBox(width: 12),
        ],
      ],
      content: _buildContent(isMobile),
    );
  }

  Widget _buildContent(bool isMobile) {
    Widget content;
    if (_isImage) {
      content = _buildImagePreview();
    } else if (_isPdf) {
      content = _buildPdfInfo(isMobile);
    } else if (_isOffice) {
      content = _buildOfficeInfo(isMobile);
    } else {
      content = _buildGenericInfo(isMobile);
    }

    return content;
  }

  // ── Image preview ─────────────────────────────────────────
  Widget _buildImagePreview() {
    return Container(
      color: Colors.grey.shade100,
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.localFile != null
                        ? Image.file(widget.localFile!, fit: BoxFit.contain)
                        : Image.network(
                            _fileUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted)
                                    setState(() => _imageLoaded = true);
                                });
                                return child;
                              }
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
                                    const Text(
                                      'Loading image…',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _imageError = true);
                              });
                              return _buildImageError();
                            },
                          ),
                  ),
                ),
                // Pinch-to-zoom hint
                if (_imageLoaded)
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pinch or scroll to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildImageError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load image',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
    return Container(
      color: Colors.grey.shade100,
      child: widget.localFile != null
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
    return Container(
      color: AppColors.surfaceWhite,
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (detail.isNotEmpty && detail != 'Size unknown') ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This file type cannot be previewed inline. '
                        'Use the buttons below to view or download it.',
                        style: TextStyle(color: Colors.blue, fontSize: 13),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.month}/${date.day}/${date.year}';
  }
}
