import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/download_service.dart';
import '../../../core/utils/file_icon_helper.dart';
import '../../../domain/entities/document_requirement_model.dart';
import '../../../domain/entities/template_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/template_provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/widgets/app_button_loader.dart';
import '../../shared/widgets/app_error_state.dart';

class TemplatesModal extends ConsumerStatefulWidget {
  const TemplatesModal({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplatesModal()),
    );
  }

  @override
  ConsumerState<TemplatesModal> createState() => _TemplatesModalState();
}

class _TemplatesModalState extends ConsumerState<TemplatesModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Inactive, 3: JHS, 4: SHS
  final Set<int> _downloadingIds = {};

  bool get _isAdmin {
    final currentUser = ref.watch(authProvider).asData?.value;
    return currentUser?.role == 'admin' || currentUser?.role == 'superadmin';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<DocumentTemplateModel> _filterTemplates(List<DocumentTemplateModel> all) {
    return all.where((t) {
      if (_selectedFilterIndex == 1 && !t.isActive) return false;
      if (_selectedFilterIndex == 2 && t.isActive) return false;
      if (_selectedFilterIndex == 3 && t.requirementCategory != 'JHS') return false;
      if (_selectedFilterIndex == 4 && t.requirementCategory != 'SHS') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = t.name.toLowerCase().contains(q);
        final descMatch = t.description?.toLowerCase().contains(q) ?? false;
        final reqMatch = t.requirementName?.toLowerCase().contains(q) ?? false;
        final fileMatch = t.currentFileName?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !descMatch && !reqMatch && !fileMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _downloadTemplate(DocumentTemplateModel template) async {
    if (_downloadingIds.contains(template.id)) return;
    setState(() => _downloadingIds.add(template.id));

    try {
      final dirPath = await DownloadService.getDownloadDirectoryPath();
      final fileName = template.currentFileName ?? '${template.name}.docx';
      final savePath = '$dirPath${Platform.pathSeparator}$fileName';

      await ref
          .read(templateMutationProvider.notifier)
          .downloadTemplate(template.id, savePath);

      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Template "${template.name}" downloaded.',
        filePath: savePath,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Download Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(template.id));
    }
  }

  void _showCreateOrEditModal({DocumentTemplateModel? template}) {
    showDialog(
      context: context,
      builder: (_) => _TemplateFormDialog(template: template),
    );
  }

  void _showVersionHistory(DocumentTemplateModel template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateVersionHistorySheet(templateId: template.id),
    );
  }

  void _confirmDelete(DocumentTemplateModel template) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Template',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        content: Text(
          'Are you sure you want to delete "${template.name}"? All version files for this template will be permanently removed.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(templateMutationProvider.notifier)
                    .deleteTemplate(template.id);
                if (!mounted) return;
                showSuccessDialog(context, message: 'Template deleted successfully');
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Delete Failed', e.toString());
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = ref.watch(templatesListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
        titleSpacing: isWide ? null : 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isWide ? 'Document Templates' : 'Templates',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: isWide ? 18 : 16.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            templatesAsync.maybeWhen(
              data: (list) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${list.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(templatesListProvider),
          ),
          if (isWide && _isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateOrEditModal(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: templatesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
              error: (e, _) => Center(
                child: AppErrorState.fromError(
                  error: e,
                  onRetry: () => ref.invalidate(templatesListProvider),
                ),
              ),
              data: (templates) {
                final filtered = _filterTemplates(templates);

                return Column(
                  children: [
                    // Search & Filters bar
                    _buildControlBar(isDark),

                    // Templates List
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(templates.isEmpty, isDark)
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 16 : 84),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) => _buildTemplateCard(
                                filtered[i],
                                isWide,
                                isDark,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: (!isWide && _isAdmin)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.add),
              label: const Text('New Template', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showCreateOrEditModal(),
            )
          : null,
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchFocusNode.unfocus(),
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search template name, description, requirement...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchFocusNode.unfocus();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(0, 'All', isDark),
                const SizedBox(width: 6),
                _filterChip(1, 'Active', isDark),
                const SizedBox(width: 6),
                _filterChip(2, 'Inactive', isDark),
                const SizedBox(width: 6),
                _filterChip(3, 'JHS Only', isDark),
                const SizedBox(width: 6),
                _filterChip(4, 'SHS Only', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label, bool isDark) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen
              : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAbsoluteEmpty, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.file_present_rounded,
                size: 34,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAbsoluteEmpty ? 'No Document Templates' : 'No Templates Match Filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAbsoluteEmpty
                  ? 'Upload official DepEd Form templates (.docx, .xlsx, .pdf) so teachers can download and use standardized forms.'
                  : 'Try clearing your search query or changing active/category filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            if (isAbsoluteEmpty && _isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateOrEditModal(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Upload First Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    DocumentTemplateModel template,
    bool isWide,
    bool isDark,
  ) {
    final fileName = template.currentFileName ?? '${template.name}.docx';
    final fileColor = FileIconHelper.getColor(fileName);
    final fileIcon = FileIconHelper.getIcon(fileName);
    final isDownloading = _downloadingIds.contains(template.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showVersionHistory(template),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 14 : 10,
              vertical: isWide ? 14 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading Icon
                Container(
                  width: isWide ? 44 : 38,
                  height: isWide ? 44 : 38,
                  margin: EdgeInsets.only(right: isWide ? 12 : 8),
                  decoration: BoxDecoration(
                    color: fileColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fileColor.withValues(alpha: 0.25)),
                  ),
                  child: Icon(fileIcon, color: fileColor, size: isWide ? 24 : 20),
                ),

                // Center details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        template.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isWide ? 14.5 : 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badges Wrap (Responsive and bounded against overflow)
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Linked requirement badge
                          if (template.requirementName != null) ...[
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: isWide ? 300 : 160,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link_rounded, size: 12, color: AppColors.primaryGreen),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      template.requirementCategory != null
                                          ? '${template.requirementName!} (${template.requirementCategory})'
                                          : template.requirementName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Version Count badge
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: isWide ? 200 : 130,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    template.currentVersionNumber != null
                                        ? 'v${template.currentVersionNumber} (${template.versionCount} ver)'
                                        : '${template.versionCount} ver',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Current File Name snippet
                          if (template.currentFileName != null) ...[
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: isWide ? 220 : 110,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      template.currentFileName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Inactive Tag
                          if (!template.isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Description
                      if (template.description != null && template.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          template.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download Button
                    isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20),
                            color: AppColors.primaryGreen,
                            tooltip: 'Download Template',
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            padding: const EdgeInsets.all(5),
                            onPressed: () => _downloadTemplate(template),
                          ),

                    if (isWide) ...[
                      IconButton(
                        icon: const Icon(Icons.history_rounded, size: 19),
                        tooltip: 'Version History',
                        onPressed: () => _showVersionHistory(template),
                      ),
                      if (_isAdmin) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Template',
                          onPressed: () => _showCreateOrEditModal(template: template),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(template),
                        ),
                      ],
                    ] else ...[
                      if (_isAdmin)
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          icon: const Icon(Icons.more_vert, size: 18),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: const EdgeInsets.all(4),
                          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                          onSelected: (val) {
                            if (val == 'history') {
                              _showVersionHistory(template);
                            } else if (val == 'edit') {
                              _showCreateOrEditModal(template: template);
                            } else if (val == 'delete') {
                              _confirmDelete(template);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'history',
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('Version History'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 19),
                          tooltip: 'Version History',
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: const EdgeInsets.all(4),
                          onPressed: () => _showVersionHistory(template),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add / Edit Template Dialog
// ─────────────────────────────────────────────────────────────
class _TemplateFormDialog extends ConsumerStatefulWidget {
  final DocumentTemplateModel? template;
  const _TemplateFormDialog({this.template});

  @override
  ConsumerState<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends ConsumerState<_TemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  int? _selectedRequirementId;
  bool _isActive = true;
  File? _pickedFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _descCtrl = TextEditingController(text: widget.template?.description ?? '');
    _selectedRequirementId = widget.template?.requirementId;
    _isActive = widget.template?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.template == null && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a template file to upload.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.template == null) {
        // Create
        await ref.read(templateMutationProvider.notifier).createTemplate(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              requirementId: _selectedRequirementId,
              isActive: _isActive,
              file: _pickedFile,
            );
        if (!mounted) return;
        Navigator.pop(context);
        showSuccessDialog(context, message: 'Template created successfully');
      } else {
        // Update info
        await ref.read(templateMutationProvider.notifier).updateTemplate(
              widget.template!.id,
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              requirementId: _selectedRequirementId,
              isActive: _isActive,
            );
        // If a new version file was picked during edit, upload it too
        if (_pickedFile != null) {
          await ref.read(templateMutationProvider.notifier).uploadTemplateVersion(
                widget.template!.id,
                _pickedFile!,
              );
        }
        if (!mounted) return;
        Navigator.pop(context);
        showSuccessDialog(context, message: 'Template updated successfully');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Save Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.template != null;
    final reqsAsync = ref.watch(requirementsSettingsProvider);

    final List<DocumentRequirementModel> allReqs = [];
    if (reqsAsync.hasValue) {
      allReqs.addAll(reqsAsync.value!.jhs);
      allReqs.addAll(reqsAsync.value!.shs);
    }

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.file_present_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Template' : 'New Document Template',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Template Name
                  CustomTextField(
                    controller: _nameCtrl,
                    hintText: 'Template Name * (e.g., SF10 JHS Official DepEd Form)',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Template name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Description
                  CustomTextField(
                    controller: _descCtrl,
                    hintText: 'Description (Optional notes, revision details)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Linked Requirement
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Linked Document Requirement',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedRequirementId,
                        isExpanded: true,
                        hint: const Text('None (General Template)'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None (General Template)'),
                          ),
                          ...allReqs.map(
                            (r) => DropdownMenuItem<int?>(
                              value: r.id,
                              child: Text(
                                '${r.name} (${r.category})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedRequirementId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // File Picker section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEdit ? 'Upload New File Version (Optional)' : 'Template File *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: Text(_pickedFile == null ? 'Browse...' : 'Change'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(color: AppColors.primaryGreen),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _pickedFile!.path.split(Platform.pathSeparator).last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() => _pickedFile = null),
                              ),
                            ],
                          ),
                        ] else if (isEdit && widget.template!.currentFileName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Current file: ${widget.template!.currentFileName} (v${widget.template!.currentVersionNumber ?? 1})',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Supported formats: .docx, .xlsx, .pdf, .xls, .doc',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Active Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Template',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeThumbColor: AppColors.primaryGreen,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: _isSaving
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppButtonLoader(size: 16),
                                  SizedBox(width: 8),
                                  Text('Saving...'),
                                ],
                              )
                            : Text(isEdit ? 'SAVE CHANGES' : 'CREATE TEMPLATE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Template Version History Sheet
// ─────────────────────────────────────────────────────────────
class _TemplateVersionHistorySheet extends ConsumerStatefulWidget {
  final int templateId;
  const _TemplateVersionHistorySheet({required this.templateId});

  @override
  ConsumerState<_TemplateVersionHistorySheet> createState() =>
      _TemplateVersionHistorySheetState();
}

class _TemplateVersionHistorySheetState
    extends ConsumerState<_TemplateVersionHistorySheet> {
  bool _isUploadingVersion = false;

  Future<void> _uploadNewVersion() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls'],
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    setState(() => _isUploadingVersion = true);
    try {
      final newVer = await ref
          .read(templateMutationProvider.notifier)
          .uploadTemplateVersion(widget.templateId, file);

      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'New version v$newVer uploaded successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Upload Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isUploadingVersion = false);
    }
  }

  Future<void> _downloadVersion(TemplateVersionModel version) async {
    try {
      final dirPath = await DownloadService.getDownloadDirectoryPath();
      final fileName = 'v${version.versionNumber}_${version.fileName}';
      final savePath = '$dirPath${Platform.pathSeparator}$fileName';

      await ref
          .read(templateMutationProvider.notifier)
          .downloadTemplate(widget.templateId, savePath);

      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Version ${version.versionNumber} downloaded.',
        filePath: savePath,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Download Failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templateAsync = ref.watch(templateDetailsProvider(widget.templateId));
    final currentUser = ref.watch(authProvider).asData?.value;
    final isAdmin = currentUser?.role == 'admin' || currentUser?.role == 'superadmin';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
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
                    const Icon(Icons.history_rounded, color: AppColors.primaryGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: templateAsync.maybeWhen(
                        data: (tmpl) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template Versions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              tmpl.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        orElse: () => const Text(
                          'Template Versions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),

              // Versions List
              Expanded(
                child: templateAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  ),
                  error: (e, _) => Center(
                    child: AppErrorState.fromError(
                      error: e,
                      onRetry: () => ref.invalidate(templateDetailsProvider(widget.templateId)),
                    ),
                  ),
                  data: (tmpl) {
                    final versions = tmpl.versions;
                    if (versions.isEmpty) {
                      return const Center(child: Text('No versions recorded yet.'));
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: versions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
                      ),
                      itemBuilder: (context, i) {
                        final v = versions[i];
                        final isLatest = v.isCurrent || i == 0;
                        final fileColor = FileIconHelper.getColor(v.fileName);
                        final fileIcon = FileIconHelper.getIcon(v.fileName);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: fileColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: fileColor.withValues(alpha: 0.25)),
                                ),
                                child: Icon(fileIcon, color: fileColor, size: 20),
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
                                      'Current',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            'Version ${v.versionNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    v.formattedSize,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                  if (v.uploadedByName != null)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 120),
                                      child: Text(
                                        'by ${v.uploadedByName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  if (v.createdAt != null)
                                    Text(
                                      '${v.createdAt!.month}/${v.createdAt!.day}/${v.createdAt!.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20),
                            color: AppColors.primaryGreen,
                            tooltip: 'Download Version',
                            onPressed: () => _downloadVersion(v),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Upload New Version Button at bottom (Admin only)
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingVersion ? null : _uploadNewVersion,
                    icon: _isUploadingVersion
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      _isUploadingVersion ? 'Uploading...' : 'Upload New Version',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
