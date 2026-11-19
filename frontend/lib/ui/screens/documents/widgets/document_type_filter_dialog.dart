import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/document_provider.dart';

class DocumentTypeFilterResult {
  final String selectedType;
  final List<String> jhsItems;
  final List<String> shsItems;

  const DocumentTypeFilterResult({
    required this.selectedType,
    required this.jhsItems,
    required this.shsItems,
  });
}

class DocumentTypeFilterDialog extends ConsumerStatefulWidget {
  final String selectedDocumentType;
  final bool isBottomSheet;

  const DocumentTypeFilterDialog({
    super.key,
    required this.selectedDocumentType,
    this.isBottomSheet = false,
  });

  static Future<DocumentTypeFilterResult?> show(
    BuildContext context, {
    required String selectedDocumentType,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (screenWidth < 600) {
      return showModalBottomSheet<DocumentTypeFilterResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
            child: DocumentTypeFilterDialog(
              selectedDocumentType: selectedDocumentType,
              isBottomSheet: true,
            ),
          ),
        ),
      );
    }

    return showDialog<DocumentTypeFilterResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: screenHeight < 600 ? 16 : 36,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: screenHeight * 0.85,
          ),
          child: DocumentTypeFilterDialog(
            selectedDocumentType: selectedDocumentType,
            isBottomSheet: false,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<DocumentTypeFilterDialog> createState() =>
      _DocumentTypeFilterDialogState();
}

