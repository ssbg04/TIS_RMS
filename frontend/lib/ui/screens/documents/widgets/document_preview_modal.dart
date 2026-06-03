import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../shared/dialogs/error_dialog.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Shows a rich preview dialog for any document type:
/// • Images (jpg/jpeg/png/gif/webp/bmp) → inline network image
/// • PDF / DOCX / XLSX / others        → file info + "Open in Browser" CTA
void showDocumentPreview(BuildContext context, DocumentModel document) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _DocumentPreviewDialog(document: document),
  );
}

// ──────────────────────────────────────────────────────────────
// Internal dialog widget
// ──────────────────────────────────────────────────────────────
class _DocumentPreviewDialog extends StatefulWidget {
  final DocumentModel document;
  const _DocumentPreviewDialog({required this.document});

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  bool _imageError = false;
  bool _imageLoaded = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await const FlutterSecureStorage().read(key: 'jwt_token');
    if (mounted) {
      setState(() => _token = token);
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  String get _fileUrl {
    if (_token == null) return '';
    return '${ApiConstants.baseUrl}/documents/${widget.document.id}/view?token=$_token';
  }

  String get _ext =>
      widget.document.fileName.toLowerCase().split('.').last;

  bool get _isImage => const {
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'
      }.contains(_ext);

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
    if (_token == null) return '';
    return '${ApiConstants.baseUrl}/documents/${widget.document.id}/view?token=$_token&download=true';
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      showErrorDialog(context, 'Launch Failed', 'Could not open file in browser.');
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
      showErrorDialog(context, 'Launch Failed', 'Could not open Google Docs viewer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;

    if (_token == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────
              _buildHeader(context),
              // ── Content ─────────────────────────────────────
              Flexible(child: _buildContent(isMobile)),
              // ── Footer ──────────────────────────────────────
              _buildFooter(),
            ],
          ),
        ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // File type icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          // File name + type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _typeLabel,
                  style: TextStyle(
                    color: _typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isImage) return _buildImagePreview();
    if (_isPdf) return _buildPdfInfo(isMobile);
    if (_isOffice) return _buildOfficeInfo(isMobile);
    return _buildGenericInfo(isMobile);
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
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.network(
                      _fileUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _imageLoaded = true);
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
                              const Text('Loading image…',
                                  style: TextStyle(
                                      color: AppColors.textSecondary, fontSize: 13)),
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
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Pinch or scroll to zoom',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
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
          const Icon(Icons.broken_image_rounded, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Could not load image',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Open in browser'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  // ── PDF info panel ────────────────────────────────────────
  Widget _buildPdfInfo(bool isMobile) {
    return Container(
      color: Colors.grey.shade100,
      child: SfPdfViewer.network(
        _fileUrl,
        canShowScrollHead: false,
        canShowScrollStatus: false,
      ),
    );
  }

  // ── Office doc info panel ─────────────────────────────────
  Widget _buildOfficeInfo(bool isMobile) {
    return _buildDocInfoPanel(
      icon: _typeIcon,
      iconColor: _typeColor,
      title: _typeLabel,
      subtitle: widget.document.fileName,
      detail: widget.document.size ?? 'Size unknown',
      actions: [
        _actionButton(
          icon: Icons.open_in_browser_rounded,
          label: 'Download & Open',
          color: _typeColor,
          onTap: _openInBrowser,
        ),
        _actionButton(
          icon: Icons.view_in_ar_rounded,
          label: 'Google Docs Viewer',
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
      subtitle: widget.document.fileName,
      detail: widget.document.size ?? 'Size unknown',
      actions: [
        _actionButton(
          icon: Icons.open_in_browser_rounded,
          label: 'Open File',
          color: AppColors.primaryGreen,
          onTap: _openInBrowser,
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
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              if (detail.isNotEmpty && detail != 'Size unknown') ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                      color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This file type cannot be previewed inline. '
                        'Use the buttons below to view or download it.',
                        style: TextStyle(
                            color: Colors.blue, fontSize: 13),
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
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  // ── Footer metadata bar ───────────────────────────────────
  Widget _buildFooter() {
    final doc = widget.document;
    final studentLabel = doc.studentName ?? doc.studentLrn ?? '—';
    final dateStr = _formatDate(doc.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _footerChip(Icons.person_outline_rounded, studentLabel),
          const SizedBox(width: 12),
          if (doc.documentType != null)
            _footerChip(Icons.label_outline_rounded, doc.documentType!),
          const Spacer(),
          _footerChip(Icons.calendar_today_outlined, dateStr),
        ],
      ),
    );
  }

  Widget _footerChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      );

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.month}/${date.day}/${date.year}';
  }
}
