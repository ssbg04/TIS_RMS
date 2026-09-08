import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/widgets/app_button_loader.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../providers/document_provider.dart';
import '../../../domain/entities/document_requirement_model.dart';
import '../../shared/modals/custom_modal.dart';

enum _SortMode { az, za, dueDateFirst }

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
  int _selectedFilterIndex = 0; // 0: All, 1: Mandatory, 2: Optional, 3: Inactive
  _SortMode _sortMode = _SortMode.az;

  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(requirementsSettingsProvider);
      }
    });
  }


  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DocumentRequirementModel> _applyFiltersAndSort(
    List<DocumentRequirementModel> all,
  ) {
    var result = all.where((r) {
      if (_selectedFilterIndex == 1 && !r.isMandatory) return false;
      if (_selectedFilterIndex == 2 && r.isMandatory) return false;
      if (_selectedFilterIndex == 3 && r.isEnabled) return false;

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
      case _SortMode.dueDateFirst:
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return a.name.compareTo(b.name);
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
    }

    return result;
  }

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

  void _showFormModal({DocumentRequirementModel? requirement, String? defaultCategory}) {
    showDialog(
      context: context,
      builder: (_) => RequirementFormModal(
        requirement: requirement,
        defaultCategory: defaultCategory,
      ),
    );
  }

  void _confirmDelete(List<DocumentRequirementModel> targets) {
    final isBulk = targets.length > 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isBulk ? 'Delete ${targets.length} Requirements' : 'Delete Requirement',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        content: Text(
          isBulk
              ? 'Are you sure you want to delete ${targets.length} selected requirements?'
              : 'Are you sure you want to delete "${targets.first.name}"?',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
                for (final t in targets) {
                  await ref.read(requirementMutationProvider.notifier).deleteRequirement(t.id);
                }
                if (!mounted) return;
                setState(() {
                  _selectedIds.removeAll(targets.map((t) => t.id));
                  if (_selectedIds.isEmpty) _multiSelectMode = false;
                });
                showSuccessDialog(
                  context,
                  message: isBulk ? '${targets.length} requirements deleted' : 'Requirement deleted',
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

  String _formatFileTypes(String raw) {
    final clean = raw.replaceAll(' ', '').toLowerCase();
    if (clean.contains('xls') || clean.split(',').length >= 5) return 'All Formats';
    if (clean.contains('doc')) return 'PDF, Docs';
    if (clean.contains('jpg') || clean.contains('png')) return 'PDF, Images';
    if (clean == 'pdf') return 'PDF';
    return clean.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final isWide = screenSize.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(requirementsSettingsProvider);

    final jhsList = settingsAsync.asData?.value.jhs ?? [];
    final shsList = settingsAsync.asData?.value.shs ?? [];

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (tabContext) {
          final tabController = DefaultTabController.of(tabContext);
          final currentList = tabController.index == 0 ? jhsList : shsList;
          final currentFiltered = _applyFiltersAndSort(currentList);
          final allCurrentSelected = currentFiltered.isNotEmpty &&
              currentFiltered.every((r) => _selectedIds.contains(r.id));
          final selectedTargets =
              currentList.where((r) => _selectedIds.contains(r.id)).toList();

          final bodyContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Segment / Tabs ──
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF),
                    ),
                  ),
                ),
                child: TabBar(
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Junior High School'),
                          const SizedBox(width: 8),
                          _countBadge(jhsList.length, isDark),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Senior High School'),
                          const SizedBox(width: 8),
                          _countBadge(shsList.length, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Focused Filter & Search Bar ──
              _buildControlBar(isWide, isDark, () {
                final activeCategory = tabController.index == 0 ? 'JHS' : 'SHS';
                _showFormModal(defaultCategory: activeCategory);
              }),

              // ── Multi-Select Banner (Desktop only; Android uses Contextual Action Bar) ──
              if (_multiSelectMode) ...[
                _buildMultiSelectBanner(
                  currentList,
                  isDark,
                  isAndroid,
                ),
              ],

              // ── Focused Requirements List ──
              Expanded(
                child: settingsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load requirements',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(requirementsSettingsProvider),
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                  data: (_) => TabBarView(
                    children: [
                      _buildRequirementsList(jhsList, isWide, isDark, 'JHS'),
                      _buildRequirementsList(shsList, isWide, isDark, 'SHS'),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (isAndroid) {
            return PopScope(
              canPop: !_multiSelectMode,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (_multiSelectMode) {
                  setState(() {
                    _multiSelectMode = false;
                    _selectedIds.clear();
                  });
                }
              },
              child: Scaffold(
                backgroundColor: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
                appBar: _multiSelectMode
                    ? AppBar(
                        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        leading: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Exit Selection',
                          onPressed: _toggleMultiSelect,
                        ),
                        title: Text(
                          '${_selectedIds.length} selected',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: Icon(
                              allCurrentSelected ? Icons.deselect : Icons.select_all,
                              color: Colors.white,
                            ),
                            tooltip: allCurrentSelected ? 'Unselect All' : 'Select All',
                            onPressed: () => _selectAll(currentFiltered),
                          ),
                          if (_selectedIds.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, color: Colors.white),
                              tooltip: 'Bulk Edit',
                              onPressed: () => _bulkEdit(selectedTargets),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                              tooltip: 'Delete Selected',
                              onPressed: () => _confirmDelete(selectedTargets),
                            ),
                          ],
                        ],
                      )
                    : AppBar(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        title: const Text(
                          'Document Requirements',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                            tooltip: 'Select Multiple',
                            onPressed: _toggleMultiSelect,
                          ),
                        ],
                      ),
                body: SafeArea(child: bodyContent),
                floatingActionButton: _multiSelectMode
                    ? null
                    : FloatingActionButton(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        onPressed: () {
                          final activeCategory = tabController.index == 0 ? 'JHS' : 'SHS';
                          _showFormModal(defaultCategory: activeCategory);
                        },
                        child: const Icon(Icons.add),
                      ),
              ),
            );
          }

          return CustomModal(
            title: 'Document Requirements',
            maxWidth: 840,
            content: SizedBox(
              height: screenSize.height * 0.78,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: bodyContent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _countBadge(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Control Bar (Search, Direct Filter Chips, Sort & Add)
  // ─────────────────────────────────────────────────────────
  Widget _buildControlBar(bool isWide, bool isDark, VoidCallback onAdd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // Search Input
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search requirements...',
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
              ),
              const SizedBox(width: 8),

              // Sort Mode Dropdown
              PopupMenuButton<_SortMode>(
                tooltip: 'Sort by',
                initialValue: _sortMode,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                onSelected: (mode) => setState(() => _sortMode = mode),
                itemBuilder: (_) => [
                  _sortItem(_SortMode.az, 'Name: A to Z'),
                  _sortItem(_SortMode.za, 'Name: Z to A'),
                  _sortItem(_SortMode.dueDateFirst, 'Due Date'),
                ],
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),

              if (isWide) ...[
                const SizedBox(width: 8),
                // Select button
                OutlinedButton.icon(
                  onPressed: _toggleMultiSelect,
                  icon: Icon(
                    _multiSelectMode ? Icons.check_box : Icons.checklist_rounded,
                    size: 16,
                  ),
                  label: Text(_multiSelectMode ? 'Cancel' : 'Select'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _multiSelectMode
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    side: BorderSide(
                      color: _multiSelectMode
                          ? AppColors.primaryGreen
                          : (isDark ? AppColors.darkBorder : const Color(0xFFCED4DA)),
                    ),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Add button
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Requirement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Quick Filter Segmented Chips (All / Mandatory / Optional / Inactive)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(0, 'All', isDark),
                const SizedBox(width: 6),
                _filterChip(1, 'Mandatory', isDark),
                const SizedBox(width: 6),
                _filterChip(2, 'Optional', isDark),
                const SizedBox(width: 6),
                _filterChip(3, 'Inactive', isDark),
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

  PopupMenuItem<_SortMode> _sortItem(_SortMode mode, String label) {
    final isSelected = _sortMode == mode;
    return PopupMenuItem<_SortMode>(
      value: mode,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          if (isSelected) const Icon(Icons.check, size: 16, color: AppColors.primaryGreen),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Multi-Select Banner
  // ─────────────────────────────────────────────────────────
  Widget _buildMultiSelectBanner(
    List<DocumentRequirementModel> visibleList,
    bool isDark,
    bool isAndroid,
  ) {
    if (isAndroid) return const SizedBox.shrink();

    final filtered = _applyFiltersAndSort(visibleList);
    final allSelected = filtered.isNotEmpty && filtered.every((r) => _selectedIds.contains(r.id));
    final targets = visibleList.where((r) => _selectedIds.contains(r.id)).toList();

    return Container(
      width: double.infinity,
      color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: allSelected,
              activeColor: AppColors.primaryGreen,
              onChanged: (_) => _selectAll(filtered),
            ),
            Text(
              '${_selectedIds.length} of ${filtered.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 16),
            if (_selectedIds.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () => _bulkEdit(targets),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Bulk Edit', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(targets),
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                label: const Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Cancel',
              onPressed: _toggleMultiSelect,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Focused Requirements List
  // ─────────────────────────────────────────────────────────
  Widget _buildRequirementsList(
    List<DocumentRequirementModel> rawList,
    bool isWide,
    bool isDark,
    String defaultCategory,
  ) {
    final items = _applyFiltersAndSort(rawList);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No requirements found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _selectedFilterIndex != 0
                    ? 'Try adjusting your search or filter.'
                    : 'Get started by creating your first document requirement.',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showFormModal(defaultCategory: defaultCategory),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Requirement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final req = items[index];
        final isSelected = _selectedIds.contains(req.id);

        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.15 : 0.08)
                : (isDark ? AppColors.darkSurfaceCard : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_multiSelectMode) {
                  _toggleItem(req.id);
                } else {
                  _showFormModal(requirement: req, defaultCategory: defaultCategory);
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
              child: Opacity(
                opacity: req.isEnabled ? 1.0 : 0.65,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Checkbox or Leading Icon
                      if (_multiSelectMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (_) => _toggleItem(req.id),
                          ),
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: (req.isMandatory ? AppColors.error : AppColors.primaryGreen)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            req.isMandatory ? Icons.assignment_outlined : Icons.description_outlined,
                            size: 18,
                            color: req.isMandatory ? AppColors.error : AppColors.primaryGreen,
                          ),
                        ),

                      // Document Name + Focused Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    req.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Mandatory Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: req.isMandatory
                                        ? AppColors.error.withValues(alpha: 0.1)
                                        : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    req.isMandatory ? 'Required' : 'Optional',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: req.isMandatory
                                          ? AppColors.error
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                    ),
                                  ),
                                ),

                                // Inactive Tag
                                if (!req.isEnabled) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
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

                            // Subtitle: Description snippet (if any) or format and due date
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (req.description != null && req.description!.trim().isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      req.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Format
                                Flexible(
                                  child: Text(
                                    _formatFileTypes(req.acceptedFileTypes),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                ),

                                // Due Date
                                if (req.dueDate != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.event, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${req.dueDate!.month}/${req.dueDate!.day}/${req.dueDate!.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Trailing Actions (Desktop: Switch + Edit + Delete)
                      if (isWide && !_multiSelectMode) ...[
                        const SizedBox(width: 12),
                        Tooltip(
                          message: req.isEnabled ? 'Active (Click to disable)' : 'Inactive (Click to enable)',
                          child: Switch(
                            value: req.isEnabled,
                            activeThumbColor: AppColors.primaryGreen,
                            onChanged: (val) async {
                              try {
                                await ref
                                    .read(requirementMutationProvider.notifier)
                                    .updateRequirement(req.copyWith(isEnabled: val));
                              } catch (e) {
                                if (!context.mounted) return;
                                showErrorDialog(context, 'Update Failed', e.toString());
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => _showFormModal(requirement: req, defaultCategory: defaultCategory),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete([req]),
                        ),
                      ] else ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add / Edit Form Modal (Focused & Intuitive)
// ─────────────────────────────────────────────────────────────
class RequirementFormModal extends ConsumerStatefulWidget {
  final DocumentRequirementModel? requirement;
  final String? defaultCategory;

  const RequirementFormModal({super.key, this.requirement, this.defaultCategory});

  @override
  ConsumerState<RequirementFormModal> createState() => _RequirementFormModalState();
}

class _RequirementFormModalState extends ConsumerState<RequirementFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dueDateController;

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

    if (req != null) {
      final cat = req.category.toUpperCase();
      _catJhs = cat == 'JHS' || cat == 'BOTH';
      _catShs = cat == 'SHS' || cat == 'BOTH';
    } else {
      final def = widget.defaultCategory?.toUpperCase() ?? 'JHS';
      _catJhs = def == 'JHS' || def == 'BOTH';
      _catShs = def == 'SHS' || def == 'BOTH';
    }

    _isMandatory = req?.isMandatory ?? true;
    _isEnabled = req?.isEnabled ?? true;

    String savedTypes = (req?.acceptedFileTypes ?? 'pdf,jpg,jpeg,png').replaceAll(' ', '');
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

  Future<void> _pickDueDate() async {
    DateTime initial = DateTime.now();
    if (_dueDateController.text.trim().isNotEmpty) {
      final parts = _dueDateController.text.trim().split('/');
      if (parts.length == 3) {
        initial = DateTime.tryParse('${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}') ?? DateTime.now();
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = '${picked.month}/${picked.day}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.requirement != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Requirement' : 'New Requirement',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Name
                  CustomTextField(
                    hintText: 'Requirement Name *',
                    controller: _nameController,
                    validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  CustomTextField(
                    hintText: 'Description (optional)',
                    controller: _descController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Due date with picker
                  InkWell(
                    onTap: _pickDueDate,
                    child: IgnorePointer(
                      child: CustomTextField(
                        hintText: 'Due Date (MM/DD/YYYY) - optional',
                        controller: _dueDateController,
                        prefixIcon: Icons.calendar_today,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Selection
                  const Text('Applicable Level *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _catJhs = !_catJhs),
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _catJhs,
                              activeColor: AppColors.primaryGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setState(() => _catJhs = v ?? false),
                            ),
                            const SizedBox(width: 6),
                            const Text('Junior High (JHS)', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _catShs = !_catShs),
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _catShs,
                              activeColor: AppColors.primaryGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setState(() => _catShs = v ?? false),
                            ),
                            const SizedBox(width: 6),
                            const Text('Senior High (SHS)', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_catJhs && !_catShs)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text('Select at least one level', style: TextStyle(color: AppColors.error, fontSize: 11)),
                    ),

                  const SizedBox(height: 12),

                  // Accepted Formats Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _acceptedFileTypes,
                    decoration: const InputDecoration(
                      labelText: 'Accepted Formats',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pdf', child: Text('PDF only')),
                      DropdownMenuItem(value: 'pdf,jpg,jpeg,png', child: Text('PDF, JPG, PNG')),
                      DropdownMenuItem(value: 'pdf,doc,docx', child: Text('PDF, Word')),
                      DropdownMenuItem(value: 'pdf,doc,docx,xls,xlsx', child: Text('PDF, Word, Excel')),
                      DropdownMenuItem(value: 'pdf,jpg,jpeg,png,doc,docx,xls,xlsx', child: Text('All Formats')),
                    ],
                    onChanged: (v) => setState(() => _acceptedFileTypes = v!),
                  ),

                  const SizedBox(height: 12),

                  // Mandatory Switch
                  SwitchListTile(
                    title: const Text('Mandatory Requirement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Students must upload this document', style: TextStyle(fontSize: 11.5)),
                    value: _isMandatory,
                    activeThumbColor: AppColors.error,
                    onChanged: (v) => setState(() => _isMandatory = v),
                  ),

                  // Active Switch
                  SwitchListTile(
                    title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Visible in the student portal', style: TextStyle(fontSize: 11.5)),
                    value: _isEnabled,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),

                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: isEditing ? 'UPDATE' : 'SAVE',
                          isLoading: _isLoading,
                          onPressed: _handleSubmit,
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
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_catJhs && !_catShs) return;

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
          id: (categories.length == 1) ? (widget.requirement?.id ?? 0) : 0,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          category: cat,
          isMandatory: _isMandatory,
          isEnabled: _isEnabled,
          dueDate: dueDate,
          acceptedFileTypes: _acceptedFileTypes,
          schoolLevels: 'JHS,SHS',
        );

        if (widget.requirement != null && categories.length == 1) {
          await ref.read(requirementMutationProvider.notifier).updateRequirement(requirement);
        } else {
          await ref.read(requirementMutationProvider.notifier).createRequirement(requirement);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message: widget.requirement != null ? 'Requirement updated' : 'Requirement created',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Failed to save', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Bulk Edit Modal
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulk Edit (${widget.targets.length} items)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<bool?>(
                initialValue: _isMandatory,
                decoration: const InputDecoration(labelText: 'Mandatory Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('No change')),
                  DropdownMenuItem(value: true, child: Text('Set Required')),
                  DropdownMenuItem(value: false, child: Text('Set Optional')),
                ],
                onChanged: (v) => setState(() => _isMandatory = v),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<bool?>(
                initialValue: _isEnabled,
                decoration: const InputDecoration(labelText: 'Availability', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('No change')),
                  DropdownMenuItem(value: true, child: Text('Set Active')),
                  DropdownMenuItem(value: false, child: Text('Set Inactive')),
                ],
                onChanged: (v) => setState(() => _isEnabled = v),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: (_isMandatory == null && _isEnabled == null) || _isLoading
                          ? null
                          : _handleBulkSave,
                      child: _isLoading
                          ? const AppButtonLoader(size: 16, color: Colors.white)
                          : const Text('APPLY'),
                    ),
                  ),
                ],
              ),
            ],
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
        await ref.read(requirementMutationProvider.notifier).updateRequirement(updated);
      }
      if (!mounted) return;
      widget.onDone();
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message: '${widget.targets.length} requirements updated',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Bulk update failed', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
