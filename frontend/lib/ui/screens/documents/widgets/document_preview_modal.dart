import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../../../domain/repositories/document_repository.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/conversion_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/document_properties_dialog.dart';
import 'student_profile_modal.dart';
import 'excel_viewer_widget.dart';
import 'document_version_history_sheet.dart';

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
  bool _isUploadingVersion = false;
  File? _editTempFile; // Tracked for cleanup after edit-upload cycle

  final _docRepo = DocumentRepository();

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
      final savedPath = await DownloadService.downloadFile(
        url: _downloadUrl,
        fileName: _fileName,
      );
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Document downloaded successfully.',
        filePath: savedPath,
        notes: 'The document has been saved to your downloads folder.',
      );
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

  Future<void> _copyDocument() async {
    if (widget.document == null) return;
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .copyDocument(widget.document!.id);
      if (!mounted) return;
      showSuccessDialog(context, message: 'Document copied.');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Copy Failed', e.toString());
    }
  }

  void _showProperties() {
    if (widget.document == null) return;
    DocumentPropertiesDialog.show(context, document: widget.document!);
  }

  void _viewStudentProfile() {
    final sId = widget.document?.studentId;
    if (sId == null) return;
    final userRole = ref.read(authProvider).value?.role ?? 'teacher';
    showStudentProfileModal(
      context,
      studentId: sId,
      userRole: userRole,
      hideEnrollmentActions: true,
    );
  }

  Future<void> _deleteDocument() async {
    if (widget.document == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'Delete Document',
              style: TextStyle(color: AppColors.error, fontSize: 17),
            ),
          ],
        ),
        content: Text('Are you sure you want to move "$_fileName" to the Recycle Bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(documentMutationProvider.notifier).deleteDocument(widget.document!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessDialog(context, message: 'Document moved to Recycle Bin.');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Delete Failed', e.toString());
    }
  }

  Future<void> _openExternalExcel() async {
    await _openInDefaultApp(openWith: false);
  }

  /// Open the file in the OS default app, or show the Windows "Open With" dialog.
  Future<void> _openInDefaultApp({bool openWith = false}) async {
    if (_isOpeningExternal) return;
    setState(() => _isOpeningExternal = true);
    try {
      String? filePath;

      if (widget.localFile != null) {
        filePath = widget.localFile!.path;
      } else {
        if (_token == null || widget.document == null) return;
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}${Platform.pathSeparator}$_fileName';
        final file = File(filePath);
        if (!await file.exists()) {
          final dio = Dio();
          await dio.download(_downloadUrl, filePath);
        }
      }

      if (Platform.isWindows) {
        if (openWith) {
          // Use openwith.exe (built-in since Windows 8) for the native "Open With" dialog
          final result = await Process.run(
            'openwith.exe',
            [filePath],
            runInShell: false,
          );
          if (result.exitCode != 0) {
            // Fallback: use rundll32 shell verb
            await Process.run(
              'cmd',
              ['/c', 'rundll32.exe', 'shell32.dll,OpenAs_RunDLL', filePath],
              runInShell: true,
            );
          }
        } else {
          await Process.run(
            'cmd',
            ['/c', 'start', '""', filePath],
            runInShell: true,
          );
        }
      } else {
        // Android / iOS — launchUrl with externalApplication shows OS app chooser
        final uri = Uri.file(filePath);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch external application for this file.');
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

  /// Download temp copy, open in default app, then prompt to upload as a new version.
  Future<void> _editInExternalApp() async {
    if (widget.document == null || _isOpeningExternal) return;
    setState(() => _isOpeningExternal = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}${Platform.pathSeparator}$_fileName';
      _editTempFile = File(tempPath);
      if (!await _editTempFile!.exists()) {
        final dio = Dio();
        await dio.download(_downloadUrl, tempPath);
      }

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', tempPath], runInShell: true);
      } else {
        final uri = Uri.file(tempPath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Prompt user to upload the edited file as a new version
      if (!mounted) return;
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text('Upload Edited Version?', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Once you\'re done editing, you can upload the file as a new version. '
            'Do you want to upload your changes now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Upload Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (shouldUpload == true && mounted) {
        await _uploadNewVersion(prePickedPath: tempPath);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Edit Failed', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isOpeningExternal = false);
    }
  }

  /// Pick a file (or use [prePickedPath]) and upload it as a new version.
  Future<void> _uploadNewVersion({String? prePickedPath}) async {
    if (widget.document == null) return;
    String? filePath = prePickedPath;

    if (filePath == null) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xls', 'xlsx', 'doc', 'docx', 'csv'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;
      filePath = result.files.single.path!;
    }

    if (!mounted) return;
    setState(() => _isUploadingVersion = true);
    try {
      final nextVersion = await _docRepo.uploadDocumentVersion(
        widget.document!.id,
        filePath!,
      );
      // Invalidate provider so the documents list refreshes
      ref.invalidate(documentPageProvider);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Version $nextVersion uploaded successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Upload Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUploadingVersion = false);
    }
  }

  void _showVersionHistory() {
    if (widget.document == null) return;
    showDocumentVersionHistory(context, document: widget.document!);
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

  bool _isConverting = false;

  Future<void> _convertToPdf() async {
    if (widget.document == null || _isConverting) return;
    setState(() => _isConverting = true);
    try {
      final converted = await ref
          .read(conversionProvider.notifier)
          .convertToPdf(widget.document!.id);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Excel converted to PDF successfully as "${converted.fileName}".',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Conversion Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final isSmallScreen = screenW < 400;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<_PreviewActionItem> directActions = [];
    final List<_PreviewActionItem> menuActions = [];

    if (_isExcel && widget.document != null) {
      directActions.add(_PreviewActionItem(
        id: 'convert_pdf',
        label: 'Convert to PDF',
        iconData: Icons.picture_as_pdf_outlined,
        onTap: _isConverting ? null : _convertToPdf,
        isLoading: _isConverting,
      ));
    }
    if (_isExcel || _isPdf || _isOffice || _isImage) {
      // Open in default app
      directActions.add(_PreviewActionItem(
        id: 'open_external',
        label: 'Open',
        iconData: Icons.open_in_new_rounded,
        onTap: _isOpeningExternal ? null : _openExternalExcel,
        isLoading: _isOpeningExternal,
      ));
      // Open With (Windows chooser / Android chooser)
      if (widget.document != null) {
        directActions.add(_PreviewActionItem(
          id: 'open_with',
          label: 'Open With',
          iconData: Icons.apps_rounded,
          onTap: _isOpeningExternal ? null : () => _openInDefaultApp(openWith: true),
          isLoading: _isOpeningExternal,
        ));
      }
    }
    if (widget.document != null) {
      // Edit action for editable file types
      if (_isExcel || _isOffice) {
        directActions.add(_PreviewActionItem(
          id: 'edit',
          label: 'Edit',
          iconData: Icons.edit_document,
          onTap: (_isOpeningExternal || _isUploadingVersion) ? null : _editInExternalApp,
          isLoading: _isOpeningExternal || _isUploadingVersion,
          color: Colors.orange.shade700,
        ));
      }
      // Upload New Version
      directActions.add(_PreviewActionItem(
        id: 'upload_version',
        label: 'Upload New Version',
        iconData: Icons.upload_file_rounded,
        onTap: _isUploadingVersion ? null : _uploadNewVersion,
        isLoading: _isUploadingVersion,
        color: AppColors.primaryGreen,
      ));
      directActions.add(_PreviewActionItem(
        id: 'print_list',
        label: 'Add to Print List',
        iconData: Icons.print_outlined,
        onTap: _addToPrintList,
      ));
      directActions.add(_PreviewActionItem(
        id: 'download',
        label: 'Download',
        iconData: Icons.download_rounded,
        onTap: _downloadFile,
      ));
      directActions.add(_PreviewActionItem(
        id: 'history',
        label: 'Version History',
        iconData: Icons.history_rounded,
        onTap: _showVersionHistory,
      ));
      directActions.add(_PreviewActionItem(
        id: 'properties',
        label: 'Properties',
        iconData: Icons.info_outline_rounded,
        onTap: _showProperties,
      ));
      if (widget.document!.studentId != null) {
        directActions.add(_PreviewActionItem(
          id: 'view_student',
          label: 'View Student Profile',
          iconData: Icons.person_outline_rounded,
          onTap: _viewStudentProfile,
        ));
      }

      // Always inside More menu: Copy and Delete
      menuActions.add(_PreviewActionItem(
        id: 'copy',
        label: 'Copy',
        iconData: Icons.copy_rounded,
        onTap: _copyDocument,
      ));
      if (ref.watch(authProvider).value?.role != 'teacher') {
        menuActions.add(_PreviewActionItem(
          id: 'delete',
          label: 'Delete',
          iconData: Icons.delete_outline_rounded,
          onTap: _deleteDocument,
          color: Colors.redAccent,
        ));
      }
    }

    final List<_PreviewActionItem> shownDirectActions = [];
    final List<_PreviewActionItem> allMenuActions = [];

    if (isSmallScreen) {
      allMenuActions.addAll(directActions);
      allMenuActions.addAll(menuActions);
    } else {
      const int maxDirect = 4;
      shownDirectActions.addAll(directActions.take(maxDirect));
      allMenuActions.addAll(directActions.skip(maxDirect));
      allMenuActions.addAll(menuActions);
    }

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
            ...shownDirectActions.map(
              (action) => IconButton(
                icon: action.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(action.iconData, color: Colors.white),
                tooltip: action.label,
                onPressed: action.onTap,
              ),
            ),
            if (allMenuActions.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'More Actions',
                onSelected: (id) {
                  final action = allMenuActions.firstWhere((a) => a.id == id);
                  action.onTap?.call();
                },
                itemBuilder: (context) => allMenuActions.map((action) {
                  return PopupMenuItem<String>(
                    value: action.id,
                    child: Row(
                      children: [
                        if (action.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            action.iconData,
                            size: 20,
                            color: action.color ??
                                (isDark ? Colors.white70 : Colors.black87),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          action.label,
                          style: TextStyle(
                            color: action.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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

class _PreviewActionItem {
  final String id;
  final String label;
  final IconData iconData;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLoading;

  const _PreviewActionItem({
    required this.id,
    required this.label,
    required this.iconData,
    required this.onTap,
    this.color,
    this.isLoading = false,
  });
}

