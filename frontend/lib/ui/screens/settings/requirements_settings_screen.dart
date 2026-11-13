import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/widgets/app_button_loader.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../providers/document_provider.dart';
import '../../../domain/entities/document_requirement_model.dart';
import '../templates/templates_screen.dart';

enum _SortMode { az, za, dueDateFirst }

class RequirementsModal extends ConsumerStatefulWidget {
  const RequirementsModal({super.key});

  static void open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RequirementsModal()));
  }

  @override
  ConsumerState<RequirementsModal> createState() => _RequirementsModalState();
}

class _RequirementsModalState extends ConsumerState<RequirementsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _lastTabIndex = 0;
  final FocusNode _searchFocusNode = FocusNode();

  int _selectedFilterIndex = 0; // 0: All, 1: Mandatory, 2: Optional, 3: Inactive
  _SortMode _sortMode = _SortMode.az;

  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(requirementsSettingsProvider);
      }
    });
  }

  void _handleTabChange() {
    if (_tabController.index != _lastTabIndex) {
      _lastTabIndex = _tabController.index;
      setState(() {
        _multiSelectMode = false;
        _selectedIds.clear();
        _selectedFilterIndex = 0;
        _searchQuery = '';
        _searchCtrl.clear();
      });
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

    final currentList = _tabController.index == 0 ? jhsList : shsList;
    final currentFiltered = _applyFiltersAndSort(currentList);
    final allCurrentSelected = currentFiltered.isNotEmpty &&
        currentFiltered.every((r) => _selectedIds.contains(r.id));
    final selectedTargets =
        currentList.where((r) => _selectedIds.contains(r.id)).toList();

    final bodyContent = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _searchFocusNode.unfocus();
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Segmented Pill Header / Tabs ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF),
                ),
              ),
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(isWide ? 'Junior High School' : 'JHS'),
                        const SizedBox(width: 8),
                        _countBadge(jhsList.length, isDark),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(isWide ? 'Senior High School' : 'SHS'),
                        const SizedBox(width: 8),
                        _countBadge(shsList.length, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Focused Filter & Search Bar ──
          _buildControlBar(isWide, isDark, () {
            final activeCategory = _tabController.index == 0 ? 'JHS' : 'SHS';
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
                child: AppErrorState.fromError(
                  error: e,
                  onRetry: () => ref.invalidate(requirementsSettingsProvider),
                ),
              ),
              data: (_) => TabBarView(
                controller: _tabController,
                children: [
                  _buildRequirementsList(jhsList, isWide, isDark, 'JHS'),
                  _buildRequirementsList(shsList, isWide, isDark, 'SHS'),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final mainScaffold = Scaffold(
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
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
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
                      isWide ? 'Document Requirements' : 'Requirements',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: isWide ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${jhsList.length + shsList.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(requirementsSettingsProvider),
                ),
                IconButton(
                  icon: Icon(
                    _multiSelectMode ? Icons.check_box : Icons.checklist_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Select Multiple',
                  onPressed: _toggleMultiSelect,
                ),
              ],
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: bodyContent,
          ),
        ),
      ),
      floatingActionButton: (!isWide && !_multiSelectMode)
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              onPressed: () {
                final activeCategory = _tabController.index == 0 ? 'JHS' : 'SHS';
                _showFormModal(defaultCategory: activeCategory);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_multiSelectMode) {
            setState(() {
              _multiSelectMode = false;
              _selectedIds.clear();
            });
          } else {
            Navigator.of(context).pop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
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
          child: mainScaffold,
        ),
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
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchFocusNode.unfocus(),
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
                // Templates button
                OutlinedButton.icon(
                  onPressed: () => TemplatesModal.open(context),
                  icon: const Icon(Icons.file_present_rounded, size: 16),
                  label: const Text('Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFCED4DA),
                    ),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 16 : 84),
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
                            // 1. Title: Full width available
                            Text(
                              req.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // 2. Badges & Tags: Wrapped to prevent horizontal squishing
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Inline Required / Optional Quick Toggle Button
                                Tooltip(
                                  message: req.isMandatory
                                      ? 'Required document — tap to switch to Optional'
                                      : 'Optional document — tap to switch to Required',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        try {
                                          await ref
                                              .read(requirementMutationProvider.notifier)
                                              .updateRequirement(
                                                req.copyWith(isMandatory: !req.isMandatory),
                                              );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          showErrorDialog(
                                            context,
                                            'Update Failed',
                                            e.toString(),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: req.isMandatory
                                              ? AppColors.error.withValues(
                                                  alpha: isDark ? 0.22 : 0.12,
                                                )
                                              : (isDark
                                                  ? AppColors.darkSurface2
                                                  : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: req.isMandatory
                                                ? AppColors.error.withValues(alpha: 0.45)
                                                : (isDark
                                                    ? AppColors.darkBorder
                                                    : Colors.grey.shade400),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (req.isMandatory
                                                      ? AppColors.error
                                                      : Colors.black)
                                                  .withValues(alpha: isDark ? 0.15 : 0.06),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              req.isMandatory
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              size: 13,
                                              color: req.isMandatory
                                                  ? AppColors.error
                                                  : (isDark
                                                      ? AppColors.darkTextSecondary
                                                      : AppColors.textSecondary),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              req.isMandatory ? 'Required' : 'Optional',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: req.isMandatory
                                                    ? AppColors.error
                                                    : (isDark
                                                        ? AppColors.darkTextSecondary
                                                        : AppColors.textSecondary),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.swap_horiz_rounded,
                                              size: 12,
                                              color: (req.isMandatory
                                                      ? AppColors.error
                                                      : (isDark
                                                          ? AppColors.darkTextSecondary
                                                          : AppColors.textSecondary))
                                                  .withValues(alpha: 0.75),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Max Files Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5)),
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
                                        Icons.file_copy_outlined,
                                        size: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        req.maxFiles == 1 ? '1 file' : 'Max: ${req.maxFiles} files',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // File Format Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5)),
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
                                        Icons.description_outlined,
                                        size: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatFileTypes(req.acceptedFileTypes),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Due Date
                                if (req.dueDate != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5)),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.event, size: 11, color: Colors.grey.shade500),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${req.dueDate!.month}/${req.dueDate!.day}/${req.dueDate!.year}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Inactive Tag
                                if (!req.isEnabled) ...[
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

                            // 3. Description snippet (if any)
                            if (req.description != null && req.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                req.description!,
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

                      // Trailing Actions
                      if (!_multiSelectMode) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 0.82,
                              child: Tooltip(
                                message: req.isEnabled ? 'Active (Click to disable)' : 'Inactive (Click to enable)',
                                child: Switch(
                                  value: req.isEnabled,
                                  activeThumbColor: AppColors.primaryGreen,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            ),
                            if (isWide) ...[
                              const SizedBox(width: 4),
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
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                                  onSelected: (val) {
                                    if (val == 'select') {
                                      setState(() {
                                        _multiSelectMode = true;
                                        _selectedIds.add(req.id);
                                      });
                                    } else if (val == 'edit') {
                                      _showFormModal(requirement: req, defaultCategory: defaultCategory);
                                    } else if (val == 'delete') {
                                      _confirmDelete([req]);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'select',
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_box_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Select'),
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
                                ),
                              ),
                            ],
                          ],
                        ),
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
  late int _maxFiles;

  DocumentRequirementModel? _counterpart;
  bool _syncCounterpart = false;

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
      _catJhs = cat == 'JHS';
      _catShs = cat == 'SHS';
      final settings = ref.read(requirementsSettingsProvider).asData?.value;
      if (settings != null) {
        final otherList = (cat == 'JHS') ? settings.shs : settings.jhs;
        for (final r in otherList) {
          if (r.name.trim().toLowerCase() == req.name.trim().toLowerCase()) {
            _counterpart = r;
            _syncCounterpart = true;
            break;
          }
        }
      }
    } else {
      final def = widget.defaultCategory?.toUpperCase() ?? 'JHS';
      _catJhs = def == 'JHS' || def == 'BOTH';
      _catShs = def == 'SHS' || def == 'BOTH';
    }

    _isMandatory = req?.isMandatory ?? true;
    _isEnabled = req?.isEnabled ?? true;
    _maxFiles = req?.maxFiles ?? 1;

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

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChoiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.1)
              : (isDark ? AppColors.darkSurface2 : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (isDark ? Colors.white : AppColors.primaryGreen)
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: selected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.requirement != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_document : Icons.post_add_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Requirement' : 'New Requirement',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing
                              ? 'Update document details, upload limits, and status'
                              : 'Define a new document requirement for students',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey.shade600,
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
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),

            // ── Scrollable Body ──
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Basic Details
                      _buildSectionHeader(
                        'Basic Details',
                        Icons.description_outlined,
                        isDark,
                      ),
                      CustomTextField(
                        hintText: 'Requirement Name *',
                        prefixIcon: Icons.badge_outlined,
                        controller: _nameController,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        hintText: 'Description (optional)',
                        prefixIcon: Icons.notes_rounded,
                        controller: _descController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDueDate,
                              borderRadius: BorderRadius.circular(10),
                              child: IgnorePointer(
                                child: CustomTextField(
                                  hintText: 'Due Date (MM/DD/YYYY) - optional',
                                  controller: _dueDateController,
                                  prefixIcon: Icons.calendar_today_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_dueDateController.text.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Clear Due Date',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _dueDateController.clear()),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 2. Target Level & Upload Rules
                      _buildSectionHeader(
                        'Level & Upload Rules',
                        Icons.tune_rounded,
                        isDark,
                      ),
                      if (isEditing) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface2
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.requirement!.category.toUpperCase() == 'JHS'
                                    ? Icons.school_outlined
                                    : Icons.account_balance_outlined,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.requirement!.category.toUpperCase() == 'JHS'
                                      ? 'Junior High School (JHS)'
                                      : 'Senior High School (SHS)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_counterpart != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () =>
                                setState(() => _syncCounterpart = !_syncCounterpart),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _syncCounterpart
                                    ? AppColors.primaryGreen.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _syncCounterpart
                                      ? AppColors.primaryGreen.withValues(alpha: 0.4)
                                      : (isDark
                                          ? AppColors.darkBorder
                                          : Colors.grey.shade300),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _syncCounterpart,
                                      activeColor: AppColors.primaryGreen,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      onChanged: (v) => setState(
                                        () => _syncCounterpart = v ?? false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sync changes to matching ${widget.requirement!.category.toUpperCase() == 'JHS' ? 'SHS' : 'JHS'} requirement',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildLevelChoiceChip(
                                label: 'Junior High (JHS)',
                                icon: Icons.school_outlined,
                                selected: _catJhs,
                                isDark: isDark,
                                onTap: () => setState(() => _catJhs = !_catJhs),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildLevelChoiceChip(
                                label: 'Senior High (SHS)',
                                icon: Icons.account_balance_outlined,
                                selected: _catShs,
                                isDark: isDark,
                                onTap: () => setState(() => _catShs = !_catShs),
                              ),
                            ),
                          ],
                        ),
                        if (!_catJhs && !_catShs)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              'Select at least one level',
                              style: TextStyle(color: AppColors.error, fontSize: 11),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _acceptedFileTypes,
                        decoration: InputDecoration(
                          labelText: 'Accepted Formats',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pdf', child: Text('PDF only')),
                          DropdownMenuItem(
                            value: 'pdf,jpg,jpeg,png',
                            child: Text('PDF, JPG, PNG'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,doc,docx',
                            child: Text('PDF, Word'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,doc,docx,xls,xlsx',
                            child: Text('PDF, Word, Excel'),
                          ),
                          DropdownMenuItem(
                            value: 'pdf,jpg,jpeg,png,doc,docx,xls,xlsx',
                            child: Text('All Formats'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _acceptedFileTypes = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _maxFiles,
                        decoration: InputDecoration(
                          labelText: 'Maximum Files Allowed',
                          helperText: 'Max files per student for this requirement',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [1, 2, 3, 4, 5, 10, 15, 20].map((n) {
                          return DropdownMenuItem<int>(
                            value: n,
                            child: Text(n == 1 ? '1 file (Single upload)' : '$n files'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _maxFiles = v ?? 1),
                      ),

                      const SizedBox(height: 18),

                      // 3. Status & Enforcement
                      _buildSectionHeader(
                        'Status & Enforcement',
                        Icons.verified_user_outlined,
                        isDark,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface2
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              dense: true,
                              title: const Text(
                                'Mandatory Requirement',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: const Text(
                                'Students must upload this document',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              value: _isMandatory,
                              activeThumbColor: AppColors.error,
                              onChanged: (v) => setState(() => _isMandatory = v),
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade200,
                            ),
                            SwitchListTile(
                              dense: true,
                              title: const Text(
                                'Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: const Text(
                                'Visible in the student portal',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              value: _isEnabled,
                              activeThumbColor: AppColors.primaryGreen,
                              onChanged: (v) => setState(() => _isEnabled = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Footer ──
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.requirement == null && !_catJhs && !_catShs) return;

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

      if (widget.requirement != null) {
        final updated = DocumentRequirementModel(
          id: widget.requirement!.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          category: widget.requirement!.category,
          isMandatory: _isMandatory,
          isEnabled: _isEnabled,
          dueDate: dueDate,
          acceptedFileTypes: _acceptedFileTypes,
          schoolLevels: widget.requirement!.schoolLevels,
          maxFiles: _maxFiles,
        );

        await ref.read(requirementMutationProvider.notifier).updateRequirement(updated);

        if (_syncCounterpart && _counterpart != null) {
          final updatedCounterpart = DocumentRequirementModel(
            id: _counterpart!.id,
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            category: _counterpart!.category,
            isMandatory: _isMandatory,
            isEnabled: _isEnabled,
            dueDate: dueDate,
            acceptedFileTypes: _acceptedFileTypes,
            schoolLevels: _counterpart!.schoolLevels,
            maxFiles: _maxFiles,
          );
          await ref.read(requirementMutationProvider.notifier).updateRequirement(updatedCounterpart);
        }
      } else {
        final categories = <String>[];
        if (_catJhs) categories.add('JHS');
        if (_catShs) categories.add('SHS');

        for (final cat in categories) {
          final requirement = DocumentRequirementModel(
            id: 0,
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            category: cat,
            isMandatory: _isMandatory,
            isEnabled: _isEnabled,
            dueDate: dueDate,
            acceptedFileTypes: _acceptedFileTypes,
            schoolLevels: 'JHS,SHS',
            maxFiles: _maxFiles,
          );
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
