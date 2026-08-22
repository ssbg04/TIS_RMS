import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/utils/theme_extension.dart';
import 'package:frontend/ui/providers/document_provider.dart';
import 'package:frontend/ui/shared/dialogs/error_dialog.dart';
import 'package:frontend/ui/shared/dialogs/success_dialog.dart';
import 'package:frontend/ui/shared/inputs/app_search_bar.dart';
import 'package:frontend/ui/shared/modals/custom_modal.dart';
import 'package:frontend/domain/repositories/document_repository.dart'
    show TrashDocumentModel;
import 'package:frontend/core/utils/file_icon_helper.dart';

class RecycleBinModal extends ConsumerStatefulWidget {
  const RecycleBinModal({super.key});

  @override
  ConsumerState<RecycleBinModal> createState() => _RecycleBinModalState();
}

class _RecycleBinModalState extends ConsumerState<RecycleBinModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isMultiSelectMode = false;
  final Set<int> _selectedTrashIds = {};
  String _selectedDocumentType = 'All Types';

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

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final trashAsync = ref.watch(trashDocumentsProvider);

    return CustomModal(
      title: 'Recycle Bin',
      icon: Icons.delete_outline,
      maxWidth: 800,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          children: [
            // Top Bar: Multi-Select Header OR Search & Controls Header
            trashAsync.maybeWhen(
              data: (items) {
                final filteredItems = _getFilteredItems(items);
                if (_isMultiSelectMode) {
                  return _buildMultiSelectBar(isDark, isMobile, filteredItems);
                }
                return _buildControlsHeader(isDark, isMobile, items);
              },
              orElse: () => _buildControlsHeader(isDark, isMobile, []),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: trashAsync.when(
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
                          'Failed to load Recycle Bin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$err',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(trashDocumentsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  final filteredItems = _getFilteredItems(items);

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 64,
                              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Recycle Bin is empty',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Soft-deleted documents will appear here.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
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
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      final isSelected = _selectedTrashIds.contains(item.id);

                      return InkWell(
                        onTap: _isMultiSelectMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTrashIds.remove(item.id);
                                  } else {
                                    _selectedTrashIds.add(item.id);
                                  }
                                });
                              }
                            : null,
                        child: Container(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.primaryGreen.withValues(alpha: 0.15)
                                  : AppColors.primaryGreen.withValues(alpha: 0.08))
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
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedTrashIds.add(item.id);
                                        } else {
                                          _selectedTrashIds.remove(item.id);
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
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.studentName != null &&
                                      item.studentName!.isNotEmpty)
                                    Text(
                                      'Student: ${item.studentName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: isDark ? 0.2 : 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.red.withValues(
                                              alpha: isDark ? 0.4 : 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${item.daysRemaining} days remaining',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.redAccent.shade100
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (item.documentType != null)
                                        Text(
                                          item.documentType!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: isMobile
                                ? PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                                    onSelected: (val) {
                                      if (val == 'restore') _handleRestore(item.id);
                                      if (val == 'delete') {
                                        _handlePermanentDelete(item.id);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.restore,
                                              size: 18,
                                              color: AppColors.primaryGreen,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Restore',
                                              style: TextStyle(
                                                color: AppColors.primaryGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_forever,
                                              size: 18,
                                              color: AppColors.error,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'DELETE',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.restore,
                                          color: AppColors.primaryGreen,
                                        ),
                                        tooltip: 'Restore document',
                                        onPressed: () => _handleRestore(item.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_forever,
                                          color: AppColors.error,
                                        ),
                                        tooltip: 'Delete permanently',
                                        onPressed: () =>
                                            _handlePermanentDelete(item.id),
                                      ),
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

  List<TrashDocumentModel> _getFilteredItems(List<TrashDocumentModel> items) {
    var filtered = items;

    if (_selectedDocumentType != 'All Types') {
      filtered = filtered
          .where(
            (i) => (i.documentType ?? 'Unknown') == _selectedDocumentType,
          )
          .toList();
    }

    if (_searchController.text.isNotEmpty) {
      final s = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (i) =>
                i.fileName.toLowerCase().contains(s) ||
                (i.studentName ?? '').toLowerCase().contains(s),
          )
          .toList();
    }

    return filtered;
  }

  Widget _buildControlsHeader(
    bool isDark,
    bool isMobile,
    List<TrashDocumentModel> items,
  ) {
    return Container(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) => AppSearchBar(
                hint: 'Search recycle bin...',
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() {}),
                maxWidth: isMobile ? constraints.maxWidth : 300,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!_searchFocusNode.hasFocus) ...[
            Tooltip(
              message: 'Filter by Document Type',
              child: IconButton(
                icon: Badge(
                  isLabelVisible: _selectedDocumentType != 'All Types',
                  backgroundColor: AppColors.primaryGreen,
                  child: Icon(
                    Icons.tune_rounded,
                    color: _selectedDocumentType != 'All Types'
                        ? AppColors.primaryGreen
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                ),
                onPressed: () {
                  final docTypes = items
                      .map((e) => e.documentType ?? 'Unknown')
                      .toSet()
                      .toList()
                    ..sort();
                  _showFilterDialog(docTypes);
                },
              ),
            ),
            const SizedBox(width: 4),
            _buildMoreOptionsDropdown(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildMoreOptionsDropdown(bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      tooltip: 'More Options',
      position: PopupMenuPosition.under,
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'multi_select') {
          setState(() {
            _isMultiSelectMode = !_isMultiSelectMode;
            if (!_isMultiSelectMode) {
              _selectedTrashIds.clear();
            }
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'multi_select',
          child: Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _isMultiSelectMode ? 'Exit Multi-Select' : 'Select Multiple',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectBar(
    bool isDark,
    bool isMobile,
    List<TrashDocumentModel> filteredItems,
  ) {
    final filteredIds = filteredItems.map((i) => i.id).toSet();
    final bool allSelected = filteredIds.isNotEmpty &&
        filteredIds.every((id) => _selectedTrashIds.contains(id));
    final buttonColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceCard
            : AppColors.primaryGreen.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Tooltip(
              message: 'Cancel selection',
              child: IconButton(
                icon: Icon(Icons.close, color: buttonColor),
                onPressed: () {
                  setState(() {
                    _selectedTrashIds.clear();
                    _isMultiSelectMode = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedTrashIds.isEmpty
                  ? 'Select items'
                  : '${_selectedTrashIds.length} selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: allSelected ? 'Unselect All' : 'Select All',
              child: IconButton(
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  color: buttonColor,
                ),
                onPressed: filteredItems.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allSelected) {
                            _selectedTrashIds.clear();
                          } else {
                            _selectedTrashIds.addAll(filteredIds);
                          }
                        });
                      },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _selectedTrashIds.isEmpty
                  ? null
                  : () => _handleBulkRestore(_selectedTrashIds.toList()),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Restore All'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                disabledForegroundColor: isDark
                    ? AppColors.darkTextMuted
                    : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _selectedTrashIds.isEmpty
                  ? null
                  : () => _handleBulkPermanentDelete(
                        _selectedTrashIds.toList(),
                      ),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? AppColors.darkSurface2
                    : Colors.grey.shade200,
                disabledForegroundColor: isDark
                    ? AppColors.darkTextMuted
                    : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRestore(int id) async {
    try {
      await ref.read(trashMutationProvider.notifier).restoreDocument(id);
      if (mounted) {
        showSuccessDialog(context, message: 'Document has been restored.');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Restore Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _handleBulkRestore(List<int> ids) async {
    try {
      await ref.read(trashMutationProvider.notifier).bulkRestore(ids);
      if (mounted) {
        setState(() {
          _selectedTrashIds.clear();
        });
        showSuccessDialog(
          context,
          message: 'Selected documents restored successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Bulk Restore Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _handlePermanentDelete(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Confirm Permanent Deletion',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this document? This will remove the file from the disk and cannot be undone.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(trashMutationProvider.notifier).permanentDelete(id);
      if (mounted) {
        showSuccessDialog(context, message: 'Document permanently deleted.');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Deletion Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _handleBulkPermanentDelete(List<int> ids) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Confirm Bulk Deletion',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete these ${ids.length} documents? This will delete the files from the disk and cannot be undone.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(trashMutationProvider.notifier).bulkPermanentDelete(ids);
      if (mounted) {
        setState(() {
          _selectedTrashIds.clear();
        });
        showSuccessDialog(
          context,
          message: 'Selected documents permanently deleted.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Bulk Deletion Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showFilterDialog(List<String> availableDocTypes) {
    String tempType = _selectedDocumentType;
    final options = ['All Types', ...availableDocTypes];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Filter Recycle Bin',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tempType,
                dropdownColor: isDark ? AppColors.darkSurface2 : Colors.white,
                isExpanded: true,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                items: options
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => tempType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedDocumentType = 'All Types');
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'RESET',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _selectedDocumentType = tempType);
                Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('APPLY'),
            ),
          ],
        ),
      ),
    );
  }
}