class _DocumentTypeFilterDialogState
    extends ConsumerState<DocumentTypeFilterDialog> {
  final _searchController = TextEditingController();
  late String _selectedType;
  String _activeCategory = 'All';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedDocumentType;
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(realtimeDocumentTypesProvider);
      ref.invalidate(documentRequirementsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({List<String> jhs, List<String> shs, List<String> general}) _resolveLists() {
    final realtimeData = ref.watch(realtimeDocumentTypesProvider).asData?.value;
    final requirementsData =
        ref.watch(documentRequirementsProvider).asData?.value ?? const [];

    if (realtimeData != null) {
      return (
        jhs: List<String>.from(realtimeData['jhs'] ?? const []),
        shs: List<String>.from(realtimeData['shs'] ?? const []),
        general: List<String>.from(realtimeData['general'] ?? const []),
      );
    }

    final prefixRx = RegExp(r'^(JHS|SHS)\s*-\s*', caseSensitive: false);
    final jhs = requirementsData
        .where((r) => r.category == 'JHS')
        .map((r) => r.name.replaceFirst(prefixRx, ''))
        .toSet()
        .toList()
      ..sort();
    final shs = requirementsData
        .where((r) => r.category == 'SHS')
        .map((r) => r.name.replaceFirst(prefixRx, ''))
        .toSet()
        .toList()
      ..sort();
    final general = requirementsData
        .where((r) => r.category != 'JHS' && r.category != 'SHS')
        .map((r) => r.name)
        .toSet()
        .toList()
      ..sort();
    return (jhs: jhs, shs: shs, general: general);
  }

  void _resetAndPop(List<String> jhs, List<String> shs) {
    Navigator.of(context).pop(
      DocumentTypeFilterResult(
        selectedType: 'All Types',
        jhsItems: jhs,
        shsItems: shs,
      ),
    );
  }

  void _applyAndPop(List<String> jhs, List<String> shs) {
    Navigator.of(context).pop(
      DocumentTypeFilterResult(
        selectedType: _selectedType,
        jhsItems: jhs,
        shsItems: shs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final lists = _resolveLists();

    final query = _searchText.trim().toLowerCase();
    final filteredJhs = query.isEmpty
        ? lists.jhs
        : lists.jhs.where((d) => d.toLowerCase().contains(query)).toList();
    final filteredShs = query.isEmpty
        ? lists.shs
        : lists.shs.where((d) => d.toLowerCase().contains(query)).toList();
    final filteredGeneral = query.isEmpty
        ? lists.general
        : lists.general.where((d) => d.toLowerCase().contains(query)).toList();

    final showJhsSection =
        (_activeCategory == 'All' || _activeCategory == 'JHS') &&
        (filteredJhs.isNotEmpty || query.isEmpty && lists.jhs.isNotEmpty);
    final showShsSection =
        (_activeCategory == 'All' || _activeCategory == 'SHS') &&
        (filteredShs.isNotEmpty || query.isEmpty && lists.shs.isNotEmpty);
    final showGeneralSection =
        (_activeCategory == 'All' || _activeCategory == 'Other') &&
        filteredGeneral.isNotEmpty;

    final hasAnyVisibleItems =
        (_activeCategory == 'All' && query.isEmpty) ||
        (_activeCategory == 'JHS' && (query.isEmpty || filteredJhs.isNotEmpty)) ||
        (_activeCategory == 'SHS' && (query.isEmpty || filteredShs.isNotEmpty)) ||
        filteredJhs.isNotEmpty && showJhsSection ||
        filteredShs.isNotEmpty && showShsSection ||
        showGeneralSection;

    final totalCount =
        lists.jhs.length + lists.shs.length + lists.general.length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: widget.isBottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(16),
            border: !widget.isBottomSheet && isDark
                ? Border.all(color: AppColors.darkBorder)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isBottomSheet)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.isBottomSheet ? 10 : 18,
                  12,
                  14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Filter by Document Type',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: textSecondary,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),

              // Search & Category Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchText = v),
                      style: TextStyle(fontSize: 13.5, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search document type...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: textSecondary.withValues(alpha: 0.75),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: textSecondary,
                        ),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: textSecondary,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchText = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface2
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryTab('All', totalCount, isDark),
                          const SizedBox(width: 6),
                          _buildCategoryTab('JHS', lists.jhs.length, isDark),
                          const SizedBox(width: 6),
                          _buildCategoryTab('SHS', lists.shs.length, isDark),
                          if (lists.general.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildCategoryTab(
                              'Other',
                              lists.general.length,
                              isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Chips List
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_activeCategory == 'All' && query.isEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              value: 'All Types',
                              label: 'All Types',
                              isDark: isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (showJhsSection) ...[
                        _buildSectionHeader('JUNIOR HIGH SCHOOL', textSecondary),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (query.isEmpty)
                              _buildFilterChip(
                                value: 'All JHS',
                                label: 'All JHS',
                                isDark: isDark,
                              ),
                            ...filteredJhs.map(
                              (doc) => _buildFilterChip(
                                value: doc,
                                label: doc,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (showShsSection) ...[
                        _buildSectionHeader('SENIOR HIGH SCHOOL', textSecondary),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (query.isEmpty)
                              _buildFilterChip(
                                value: 'All SHS',
                                label: 'All SHS',
                                isDark: isDark,
                              ),
                            ...filteredShs.map(
                              (doc) => _buildFilterChip(
                                value: doc,
                                label: doc,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (showGeneralSection) ...[
                        _buildSectionHeader('OTHER DOCUMENTS', textSecondary),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filteredGeneral
                              .map(
                                (doc) => _buildFilterChip(
                                  value: doc,
                                  label: doc,
                                  isDark: isDark,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (!hasAnyVisibleItems)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'No document types match "$_searchText".',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Footer matching FolderFilterDialog
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                  borderRadius: widget.isBottomSheet
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _resetAndPop(lists.jhs, lists.shs),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _applyAndPop(lists.jhs, lists.shs),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Apply Filter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String category, int count, bool isDark) {
    final isSelected = _activeCategory == category;
    return InkWell(
      onTap: () => setState(() => _activeCategory = category),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.14)
              : (isDark ? AppColors.darkSurface2 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          '$category ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF76BA8A) : AppColors.primaryGreen)
                : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: textSecondary.withValues(alpha: 0.75),
      ),
    );
  }

  Widget _buildFilterChip({
    required String value,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedType == value;
    return InkWell(
      onTap: () => setState(() => _selectedType = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen
              : (isDark ? AppColors.darkSurface2 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
