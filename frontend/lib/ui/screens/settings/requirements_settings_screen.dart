import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../providers/document_provider.dart';
import '../../../domain/entities/document_requirement_model.dart';
import '../../shared/modals/custom_modal.dart';

// ─────────────────────────────────────────────────────────────
// Sort Mode Enum
// ─────────────────────────────────────────────────────────────
enum _SortMode { az, za, mandatoryFirst, dueDateFirst }

// ─────────────────────────────────────────────────────────────
// Entry point: show as dialog from settings
// ─────────────────────────────────────────────────────────────
class RequirementsModal extends ConsumerStatefulWidget {
  const RequirementsModal({super.key});

  static void open(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (isAndroid) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RequirementsModal()));
    } else {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const RequirementsModal(),
      );
    }
  }

  @override
  ConsumerState<RequirementsModal> createState() => _RequirementsModalState();
}

class _RequirementsModalState extends ConsumerState<RequirementsModal> {
  // ── Filters ──────────────────────────────────────────────
  bool? _filterMandatory; // null = all
  bool? _filterEnabled; // null = all

  // ── Sort ─────────────────────────────────────────────────
  _SortMode _sortMode = _SortMode.az;

  // ── Multi-select ─────────────────────────────────────────
  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  // ── Search ───────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Filter + Sort pipeline
  // ─────────────────────────────────────────────────────────
  List<DocumentRequirementModel> _applyFiltersAndSort(
    List<DocumentRequirementModel> all,
  ) {
    var result = all.where((r) {
      // Mandatory filter
      if (_filterMandatory != null && r.isMandatory != _filterMandatory) {
        return false;
      }

      // Enabled filter
      if (_filterEnabled != null && r.isEnabled != _filterEnabled) {
        return false;
      }

      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!r.name.toLowerCase().contains(q) &&
            !(r.description?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sortMode) {
      case _SortMode.az:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortMode.za:
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
      case _SortMode.mandatoryFirst:
        result.sort((a, b) {
          if (a.isMandatory == b.isMandatory) return a.name.compareTo(b.name);
          return a.isMandatory ? -1 : 1;
        });
        break;
      case _SortMode.dueDateFirst:
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return a.name.compareTo(b.name);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────
  // Multi-select helpers
  // ─────────────────────────────────────────────────────────
  void _toggleMultiSelect() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedIds.clear();
    });
  }

  void _toggleItem(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<DocumentRequirementModel> visible) {
    setState(() {
      if (_selectedIds.length == visible.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(visible.map((r) => r.id));
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────
  void _showDetailModal(DocumentRequirementModel req) {
    showDialog(
      context: context,
      builder: (_) => _RequirementDetailModal(
        requirement: req,
        onEdit: () {
          Navigator.pop(context);
          _showFormModal(requirement: req);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete([req]);
        },
      ),
    );
  }

  void _showFormModal({DocumentRequirementModel? requirement}) {
    showDialog(
      context: context,
      builder: (_) => RequirementFormModal(requirement: requirement),
    );
  }

  void _confirmDelete(List<DocumentRequirementModel> targets) {
    final isBulk = targets.length > 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text(
          isBulk
              ? 'Delete ${targets.length} Requirements'
              : 'Delete Requirement',
          style: const TextStyle(color: AppColors.error),
        ),
        content: Text(
          isBulk
              ? 'Are you sure you want to delete ${targets.length} selected requirements? This cannot be undone.'
              : 'Are you sure you want to delete "${targets.first.name}"?',
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
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                for (final t in targets) {
                  await ref
                      .read(requirementMutationProvider.notifier)
                      .deleteRequirement(t.id);
                }
                if (!mounted) return;
                setState(() {
                  _selectedIds.removeAll(targets.map((t) => t.id));
                  if (_selectedIds.isEmpty) _multiSelectMode = false;
                });
                showSuccessDialog(
                  context,
                  message: isBulk
                      ? '${targets.length} requirements deleted'
                      : 'Requirement deleted successfully',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Failed to delete', e.toString());
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _bulkEdit(List<DocumentRequirementModel> targets) {
    showDialog(
      context: context,
      builder: (_) => _BulkEditModal(
        targets: targets,
        onDone: () {
          setState(() {
            _selectedIds.clear();
            _multiSelectMode = false;
          });
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final settingsAsync = ref.watch(requirementsSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      children: [
        _buildSearchAndControls(isAndroid),
        _buildFilterBar(isAndroid),
        const Divider(height: 1),
        TabBar(
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          tabs: const [
            Tab(text: 'JHS'),
            Tab(text: 'SHS'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            children: [
              settingsAsync.when(
                data: (settings) {
                  final filtered = _applyFiltersAndSort(settings.jhs);
                  return _buildTable(filtered, isAndroid);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSizes.p16),
                      Text(
                        'Error: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(requirementsSettingsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              settingsAsync.when(
                data: (settings) {
                  final filtered = _applyFiltersAndSort(settings.shs);
                  return _buildTable(filtered, isAndroid);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSizes.p16),
                      Text(
                        'Error: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(requirementsSettingsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget result;
    if (isAndroid) {
      result = Scaffold(
        backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.surfaceWhite,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Document Requirements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(child: content),
        floatingActionButton: _buildFAB(context),
      );
    } else {
      result = CustomModal(
        title: 'Document Requirements',
        maxWidth: 900,
        content: SizedBox(
          height: screenSize.height * 0.8,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: content,
            floatingActionButton: _buildFAB(context),
          ),
        ),
      );
    }

    return DefaultTabController(length: 2, child: result);
  }

  // ─────────────────────────────────────────────────────────
  // Search row + sort
  // ─────────────────────────────────────────────────────────
  Widget _buildSearchAndControls(bool isNarrow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p12,
        AppSizes.p16,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search requirements…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 16,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.p8),
          // Sort menu
          PopupMenuButton<_SortMode>(
            tooltip: 'Sort',
            initialValue: _sortMode,
            onSelected: (v) => setState(() => _sortMode = v),
            itemBuilder: (_) => [
              _sortMenuItem(_SortMode.az, Icons.sort_by_alpha, 'A → Z'),
              _sortMenuItem(_SortMode.za, Icons.sort_by_alpha, 'Z → A'),
              _sortMenuItem(
                _SortMode.mandatoryFirst,
                Icons.star,
                'Mandatory first',
              ),
              _sortMenuItem(
                _SortMode.dueDateFirst,
                Icons.calendar_today,
                'Due date first',
              ),
            ],
          child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 4),
                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(
    _SortMode mode,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: _sortMode == mode
                ? AppColors.primaryGreen
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _sortMode == mode
                  ? AppColors.primaryGreen
                  : AppColors.textPrimary,
              fontWeight: _sortMode == mode
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          if (_sortMode == mode) ...[
            const Spacer(),
            const Icon(Icons.check, size: 14, color: AppColors.primaryGreen),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Filter chips bar
  // ─────────────────────────────────────────────────────────
  Widget _buildFilterBar(bool isNarrow) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p8,
        AppSizes.p16,
        AppSizes.p8,
      ),
      child: Row(
        children: [
          const Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'Filters:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.p8),

          // Mandatory
          _buildToggleChip(
            labels: const ['All', 'Mandatory', 'Optional'],
            selectedIndex: _filterMandatory == null
                ? 0
                : _filterMandatory!
                ? 1
                : 2,
            color: AppColors.error,
            onSelected: (i) => setState(() {
              _filterMandatory = i == 0 ? null : i == 1;
            }),
          ),
          const SizedBox(width: AppSizes.p12),

          const SizedBox(
            height: 16,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
            ),
          ),
          const SizedBox(width: AppSizes.p12),

          // Enabled
          _buildToggleChip(
            labels: const ['All', 'Enabled', 'Disabled'],
            selectedIndex: _filterEnabled == null
                ? 0
                : _filterEnabled!
                ? 1
                : 2,
            color: AppColors.success,
            onSelected: (i) => setState(() {
              _filterEnabled = i == 0 ? null : i == 1;
            }),
          ),

          const SizedBox(width: AppSizes.p12),
          const SizedBox(
            height: 16,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
            ),
          ),
          const SizedBox(width: AppSizes.p12),

          // Multi-select text button (no icon)
          TextButton(
            onPressed: _toggleMultiSelect,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _multiSelectMode ? 'Exit Selection' : 'Select Multiple',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _multiSelectMode ? Colors.redAccent : AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required List<String> labels,
    required int selectedIndex,
    required Color color,
    required ValueChanged<int> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final isActive = selectedIndex == i;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? color : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Table list
  // ─────────────────────────────────────────────────────────
  Widget _buildTable(List<DocumentRequirementModel> filtered, bool isNarrow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 56,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No requirements match your filters',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: AppSizes.p8),
            TextButton(
              onPressed: () => setState(() {
                _filterMandatory = null;
                _filterEnabled = null;
                _searchQuery = '';
                _searchCtrl.clear();
              }),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p8,
          ),
          child: Row(
            children: [
              if (_multiSelectMode) ...[
                SizedBox(
                  width: 36,
                  child: Checkbox(
                    value: _selectedIds.length == filtered.length,
                    tristate: true,
                    onChanged: (_) => _selectAll(filtered),
                    activeColor: AppColors.primaryGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
              Expanded(
                flex: 5,
                child: Text(
                  _multiSelectMode
                      ? '${_selectedIds.length} of ${filtered.length} selected'
                      : 'DOCUMENT NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _multiSelectMode
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (!isNarrow)
                SizedBox(
                  width: 80,
                  child: Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        // Rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filtered.length,
            separatorBuilder: (ctx, i) =>
                Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
            itemBuilder: (context, index) =>
                _buildRow(filtered[index], isNarrow),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(DocumentRequirementModel req, bool isNarrow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIds.contains(req.id);
    final catColor = req.category.toUpperCase() == 'JHS'
        ? Colors.blue
        : Colors.purple;

    return Material(
      color: isSelected
          ? AppColors.primaryGreen.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_multiSelectMode) {
            _toggleItem(req.id);
          } else {
            _showDetailModal(req);
          }
        },
        onLongPress: () {
          if (!_multiSelectMode) {
            setState(() {
              _multiSelectMode = true;
              _selectedIds.add(req.id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: 12,
          ),
          child: Row(
            children: [
              // Checkbox (multiselect)
              if (_multiSelectMode) ...[
                SizedBox(
                  width: 36,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleItem(req.id),
                    activeColor: AppColors.primaryGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],

              // Document icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: req.isMandatory
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  req.isMandatory
                      ? Icons.description
                      : Icons.description_outlined,
                  size: 18,
                  color: req.isMandatory
                      ? AppColors.error
                      : AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: AppSizes.p12),

              // Name + badges
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Category badge on narrow screens
                        if (isNarrow) ...[
                          _catBadge(req.category, catColor),
                          const SizedBox(width: 4),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: req.isMandatory
                              ? _badge(
                                  'Mandatory',
                                  AppColors.primaryGreen,
                                  key: const ValueKey('man'),
                                )
                              : _badge(
                                  'Optional',
                                  isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                                  key: const ValueKey('opt'),
                                ),
                        ),
                        if (req.isMandatory && !req.isEnabled)
                          const SizedBox(width: 4),
                        if (!req.isEnabled)
                          _badge('Disabled', isDark ? AppColors.darkTextMuted : Colors.grey.shade500),
                        if (req.dueDate != null) ...[
                          const SizedBox(width: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 10,
                                color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatDate(req.dueDate!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Category badge (wide screens)
              if (!isNarrow) ...[
                SizedBox(
                  width: 80,
                  child: Center(child: _catBadge(req.category, catColor)),
                ),
              ],

              // Chevron
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catBadge(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────────────────
  Widget _buildFAB(BuildContext context) {
    if (_multiSelectMode && _selectedIds.isNotEmpty) {
      return _buildMultiSelectBar();
    }

    return FloatingActionButton(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      tooltip: 'Add requirement',
      onPressed: () => _showFormModal(),
      child: const Icon(Icons.add, size: 28),
    );
  }

  Widget _buildMultiSelectBar() {
    final isNarrow = MediaQuery.of(context).size.width < 480;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4),
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                // Edit button (only if single selection)
                if (_selectedIds.length == 1)
                  _fabBarButton(
                    icon: Icons.edit,
                    label: 'Edit',
                    showLabel: !isNarrow,
                    color: Colors.white,
                    onTap: () {
                      final settingsAsync = ref.read(
                        requirementsSettingsProvider,
                      );
                      settingsAsync.whenData((settings) {
                        final all = [...settings.jhs, ...settings.shs];
                        final req = all.firstWhere(
                          (r) => r.id == _selectedIds.first,
                          orElse: () => all.first,
                        );
                        setState(() {
                          _selectedIds.clear();
                          _multiSelectMode = false;
                        });
                        _showFormModal(requirement: req);
                      });
                    },
                  ),
                if (_selectedIds.length > 1) ...[
                  _fabBarButton(
                    icon: Icons.edit,
                    label: 'Bulk Edit',
                    showLabel: !isNarrow,
                    color: Colors.white,
                    onTap: () {
                      final settingsAsync = ref.read(
                        requirementsSettingsProvider,
                      );
                      settingsAsync.whenData((settings) {
                        final all = [...settings.jhs, ...settings.shs];
                        final targets = all
                            .where((r) => _selectedIds.contains(r.id))
                            .toList();
                        _bulkEdit(targets);
                      });
                    },
                  ),
                ],
                const SizedBox(width: 4),
                _fabBarButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  showLabel: !isNarrow,
                  color: Colors.redAccent.shade100,
                  onTap: () {
                    final settingsAsync = ref.read(
                      requirementsSettingsProvider,
                    );
                    settingsAsync.whenData((settings) {
                      final all = [...settings.jhs, ...settings.shs];
                      final targets = all
                          .where((r) => _selectedIds.contains(r.id))
                          .toList();
                      _confirmDelete(targets);
                    });
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fabBarButton({
    required IconData icon,
    required String label,
    required bool showLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 10 : 6,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

// ─────────────────────────────────────────────────────────────
// Detail Modal — shows full info + Edit / Delete
// ─────────────────────────────────────────────────────────────
class _RequirementDetailModal extends StatelessWidget {
  final DocumentRequirementModel requirement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RequirementDetailModal({
    required this.requirement,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final req = requirement;
    final catColor = req.category.toUpperCase() == 'JHS'
        ? Colors.blue
        : Colors.purple;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.p20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLarge),
                ),
                border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: req.isMandatory
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      req.isMandatory
                          ? Icons.description
                          : Icons.description_outlined,
                      color: req.isMandatory
                          ? AppColors.error
                          : AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [_catChip(req.category, catColor)]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p20),
                child: Column(
                  children: [
                    _detailTile(
                      context,
                      Icons.notes,
                      'Description',
                      (req.description?.isNotEmpty == true)
                          ? req.description!
                          : 'No description provided',
                      valueColor: (req.description?.isNotEmpty == true)
                          ? null
                          : AppColors.textMuted,
                    ),
                    Divider(height: 20, color: isDark ? AppColors.darkBorder : null),
                    _detailTile(
                      context,
                      Icons.calendar_today,
                      'Due Date',
                      req.dueDate != null
                          ? _formatDate(req.dueDate!)
                          : 'No due date',
                      valueColor: req.dueDate != null
                          ? null
                          : AppColors.textMuted,
                    ),
                    Divider(height: 20, color: isDark ? AppColors.darkBorder : null),
                    _detailTile(
                      context,
                      Icons.attach_file,
                      'Accepted File Types',
                      req.acceptedFileTypes.replaceAll(',', ', '),
                    ),
                    Divider(height: 20, color: isDark ? AppColors.darkBorder : null),
                    Row(
                      children: [
                        Expanded(
                          child: _statusCard(
                            context,
                            label: 'Mandatory',
                            value: req.isMandatory,
                            trueLabel: 'Mandatory',
                            falseLabel: 'Optional',
                            trueColor: AppColors.error,
                            falseColor: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: _statusCard(
                            context,
                            label: 'Status',
                            value: req.isEnabled,
                            trueLabel: 'Enabled',
                            falseLabel: 'Disabled',
                            trueColor: AppColors.success,
                            falseColor: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: AppSizes.p12,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Edit',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _detailTile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required String label,
    required bool value,
    required String trueLabel,
    required String falseLabel,
    required Color trueColor,
    required Color falseColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = value ? trueColor : falseColor;
    final displayLabel = value ? trueLabel : falseLabel;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                value ? Icons.check_circle : Icons.cancel_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

// ─────────────────────────────────────────────────────────────
// Bulk Edit Modal — edit mandatory/enabled for multiple items
// ─────────────────────────────────────────────────────────────
class _BulkEditModal extends ConsumerStatefulWidget {
  final List<DocumentRequirementModel> targets;
  final VoidCallback onDone;

  const _BulkEditModal({required this.targets, required this.onDone});

  @override
  ConsumerState<_BulkEditModal> createState() => _BulkEditModalState();
}

class _BulkEditModalState extends ConsumerState<_BulkEditModal> {
  bool? _isMandatory;
  bool? _isEnabled;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isNarrow = screenSize.width < 480;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: isDark ? AppColors.darkSurfaceCard.withValues(alpha: 0.85) : AppColors.surfaceWhite.withValues(alpha: 0.85),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: AppColors.primaryGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bulk Edit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Editing ${widget.targets.length} requirements',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p20),
                    Text(
                      'Leave a field as "No change" to keep each requirement\'s current value.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),
                    _buildSelectRow(
                      label: 'Mandatory',
                      value: _isMandatory,
                      trueLabel: 'Set Mandatory',
                      falseLabel: 'Set Optional',
                      onChanged: (v) => setState(() => _isMandatory = v),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildSelectRow(
                      label: 'Enabled',
                      value: _isEnabled,
                      trueLabel: 'Set Enabled',
                      falseLabel: 'Set Disabled',
                      onChanged: (v) => setState(() => _isEnabled = v),
                    ),
                    const SizedBox(height: AppSizes.p24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                (_isMandatory == null && _isEnabled == null) ||
                                    _isLoading
                                ? null
                                : _handleBulkSave,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('APPLY'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectRow({
    required String label,
    required bool? value,
    required String trueLabel,
    required String falseLabel,
    required ValueChanged<bool?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _selectChip('No change', value == null, () => onChanged(null)),
            const SizedBox(width: 6),
            _selectChip(
              trueLabel,
              value == true,
              () => onChanged(true),
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 6),
            _selectChip(
              falseLabel,
              value == false,
              () => onChanged(false),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color color = AppColors.textMuted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurface2 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? color : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBulkSave() async {
    setState(() => _isLoading = true);
    try {
      for (final req in widget.targets) {
        final updated = req.copyWith(
          isMandatory: _isMandatory ?? req.isMandatory,
          isEnabled: _isEnabled ?? req.isEnabled,
        );
        await ref
            .read(requirementMutationProvider.notifier)
            .updateRequirement(updated);
      }
      if (!mounted) return;
      widget.onDone();
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message: '${widget.targets.length} requirements updated successfully',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Bulk update failed', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Add / Edit Form Modal
// ─────────────────────────────────────────────────────────────
class RequirementFormModal extends ConsumerStatefulWidget {
  final DocumentRequirementModel? requirement;

  const RequirementFormModal({super.key, this.requirement});

  @override
  ConsumerState<RequirementFormModal> createState() =>
      _RequirementFormModalState();
}

class _RequirementFormModalState extends ConsumerState<RequirementFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dueDateController;

  // Category — both can be checked; stored as category field
  late bool _catJhs;
  late bool _catShs;
  late bool _isMandatory;
  late bool _isEnabled;
  late String _acceptedFileTypes;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final req = widget.requirement;
    _nameController = TextEditingController(text: req?.name ?? '');
    _descController = TextEditingController(text: req?.description ?? '');
    _dueDateController = TextEditingController(
      text: req?.dueDate != null
          ? '${req!.dueDate!.month}/${req.dueDate!.day}/${req.dueDate!.year}'
          : '',
    );

    // Category checkboxes
    final cat = req?.category.toUpperCase() ?? 'JHS';
    _catJhs = cat == 'JHS' || cat == 'BOTH';
    _catShs = cat == 'SHS' || cat == 'BOTH';

    _isMandatory = req?.isMandatory ?? true;
    _isEnabled = req?.isEnabled ?? true;

    String savedTypes = (req?.acceptedFileTypes ?? 'pdf,jpg,jpeg,png')
        .replaceAll(' ', '');
    const validItems = [
      'pdf',
      'pdf,jpg,jpeg,png',
      'pdf,doc,docx',
      'pdf,doc,docx,xls,xlsx',
      'pdf,jpg,jpeg,png,doc,docx,xls,xlsx',
    ];
    if (!validItems.contains(savedTypes)) {
      savedTypes = 'pdf,jpg,jpeg,png';
    }
    _acceptedFileTypes = savedTypes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.requirement != null;
    final screenSize = MediaQuery.of(context).size;
    final isNarrow = screenSize.width < 480;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      insetPadding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p20,
                AppSizes.p16,
                AppSizes.p12,
                AppSizes.p16,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLarge),
                ),
                border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.document_scanner,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Requirement' : 'Add Requirement',
                      style: TextStyle(
                        fontSize: 16,
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
            ),

            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        hintText: 'Document Name *',
                        controller: _nameController,
                        prefixIcon: Icons.description,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: AppSizes.p16),
                      CustomTextField(
                        hintText: 'Description (optional)',
                        controller: _descController,
                        prefixIcon: Icons.notes,
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSizes.p16),
                      CustomTextField(
                        hintText: 'Due Date (MM/DD/YYYY) — optional',
                        controller: _dueDateController,
                        prefixIcon: Icons.calendar_today,
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Category checkboxes
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _buildCategoryCheckTile(
                              label: 'JHS (Junior High School)',
                              value: _catJhs,
                              color: Colors.blue,
                              onChanged: (v) => setState(() => _catJhs = v!),
                            ),
                            Divider(height: 1, color: isDark ? AppColors.darkBorder : null),
                            _buildCategoryCheckTile(
                              label: 'SHS (Senior High School)',
                              value: _catShs,
                              color: Colors.purple,
                              onChanged: (v) => setState(() => _catShs = v!),
                            ),
                          ],
                        ),
                      ),
                      if (!_catJhs && !_catShs)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            'Please select at least one category',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSizes.p16),

                      // File types dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _acceptedFileTypes,
                        decoration: InputDecoration(
                          labelText: 'Accepted File Types',
                          prefixIcon: const Icon(
                            Icons.attach_file,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pdf',
                            child: Text('PDF only'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,jpg,jpeg,png',
                            child: Text('PDF, JPG, PNG'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,doc,docx',
                            child: Text('PDF & Word'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,doc,docx,xls,xlsx',
                            child: Text('PDF, Word & Excel'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,jpg,jpeg,png,doc,docx,xls,xlsx',
                            child: Text('All Formats'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _acceptedFileTypes = v!),
                      ),
                      const SizedBox(height: AppSizes.p20),

                      // Switches
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Mandatory Requirement',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Students must upload this document',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _isMandatory,
                              onChanged: (v) =>
                                  setState(() => _isMandatory = v),
                              activeThumbColor: AppColors.error,
                            ),
                            Divider(height: 1, color: isDark ? AppColors.darkBorder : null),
                            SwitchListTile(
                              title: const Text(
                                'Enabled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Show this requirement in the system',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _isEnabled,
                              onChanged: (v) => setState(() => _isEnabled = v),
                              activeThumbColor: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: AppSizes.p12,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: PrimaryButton(
                      label: isEditing ? 'UPDATE' : 'CREATE',
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCheckTile({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: value ? color : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: color,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_catJhs && !_catShs) return; // Category validation

    setState(() => _isLoading = true);

    try {
      DateTime? dueDate;
      if (_dueDateController.text.trim().isNotEmpty) {
        final parts = _dueDateController.text.trim().split('/');
        if (parts.length == 3) {
          dueDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }

      // If both categories selected, create/update for each separately
      final categories = <String>[];
      if (_catJhs && _catShs) {
        categories.addAll(['JHS', 'SHS']);
      } else if (_catJhs) {
        categories.add('JHS');
      } else {
        categories.add('SHS');
      }

      for (final cat in categories) {
        final requirement = DocumentRequirementModel(
          id: (categories.length == 1)
              ? (widget.requirement?.id ?? 0)
              : 0, // new record for second category
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          category: cat,
          isMandatory: _isMandatory,
          isEnabled: _isEnabled,
          dueDate: dueDate,
          acceptedFileTypes: _acceptedFileTypes,
          schoolLevels: 'JHS,SHS',
        );

        if (widget.requirement != null && categories.length == 1) {
          await ref
              .read(requirementMutationProvider.notifier)
              .updateRequirement(requirement);
        } else {
          await ref
              .read(requirementMutationProvider.notifier)
              .createRequirement(requirement);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message: widget.requirement != null
            ? 'Requirement updated successfully'
            : 'Requirement created successfully',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Failed to save requirement', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
