import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/download_service.dart';
import '../../../../core/utils/file_icon_helper.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../../domain/entities/document_version_model.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import 'document_preview_modal.dart';

/// Shows a bottom sheet listing all versions of a document.
/// Each version can be downloaded or opened in the preview modal.
Future<void> showDocumentVersionHistory(
  BuildContext context, {
  required DocumentModel document,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VersionHistorySheet(document: document),
  );
}

class _VersionHistorySheet extends StatefulWidget {
  final DocumentModel document;
  const _VersionHistorySheet({required this.document});

  @override
  State<_VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<_VersionHistorySheet> {
  final _repo = DocumentRepository();
  List<DocumentVersionModel>? _versions;
  String? _error;
  final Set<int> _loading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final versions = await _repo.getDocumentVersions(widget.document.id);
      if (mounted) setState(() => _versions = versions);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _download(DocumentVersionModel version) async {
    if (_loading.contains(version.id)) return;
    setState(() => _loading.add(version.id));
    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) throw Exception('Not authenticated');
      final dirPath = await DownloadService.getDownloadDirectoryPath();
      final sep = Platform.pathSeparator;
      final savePath = '$dirPath${sep}v${version.versionNumber}_${version.fileName}';
      await _repo.downloadDocumentVersion(
        widget.document.id,
        savePath,
        versionId: version.id,
      );
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Version ${version.versionNumber} downloaded.',
        filePath: savePath,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Download Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading.remove(version.id));
    }
  }

  Future<void> _openPreview(DocumentVersionModel version) async {
    if (_loading.contains(version.id)) return;
    setState(() => _loading.add(version.id));
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}${Platform.pathSeparator}v${version.versionNumber}_${version.fileName}';
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        await _repo.downloadDocumentVersion(
          widget.document.id,
          tempPath,
          versionId: version.id,
        );
      }
      if (!mounted) return;
      showDocumentPreview(
        context: context,
        localFile: tempFile,
        localFileName: version.fileName,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Open Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading.remove(version.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.primaryGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            widget.document.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              // Content
              Expanded(
                child: _buildBody(scrollController, textPrimary, textSecondary, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    ScrollController scrollController,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () { setState(() { _error = null; _versions = null; }); _load(); },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_versions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_versions!.isEmpty) {
      return Center(
        child: Text('No versions found.', style: TextStyle(color: textSecondary)),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _versions!.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
      itemBuilder: (ctx, i) {
        final version = _versions![i];
        final isLatest = i == 0;
        final isLoadingItem = _loading.contains(version.id);
        final fileColor = FileIconHelper.getColor(version.fileName);
        final fileIcon = FileIconHelper.getIcon(version.fileName);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fileColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: fileColor.withValues(alpha: 0.25)),
                ),
                child: Icon(fileIcon, color: fileColor, size: 22),
              ),
              if (isLatest)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Latest',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            'Version ${version.versionNumber}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                version.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              Row(
                children: [
                  if (version.uploadedByName != null) ...[
                    Icon(Icons.person_outline, size: 11, color: textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      version.uploadedByName!,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    version.formattedSize,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                  if (version.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(version.createdAt!),
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ],
              ),
              if (version.templateName != null)
                Text(
                  'Template: ${version.templateName}',
                  style: TextStyle(fontSize: 11, color: AppColors.primaryGreen),
                ),
            ],
          ),
          trailing: isLoadingItem
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.visibility_outlined, size: 20, color: textSecondary),
                      tooltip: 'Preview',
                      onPressed: () => _openPreview(version),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.download_rounded, size: 20, color: AppColors.primaryGreen),
                      tooltip: 'Download',
                      onPressed: () => _download(version),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
