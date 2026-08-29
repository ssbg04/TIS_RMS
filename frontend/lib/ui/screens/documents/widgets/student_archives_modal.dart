import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/download_service.dart';
import '../../../../core/utils/file_icon_helper.dart';
import '../../../../core/utils/theme_extension.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../providers/archives_provider.dart';
import '../../../providers/conversion_provider.dart';
import '../../../providers/document_provider.dart';
import '../../../shared/dialogs/document_properties_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/inputs/app_search_bar.dart';
import '../../../shared/modals/custom_modal.dart';
import 'document_preview_modal.dart';

class StudentArchivesModal extends ConsumerStatefulWidget {
  final int studentId;
  final String studentName;
  final String userRole;

  const StudentArchivesModal({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.userRole,
  });

  static Future<void> show(
    BuildContext context, {
    required int studentId,
    required String studentName,
    required String userRole,
  }) {
    return showDialog(
      context: context,
      builder: (_) => StudentArchivesModal(
        studentId: studentId,
        studentName: studentName,
        userRole: userRole,
      ),
    );
  }

  @override
  ConsumerState<StudentArchivesModal> createState() =>
      _StudentArchivesModalState();
}

class _StudentArchivesModalState extends ConsumerState<StudentArchivesModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isMultiSelectMode = false;
  final Set<int> _selectedIds = {};
  String _searchQuery = '';

  bool get _isAdmin => widget.userRole != 'teacher';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<DocumentModel> _getFilteredItems(List<DocumentModel> items) {
    if (_searchQuery.trim().isEmpty) return items;
    final q = _searchQuery.toLowerCase().trim();
    return items.where((item) {
      final matchesFile = item.fileName.toLowerCase().contains(q);
      final matchesType =
          item.documentType?.toLowerCase().contains(q) ?? false;
      return matchesFile || matchesType;
    }).toList();
  }

  void _refresh() {
    ref.invalidate(studentArchivedDocumentsProvider(widget.studentId));
    ref.invalidate(documentPageProvider);
    ref.invalidate(foldersProvider);
    ref.invalidate(studentFoldersProvider);
    ref.invalidate(archiveDocumentPageProvider);
    ref.invalidate(archiveStudentFoldersProvider);
  }

  Future<void> _handlePreview(DocumentModel doc) async {
    showDocumentPreview(context: context, document: doc);
  }

  Future<void> _handleDownload(DocumentModel doc) async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) return;
      final url =
          '${ApiConstants.baseUrl}/documents/${doc.id}/view?token=$token&download=true';
      await DownloadService.downloadFile(url: url, fileName: doc.fileName);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Document downloaded successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Download Failed', e.toString());
    }
  }

  Future<void> _handleRestoreSingle(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.unarchive_outlined, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Restore Document'),
          ],
        ),
        content: Text(
          'Are you sure you want to restore "${doc.fileName}" to active documents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(documentMutationProvider.notifier)
          .updateStatus(doc.id, 'Completed');
      _refresh();
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Document restored to active documents.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Restore Failed', e.toString());
    }
  }

  Future<void> _handleDeleteSingle(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Document', style: TextStyle(color: AppColors.error)),
          ],
        ),
        content: Text(
          'Are you sure you want to move "${doc.fileName}" to the Recycle Bin?',
        ),
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
      await ref
          .read(documentMutationProvider.notifier)
          .deleteDocument(doc.id);
      _refresh();
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Document moved to Recycle Bin.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Delete Failed', e.toString());
    }
  }

  Future<void> _handleBatchRestore() async {
    if (_selectedIds.isEmpty) return;
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .bulkUpdateStatus(_selectedIds.toList(), 'Completed');
      final count = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isMultiSelectMode = false;
      });
      _refresh();
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Restored $count document${count > 1 ? 's' : ''} to active folder.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Batch Restore Failed', e.toString());
    }
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'Delete Selected Documents',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to move ${_selectedIds.length} document${_selectedIds.length > 1 ? 's' : ''} to the Recycle Bin?',
        ),
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
      await ref
          .read(documentMutationProvider.notifier)
          .bulkDelete(_selectedIds.toList());
      final count = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isMultiSelectMode = false;
      });
      _refresh();
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Moved $count document${count > 1 ? 's' : ''} to Recycle Bin.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Batch Delete Failed', e.toString());
    }
  }

  Future<void> _handleBatchDownload(List<DocumentModel> allDocs) async {
    if (_selectedIds.isEmpty) return;
    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) return;

      int successCount = 0;
      for (final docId in _selectedIds) {
        final match = allDocs.where((d) => d.id == docId);
        if (match.isNotEmpty) {
          final doc = match.first;
          final url =
              '${ApiConstants.baseUrl}/documents/${doc.id}/view?token=$token&download=true';
          await DownloadService.downloadFile(url: url, fileName: doc.fileName);
          successCount++;
        }
      }

      setState(() {
        _selectedIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Successfully downloaded $successCount documents.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Batch Download Failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final archivesAsync =
        ref.watch(studentArchivedDocumentsProvider(widget.studentId));

    return CustomModal(
      title: widget.studentName.isNotEmpty
          ? '${widget.studentName} — Archives'
          : 'Archived Documents',
      icon: Icons.inventory_2_outlined,
      maxWidth: 800,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Controls header or Multi-select header
            archivesAsync.maybeWhen(
              data: (items) {
                final filtered = _getFilteredItems(items);
                if (_isMultiSelectMode) {
                  return _buildMultiSelectBar(isDark, isMobile, filtered);
                }
                return _buildControlsHeader(isDark, isMobile, items);
              },
              orElse: () => _buildControlsHeader(isDark, isMobile, []),
            ),

            const Divider(height: 1),

            // Main Content
            Expanded(
              child: archivesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load archives',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$err',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  final filtered = _getFilteredItems(items);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              items.isEmpty
                                  ? 'No archived documents'
                                  : 'No matching documents found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              items.isEmpty
                                  ? 'Archived documents for this student will appear here.'
                                  : 'Try adjusting your search term.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isSelected = _selectedIds.contains(item.id);

                      return InkWell(
                        onTap: _isMultiSelectMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(item.id);
                                  } else {
                                    _selectedIds.add(item.id);
                                  }
                                });
                              }
                            : () => _handlePreview(item),
                        child: Container(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.primaryGreen
                                      .withValues(alpha: 0.15)
                                  : AppColors.primaryGreen
                                      .withValues(alpha: 0.08))
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: _isMultiSelectMode
                                ? Checkbox(
                                    value: isSelected,
                                    activeColor: AppColors.primaryGreen,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIds.add(item.id);
                                        } else {
                                          _selectedIds.remove(item.id);
                                        }
                                      });
                                    },
                                  )
                                : Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: FileIconHelper.getColor(
                                        item.fileName,
                                        docType: item.documentType,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      FileIconHelper.getIcon(
                                        item.fileName,
                                        docType: item.documentType,
                                      ),
                                      color: FileIconHelper.getColor(
                                        item.fileName,
                                        docType: item.documentType,
                                      ),
                                      size: 22,
                                    ),
                                  ),
                            title: Text(
                              item.fileName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  if (item.documentType != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurfaceCard
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : Colors.grey.shade300,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        item.documentType!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    FileIconHelper.formatFileSize(
                                      item.fileSize ?? item.size,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${formatShortDate(item.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: _isMultiSelectMode
                                ? null
                                : PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                    onSelected: (val) {
                                      if (val == 'preview') {
                                        _handlePreview(item);
                                      } else if (val == 'download') {
                                        _handleDownload(item);
                                      } else if (val == 'properties') {
                                        DocumentPropertiesDialog.show(
                                          context,
                                          document: item,
                                        );
                                      } else if (val == 'convert_pdf') {
                                        ref
                                            .read(conversionProvider.notifier)
                                            .convertToPdf(item.id);
                                      } else if (val == 'restore') {
                                        _handleRestoreSingle(item);
                                      } else if (val == 'delete') {
                                        _handleDeleteSingle(item);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'preview',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Preview',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'download',
                                        child: Row(
                                          children: [
                                            Icon(Icons.download, size: 18),
                                            SizedBox(width: 10),
                                            Text(
                                              'Download',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'properties',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 18,
                                              color: AppColors.primaryGreen,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Properties',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_isAdmin) ...[
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.unarchive_outlined,
                                                size: 18,
                                                color: AppColors.primaryGreen,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Restore Document',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppColors.error,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsHeader(
    bool isDark,
    bool isMobile,
    List<DocumentModel> allDocs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: AppSearchBar(
              hint: 'Search archived files…',
              controller: _searchController,
              focusNode: _searchFocusNode,
              collapsible: false,
              maxWidth: 400,
              onChanged: (val) => setState(() => _searchQuery = val),
              onSubmitted: (val) => setState(() => _searchQuery = val),
            ),
          ),
          if (_isAdmin && allDocs.isNotEmpty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Select Multiple',
              child: IconButton(
                icon: const Icon(Icons.checklist_rounded, size: 20),
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                onPressed: () => setState(() => _isMultiSelectMode = true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar(
    bool isDark,
    bool isMobile,
    List<DocumentModel> filteredDocs,
  ) {
    final allSelected = filteredDocs.isNotEmpty &&
        filteredDocs.every((d) => _selectedIds.contains(d.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark
          ? AppColors.darkSurfaceCard
          : AppColors.primaryGreen.withValues(alpha: 0.08),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _selectedIds.clear();
                _isMultiSelectMode = false;
              });
            },
            tooltip: 'Cancel Selection',
          ),
          const SizedBox(width: 4),
          Text(
            '${_selectedIds.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              size: 20,
            ),
            tooltip: allSelected ? 'Unselect All' : 'Select All',
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.addAll(filteredDocs.map((d) => d.id));
                }
              });
            },
          ),
          const Spacer(),
          Tooltip(
            message: 'Download',
            child: IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _handleBatchDownload(filteredDocs),
            ),
          ),
          if (_isAdmin) ...[
            Tooltip(
              message: 'Restore Selected',
              child: IconButton(
                icon: const Icon(
                  Icons.unarchive_outlined,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
                onPressed: _selectedIds.isEmpty ? null : _handleBatchRestore,
              ),
            ),
            Tooltip(
              message: 'Delete Selected',
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
