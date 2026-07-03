import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/ui/providers/document_provider.dart';
import 'package:frontend/ui/shared/dialogs/error_dialog.dart';
import 'package:frontend/ui/shared/dialogs/success_dialog.dart';
import 'package:frontend/ui/shared/inputs/app_search_bar.dart';
import 'package:frontend/ui/shared/modals/custom_modal.dart';

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
            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    IconButton(
                      icon: Badge(
                        isLabelVisible: _selectedDocumentType != 'All Types',
                        child: const Icon(Icons.tune_rounded),
                      ),
                      tooltip: 'Filter by Document Type',
                      onPressed: () {
                        final items = trashAsync.value ?? [];
                        final docTypes = items
                            .map((e) => e.documentType ?? 'Unknown')
                            .toSet()
                            .toList()
                            ..sort();
                        _showFilterDialog(docTypes);
                      },
                    ),
                    _buildMultiSelectToggle(false),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: trashAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load Recycle Bin: $err'),
                      TextButton(
                        onPressed: () => ref.invalidate(trashDocumentsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  var filteredItems = items;
                  
                  if (_selectedDocumentType != 'All Types') {
                    filteredItems = filteredItems
                        .where((i) => (i.documentType ?? 'Unknown') == _selectedDocumentType)
                        .toList();
                  }

                  if (_searchController.text.isNotEmpty) {
                    final s = _searchController.text.toLowerCase();
                    filteredItems = filteredItems
                        .where(
                          (i) =>
                              i.fileName.toLowerCase().contains(s) ||
                              (i.studentName ?? '').toLowerCase().contains(s),
                        )
                        .toList();
                  }

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Recycle Bin is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Soft-deleted documents will appear here.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      final isSelected = _selectedTrashIds.contains(item.id);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: _isMultiSelectMode
                            ? Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primaryGreen,
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
                            : null,
                        title: Text(
                          item.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
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
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${item.daysRemaining} days remaining',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (item.documentType != null)
                                    Text(
                                      item.documentType!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: isMobile
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (val) {
                                  if (val == 'restore') _handleRestore(item.id);
                                  if (val == 'delete') _handlePermanentDelete(item.id);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Restore', style: TextStyle(color: AppColors.primaryGreen)),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('DELETE', style: TextStyle(color: AppColors.error)),
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
                                    onPressed: () => _handlePermanentDelete(item.id),
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Batch Actions Bar (if any selected)
            if (_isMultiSelectMode && _selectedTrashIds.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Text(
                      '${_selectedTrashIds.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _handleBulkRestore(_selectedTrashIds.toList()),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore All'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handleBulkPermanentDelete(_selectedTrashIds.toList()),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectToggle(bool isIconOnly) {
    final active = _isMultiSelectMode;
    final color = active ? AppColors.primaryGreen : AppColors.textSecondary;
    final bgColor = active ? AppColors.primaryGreen.withValues(alpha: 0.1) : AppColors.surfaceWhite;
    final borderColor = active ? AppColors.primaryGreen : Colors.grey.shade300;

    final child = Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 10 : 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rtl_rounded, size: 20, color: color),
          if (!isIconOnly) ...[
            const SizedBox(width: 8),
            Text(
              'Select',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: 'Select items',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _isMultiSelectMode = !_isMultiSelectMode;
            if (!_isMultiSelectMode) {
              _selectedTrashIds.clear();
            }
          });
        },
        child: child,
      ),
    );
  }

  Future<void> _handleRestore(int id) async {
    try {
      await ref.read(trashMutationProvider.notifier).restoreDocument(id);
      if (mounted) showSuccessDialog(context, message: 'Document has been restored.');
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Permanent Deletion'),
        content: const Text(
          'Are you sure you want to permanently delete this document? This will remove the file from the disk and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
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
      if (mounted) showSuccessDialog(context, message: 'Document permanently deleted.');
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Deletion'),
        content: Text(
          'Are you sure you want to permanently delete these ${ids.length} documents? This will delete the files from the disk and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text('Filter Recycle Bin'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Document Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tempType,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => tempType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedDocumentType = 'All Types');
                Navigator.of(ctx).pop();
              },
              child: const Text('RESET', style: TextStyle(color: AppColors.error)),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _selectedDocumentType = tempType);
                Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: const Text('APPLY'),
            ),
          ],
        ),
      ),
    );
  }
}
