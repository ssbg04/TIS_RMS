import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/report_models.dart';
import '../../../providers/reports_provider.dart';

class TransparencyBoardSection extends ConsumerWidget {
  const TransparencyBoardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(transparencyBoardProvider);

    return asyncData.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(AppSizes.p20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Error loading DepEd Transparency Board: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (data) => _TransparencyBoardContent(data: data),
    );
  }
}

class _TransparencyBoardContent extends ConsumerStatefulWidget {
  final TransparencyBoardData data;
  const _TransparencyBoardContent({required this.data});

  @override
  ConsumerState<_TransparencyBoardContent> createState() => _TransparencyBoardContentState();
}

class _TransparencyBoardContentState extends ConsumerState<_TransparencyBoardContent> {
  final ScrollController _enrollmentChartScrollController = ScrollController();

  @override
  void dispose() {
    _enrollmentChartScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final academicYears = ref.watch(academicYearsProvider).asData?.value ?? [];
    final selectedYearId = ref.watch(transparencyBoardYearProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSizes.p20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.darkGreen,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusLarge),
                topRight: Radius.circular(AppSizes.radiusLarge),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isMobileHeader = headerConstraints.maxWidth < 750;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobileHeader) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.dashboard_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: AppSizes.p12),
                          const Expanded(
                            child: Text(
                              'DEPED TRANSPARENCY BOARD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (academicYears.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildYearSelector(
                          context,
                          academicYears: academicYears,
                          selectedYearId: selectedYearId,
                        ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.dashboard_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: AppSizes.p12),
                          const Expanded(
                            child: Text(
                              'DEPED TRANSPARENCY & SCHOOL PERFORMANCE BOARD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (academicYears.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            _buildYearSelector(
                              context,
                              academicYears: academicYears,
                              selectedYearId: selectedYearId,
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Track student enrollment, dropouts, transferees, and 4Ps learners across school years.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: isMobileHeader ? 12 : 13,
                        height: 1.35,
                      ),
                    ),
                    if (data.years.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Showing ${data.years.length} Consecutive Year${data.years.length > 1 ? 's' : ''}:',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          ...data.years.map((y) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'SY ${y.yearRange}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // â”€â”€ Sections stacked vertically â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.all(AppSizes.p20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Data on Enrollment ───────────────────────────
                _buildSectionHeader(
                  context,
                  icon: Icons.bar_chart,
                  label: '1. Data on Enrollment',
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: AppSizes.p16),
                _buildEnrollmentSection(context, data.years),

                const SizedBox(height: AppSizes.p32),
                Divider(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : Colors.grey)
                      .withValues(alpha: 0.25),
                ),
                const SizedBox(height: AppSizes.p24),

                // ── Section 2: Dropouts & Transferees ────────────────────────
                _buildSectionHeader(
                  context,
                  icon: Icons.trending_down,
                  label: '2. Dropouts & Transferees',
                  color: Colors.redAccent,
                ),
                const SizedBox(height: AppSizes.p16),
                _buildDropoutTransfereeSection(context, data.years),

                const SizedBox(height: AppSizes.p32),
                Divider(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : Colors.grey)
                      .withValues(alpha: 0.25),
                ),
                const SizedBox(height: AppSizes.p24),

                // ── Section 3: 4Ps Beneficiaries ─────────────────────────────
                _buildSectionHeader(
                  context,
                  icon: Icons.family_restroom,
                  label: '3. 4Ps Beneficiaries',
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: AppSizes.p16),
                _buildEquity4PsSection(context, data.years),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(
    BuildContext context, {
    required List<AcademicYear> academicYears,
    required int? selectedYearId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedYears = List<AcademicYear>.from(academicYears)
      ..sort((a, b) => b.yearRange.compareTo(a.yearRange));
    final activeAy = sortedYears
            .where((y) => y.status.toLowerCase() == 'active')
            .firstOrNull ??
        sortedYears.firstOrNull;
    final effectiveSelectedId = (selectedYearId != null &&
            sortedYears.any((y) => y.id == selectedYearId))
        ? selectedYearId
        : activeAy?.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_outlined, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          const Text(
            'Academic Year:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: effectiveSelectedId,
              isDense: true,
              dropdownColor:
                  isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
              items: sortedYears.map((ay) {
                final isActive = ay.status.toLowerCase() == 'active';
                return DropdownMenuItem<int>(
                  value: ay.id,
                  child: Text(
                    'SY ${ay.yearRange}${isActive ? ' (Active)' : ''}',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(transparencyBoardYearProvider.notifier).state = val;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared Helpers ─────────────────────────────────────────────────────────

  static Widget _buildDifferenceCell(int? diff, {required bool hasPreviousYear, required bool isDark}) {
    if (!hasPreviousYear || diff == null) {
      return Text(
        '—',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextMuted : Colors.grey,
        ),
      );
    }

    final String text = diff > 0 ? '+$diff' : '$diff';
    final Color color = diff > 0
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
        : (diff < 0
            ? (isDark ? const Color(0xFFE57373) : const Color(0xFFC62828))
            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary));

    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  static Widget _buildRemarkBadge(int? diff, {required bool hasPreviousYear, required bool isDark}) {
    if (!hasPreviousYear || diff == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
        ),
        child: Text(
          'Baseline',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
          ),
        ),
      );
    }

    if (diff > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B3828) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7),
          ),
        ),
        child: Text(
          'Increasing',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
          ),
        ),
      );
    } else if (diff < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3E1F1F) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A),
          ),
        ),
        child: Text(
          'Decreasing',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          'Maintained',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
      );
    }
  }

  static Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildTableScrollHint(
    BuildContext context, {
    String text = 'Scroll horizontally to view full table',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgColor = isDark
        ? AppColors.darkSurface2
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? AppColors.darkBorder
        : const Color(0xFFCBD5E1);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: hintColor,
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Responsive table wrapper — on wide screens it fills width naturally;
  /// on narrow screens it allows horizontal scroll with a minimum width and hint.
  static Widget _responsiveTable({
    required Widget child,
    double minWidth = 580,
  }) {
    return _StatefulResponsiveTable(
      minWidth: minWidth,
      child: child,
    );
  }

  // ── Section 1: Data on Enrollment ─────────────────────────────────────────

  Widget _buildEnrollmentSection(
    BuildContext context,
    List<YearlyTransparencyItem> years,
  ) {
    if (years.isEmpty) {
      return const Center(child: Text('No comparative academic years found.'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latestYear = years.last;
    final previousYear = years.length > 1 ? years[years.length - 2] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enrollment Trends across School Years',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.p12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            return SizedBox(
              height: isNarrow ? 400 : 360,
              child: _buildEnrollmentGroupedBarChart(context, years, isDark: isDark),
            );
          },
        ),
        const SizedBox(height: AppSizes.p24),
        const Divider(height: 1),
        const SizedBox(height: AppSizes.p16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              previousYear != null
                  ? 'Data on Enrollment (SY ${previousYear.yearRange} vs. SY ${latestYear.yearRange})'
                  : 'Data on Enrollment (SY ${latestYear.yearRange})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            Text(
              'Active SY Total: ${latestYear.enrollment.overallTotal.total}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.p12),
        _buildEnrollmentComparisonTable(
          context,
          latestYear: latestYear,
          previousYear: previousYear,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildEnrollmentGroupedBarChart(
    BuildContext context,
    List<YearlyTransparencyItem> years, {
    required bool isDark,
  }) {
    final gradeLevels = [7, 8, 9, 10, 11, 12];
    final yearColors = [
      Colors.blueGrey.shade400,
      Colors.teal.shade400,
      AppColors.primaryGreen,
    ];

    double maxVal = 10;
    for (final y in years) {
      for (final g in y.enrollment.grades) {
        if (g.total > maxVal) maxVal = g.total.toDouble();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minChartWidth = 720.0;
        final bool isNarrow = constraints.maxWidth < minChartWidth;
        final double chartContentWidth = isNarrow ? minChartWidth : constraints.maxWidth;

        final chartWidget = Padding(
          padding: const EdgeInsets.only(top: 16, right: 14, left: 4),
          child: SizedBox(
            width: chartContentWidth,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                groupsSpace: 24,
                maxY: (maxVal * 1.45).ceilToDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipMargin: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    getTooltipColor: (group) => isDark
                        ? AppColors.darkSurface2
                        : const Color(0xFF1E293B),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final yr = years[rodIndex % years.length].yearRange;
                      return BarTooltipItem(
                        '$yr\nGrade ${gradeLevels[group.x.toInt()]}: ${rod.toY.toInt()} enrolled',
                        TextStyle(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= gradeLevels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Grade ${gradeLevels[idx]}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            val.toInt().toString(),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: 20,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? AppColors.darkBorder
                        : Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: gradeLevels.asMap().entries.map((entry) {
                  final xIdx = entry.key;
                  final grade = entry.value;

                  final rods = years.asMap().entries.map((yEntry) {
                    final yIdx = yEntry.key;
                    final yItem = yEntry.value;
                    final gData = yItem.enrollment.grades
                        .firstWhere(
                          (g) => g.gradeLevel == grade,
                          orElse: () => GradeEnrollmentBreakdown(
                            gradeLevel: grade,
                            male: 0,
                            female: 0,
                            total: 0,
                          ),
                        );
                    return BarChartRodData(
                      toY: gData.total.toDouble(),
                      color: yearColors[yIdx % yearColors.length],
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    );
                  }).toList();

                  return BarChartGroupData(
                    x: xIdx,
                    barsSpace: 4,
                    barRods: rods,
                  );
                }).toList(),
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 6,
              children: years.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final color = yearColors[idx % yearColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.yearRange,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isNarrow
                  ? SingleChildScrollView(
                      controller: _enrollmentChartScrollController,
                      scrollDirection: Axis.horizontal,
                      child: chartWidget,
                    )
                  : chartWidget,
            ),
            if (isNarrow) ...[
              const SizedBox(height: 6),
              _CustomHorizontalScrollBar(
                controller: _enrollmentChartScrollController,
                isDark: isDark,
              ),
              _buildTableScrollHint(
                context,
                text: 'Scroll horizontally to view all grades',
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEnrollmentComparisonTable(
    BuildContext context, {
    required YearlyTransparencyItem latestYear,
    required YearlyTransparencyItem? previousYear,
    required bool isDark,
  }) {
    final hasPrev = previousYear != null;
    final prevLabel = hasPrev ? 'SY ${previousYear.yearRange}' : 'Previous SY';
    final currentLabel = 'SY ${latestYear.yearRange}';

    Widget tableWidget = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.1),
          4: FlexColumnWidth(1.4),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusMedium),
              ),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage / Grade Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  prevLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  currentLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Difference',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Remarks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),

          // ── Key Stage 3 Header ──
          TableRow(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface2
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'KEY STAGE 3 (JUNIOR HIGH SCHOOL)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
          ),

          // JHS Grades 7-10
          ...[7, 8, 9, 10].map((grade) {
            final curr = latestYear.enrollment.grades.firstWhere(
              (g) => g.gradeLevel == grade,
              orElse: () => GradeEnrollmentBreakdown(
                gradeLevel: grade,
                male: 0,
                female: 0,
                total: 0,
              ),
            ).total;

            final prev = hasPrev
                ? previousYear.enrollment.grades.firstWhere(
                    (g) => g.gradeLevel == grade,
                    orElse: () => GradeEnrollmentBreakdown(
                      gradeLevel: grade,
                      male: 0,
                      female: 0,
                      total: 0,
                    ),
                  ).total
                : null;

            final diff = hasPrev ? (curr - (prev ?? 0)) : null;

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Grade $grade'),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    hasPrev ? '$prev' : '—',
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '$curr',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: _buildDifferenceCell(diff, hasPreviousYear: hasPrev, isDark: isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Center(
                    child: _buildRemarkBadge(diff, hasPreviousYear: hasPrev, isDark: isDark),
                  ),
                ),
              ],
            );
          }),

          // JHS Subtotal Row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage 3 (JHS) Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  hasPrev ? '${previousYear.enrollment.jhsTotal.total}' : '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${latestYear.enrollment.jhsTotal.total}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: _buildDifferenceCell(
                    hasPrev
                        ? (latestYear.enrollment.jhsTotal.total -
                            previousYear.enrollment.jhsTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Center(
                  child: _buildRemarkBadge(
                    hasPrev
                        ? (latestYear.enrollment.jhsTotal.total -
                            previousYear.enrollment.jhsTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),

          // ── Key Stage 4 Header ──
          TableRow(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface2
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'KEY STAGE 4 (SENIOR HIGH SCHOOL)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
          ),

          // SHS Grades 11-12
          ...[11, 12].map((grade) {
            final curr = latestYear.enrollment.grades.firstWhere(
              (g) => g.gradeLevel == grade,
              orElse: () => GradeEnrollmentBreakdown(
                gradeLevel: grade,
                male: 0,
                female: 0,
                total: 0,
              ),
            ).total;

            final prev = hasPrev
                ? previousYear.enrollment.grades.firstWhere(
                    (g) => g.gradeLevel == grade,
                    orElse: () => GradeEnrollmentBreakdown(
                      gradeLevel: grade,
                      male: 0,
                      female: 0,
                      total: 0,
                    ),
                  ).total
                : null;

            final diff = hasPrev ? (curr - (prev ?? 0)) : null;

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Grade $grade'),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    hasPrev ? '$prev' : '—',
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '$curr',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: _buildDifferenceCell(diff, hasPreviousYear: hasPrev, isDark: isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Center(
                    child: _buildRemarkBadge(diff, hasPreviousYear: hasPrev, isDark: isDark),
                  ),
                ),
              ],
            );
          }),

          // SHS Subtotal Row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage 4 (SHS) Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  hasPrev ? '${previousYear.enrollment.shsTotal.total}' : '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${latestYear.enrollment.shsTotal.total}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: _buildDifferenceCell(
                    hasPrev
                        ? (latestYear.enrollment.shsTotal.total -
                            previousYear.enrollment.shsTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Center(
                  child: _buildRemarkBadge(
                    hasPrev
                        ? (latestYear.enrollment.shsTotal.total -
                            previousYear.enrollment.shsTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),

          // ── Overall Total Row ──
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Overall Total (JHS + SHS)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  hasPrev ? '${previousYear.enrollment.overallTotal.total}' : '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${latestYear.enrollment.overallTotal.total}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: _buildDifferenceCell(
                    hasPrev
                        ? (latestYear.enrollment.overallTotal.total -
                            previousYear.enrollment.overallTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Center(
                  child: _buildRemarkBadge(
                    hasPrev
                        ? (latestYear.enrollment.overallTotal.total -
                            previousYear.enrollment.overallTotal.total)
                        : null,
                    hasPreviousYear: hasPrev,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return _responsiveTable(child: tableWidget, minWidth: 620);
  }

  // â”€â”€ Section 2: Dropouts & Transferees â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDropoutTransfereeSection(
    BuildContext context,
    List<YearlyTransparencyItem> years,
  ) {
    if (years.isEmpty) {
      return const Center(child: Text('No comparative data found.'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grades = [7, 8, 9, 10, 11, 12];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropouts sub-section
        Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Dropouts by Grade',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMultiYearGradeTable(
          context,
          years: years,
          grades: grades,
          isDark: isDark,
          getValue: (y, g) {
            final row = y.dropouts.grades.firstWhere(
              (item) => item.gradeLevel == g,
              orElse: () => GradeDropoutCount(gradeLevel: g, droppedCount: 0),
            );
            return row.droppedCount;
          },
          getTotal: (y) => y.dropouts.totalDropped,
          headerColor: Colors.red.withValues(alpha: 0.08),
          totalColor: Colors.redAccent,
        ),
        const SizedBox(height: 28),
        // Transferees sub-section
        Row(
          children: [
            const Icon(Icons.swap_horiz_outlined, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text(
              'Transferees by Grade',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMultiYearGradeTable(
          context,
          years: years,
          grades: grades,
          isDark: isDark,
          getValue: (y, g) {
            final row = y.transferees.grades.firstWhere(
              (item) => item.gradeLevel == g,
              orElse: () => GradeTransfereeCount(
                gradeLevel: g,
                transferredCount: 0,
              ),
            );
            return row.transferredCount;
          },
          getTotal: (y) => y.transferees.totalTransferred,
          headerColor: Colors.orange.withValues(alpha: 0.1),
          totalColor: Colors.orange.shade800,
        ),
      ],
    );
  }

  Widget _buildMultiYearGradeTable(
    BuildContext context, {
    required List<YearlyTransparencyItem> years,
    required List<int> grades,
    required bool isDark,
    required int Function(YearlyTransparencyItem year, int grade) getValue,
    required int Function(YearlyTransparencyItem year) getTotal,
    required Color headerColor,
    required Color totalColor,
  }) {
    Widget tableWidget = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Table(
        columnWidths: {
          0: const FlexColumnWidth(2),
          for (int i = 0; i < years.length; i++)
            (i + 1): const FlexColumnWidth(1.2),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: headerColor),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Grade Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...years.map(
                (y) => Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    y.yearRange,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          // Grade Rows
          ...grades.map((g) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Grade $g'),
                ),
                ...years.map(
                  (y) => Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      getValue(y, g).toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }),
          // Total Row
          TableRow(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface2
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...years.map(
                (y) => Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    getTotal(y).toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: totalColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return _responsiveTable(child: tableWidget, minWidth: 580);
  }

  // ── Section 3: 4Ps Beneficiaries ──────────────────────────────────────────

  Widget _buildEquity4PsSection(
    BuildContext context,
    List<YearlyTransparencyItem> years,
  ) {
    if (years.isEmpty) {
      return const Center(child: Text('No comparative data found.'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latestYear = years.last;
    final previousYear = years.length > 1 ? years[years.length - 2] : null;
    final hasPrev = previousYear != null;
    final prevLabel = hasPrev ? 'SY ${previousYear.yearRange}' : 'Previous SY';
    final currentLabel = 'SY ${latestYear.yearRange}';

    final active4Ps = latestYear.fourPs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              previousYear != null
                  ? '4Ps Beneficiaries (SY ${previousYear.yearRange} vs. SY ${latestYear.yearRange})'
                  : '4Ps Beneficiaries (SY ${latestYear.yearRange})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            Text(
              'Active SY Total: ${active4Ps.overallTotal.fourPsCount} of ${active4Ps.overallTotal.totalStudents} (${active4Ps.overallTotal.percentage}%)',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _responsiveTable(
          minWidth: 680,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.3),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.1),
                5: FlexColumnWidth(1.4),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              children: [
                // Table Header
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusMedium),
                    ),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Key Stage / Grade Level',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        prevLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        currentLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Difference',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        '4Ps Share',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Remarks',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // ── Key Stage 3 Header ──
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : Colors.grey.withValues(alpha: 0.08),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'KEY STAGE 3 (JUNIOR HIGH SCHOOL)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                  ],
                ),

                // JHS Grades 7-10
                ...[7, 8, 9, 10].map((grade) {
                  final currRow = latestYear.fourPs.grades.firstWhere(
                    (g) => g.gradeLevel == grade,
                    orElse: () => Grade4PsCount(
                      gradeLevel: grade,
                      fourPsCount: 0,
                      totalStudents: 0,
                      percentage: 0.0,
                    ),
                  );

                  final prevRow = hasPrev
                      ? previousYear.fourPs.grades.firstWhere(
                          (g) => g.gradeLevel == grade,
                          orElse: () => Grade4PsCount(
                            gradeLevel: grade,
                            fourPsCount: 0,
                            totalStudents: 0,
                            percentage: 0.0,
                          ),
                        )
                      : null;

                  final curr = currRow.fourPsCount;
                  final prev = prevRow?.fourPsCount;
                  final diff = hasPrev ? (curr - (prev ?? 0)) : null;

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text('Grade $grade'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          hasPrev ? '$prev' : '—',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '$curr',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Center(
                          child: _buildDifferenceCell(diff, hasPreviousYear: hasPrev, isDark: isDark),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${currRow.percentage}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Center(
                          child: _buildRemarkBadge(diff, hasPreviousYear: hasPrev, isDark: isDark),
                        ),
                      ),
                    ],
                  );
                }),

                // JHS Subtotal Row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.05),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Key Stage 3 (JHS) Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        hasPrev ? '${previousYear.fourPs.jhsTotal.fourPsCount}' : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.jhsTotal.fourPsCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Center(
                        child: _buildDifferenceCell(
                          hasPrev
                              ? (latestYear.fourPs.jhsTotal.fourPsCount -
                                  previousYear.fourPs.jhsTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.jhsTotal.percentage}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Center(
                        child: _buildRemarkBadge(
                          hasPrev
                              ? (latestYear.fourPs.jhsTotal.fourPsCount -
                                  previousYear.fourPs.jhsTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Key Stage 4 Header ──
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : Colors.grey.withValues(alpha: 0.08),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'KEY STAGE 4 (SENIOR HIGH SCHOOL)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                    SizedBox.shrink(),
                  ],
                ),

                // SHS Grades 11-12
                ...[11, 12].map((grade) {
                  final currRow = latestYear.fourPs.grades.firstWhere(
                    (g) => g.gradeLevel == grade,
                    orElse: () => Grade4PsCount(
                      gradeLevel: grade,
                      fourPsCount: 0,
                      totalStudents: 0,
                      percentage: 0.0,
                    ),
                  );

                  final prevRow = hasPrev
                      ? previousYear.fourPs.grades.firstWhere(
                          (g) => g.gradeLevel == grade,
                          orElse: () => Grade4PsCount(
                            gradeLevel: grade,
                            fourPsCount: 0,
                            totalStudents: 0,
                            percentage: 0.0,
                          ),
                        )
                      : null;

                  final curr = currRow.fourPsCount;
                  final prev = prevRow?.fourPsCount;
                  final diff = hasPrev ? (curr - (prev ?? 0)) : null;

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text('Grade $grade'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          hasPrev ? '$prev' : '—',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '$curr',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Center(
                          child: _buildDifferenceCell(diff, hasPreviousYear: hasPrev, isDark: isDark),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${currRow.percentage}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Center(
                          child: _buildRemarkBadge(diff, hasPreviousYear: hasPrev, isDark: isDark),
                        ),
                      ),
                    ],
                  );
                }),

                // SHS Subtotal Row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.05),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Key Stage 4 (SHS) Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        hasPrev ? '${previousYear.fourPs.shsTotal.fourPsCount}' : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.shsTotal.fourPsCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Center(
                        child: _buildDifferenceCell(
                          hasPrev
                              ? (latestYear.fourPs.shsTotal.fourPsCount -
                                  previousYear.fourPs.shsTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.shsTotal.percentage}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Center(
                        child: _buildRemarkBadge(
                          hasPrev
                              ? (latestYear.fourPs.shsTotal.fourPsCount -
                                  previousYear.fourPs.shsTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Overall Total Row ──
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.12),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Overall Total (JHS + SHS)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        hasPrev ? '${previousYear.fourPs.overallTotal.fourPsCount}' : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.overallTotal.fourPsCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Center(
                        child: _buildDifferenceCell(
                          hasPrev
                              ? (latestYear.fourPs.overallTotal.fourPsCount -
                                  previousYear.fourPs.overallTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${latestYear.fourPs.overallTotal.percentage}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Center(
                        child: _buildRemarkBadge(
                          hasPrev
                              ? (latestYear.fourPs.overallTotal.fourPsCount -
                                  previousYear.fourPs.overallTotal.fourPsCount)
                              : null,
                          hasPreviousYear: hasPrev,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stateful Responsive Table with Dedicated Horizontal Scrollbar ───────────
class _StatefulResponsiveTable extends StatefulWidget {
  final Widget child;
  final double minWidth;

  const _StatefulResponsiveTable({
    required this.child,
    this.minWidth = 580,
  });

  @override
  State<_StatefulResponsiveTable> createState() => _StatefulResponsiveTableState();
}

class _StatefulResponsiveTableState extends State<_StatefulResponsiveTable> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.minWidth) {
          return widget.child;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: widget.minWidth),
                child: widget.child,
              ),
            ),
            const SizedBox(height: 6),
            _CustomHorizontalScrollBar(
              controller: _controller,
              isDark: isDark,
            ),
            _TransparencyBoardContentState._buildTableScrollHint(
              context,
              text: 'Scroll horizontally to view full table',
            ),
          ],
        );
      },
    );
  }
}

// ── Custom Dedicated Horizontal Scrollbar Under Graphs & Tables ──────────────
class _CustomHorizontalScrollBar extends StatefulWidget {
  final ScrollController controller;
  final bool isDark;

  const _CustomHorizontalScrollBar({
    required this.controller,
    required this.isDark,
  });

  @override
  State<_CustomHorizontalScrollBar> createState() =>
      _CustomHorizontalScrollBarState();
}

class _CustomHorizontalScrollBarState
    extends State<_CustomHorizontalScrollBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _CustomHorizontalScrollBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasClients = widget.controller.hasClients &&
            widget.controller.position.hasContentDimensions;

        if (!hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }

        final pos = hasClients ? widget.controller.position : null;
        final maxScroll = pos?.maxScrollExtent ?? 0.0;
        final currentScroll = (pos?.pixels ?? 0.0).clamp(
          0.0,
          maxScroll > 0 ? maxScroll : 1.0,
        );
        final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
        final viewportFraction = hasClients && maxScroll > 0
            ? (pos!.viewportDimension /
                    (pos.maxScrollExtent + pos.viewportDimension))
                .clamp(0.15, 0.85)
            : 0.35;

        final trackColor = widget.isDark
            ? AppColors.darkBorder.withValues(alpha: 0.7)
            : const Color(0xFFCBD5E1);
        final thumbColor = AppColors.primaryGreen;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final thumbWidth =
                  (trackWidth * viewportFraction).clamp(36.0, trackWidth);
              final maxThumbOffset =
                  (trackWidth - thumbWidth).clamp(0.0, trackWidth);
              final thumbOffset = maxThumbOffset * progress;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (!hasClients || maxThumbOffset <= 0 || maxScroll <= 0) return;
                    final deltaFraction =
                        details.primaryDelta! / maxThumbOffset;
                    final newScroll = (widget.controller.offset +
                            deltaFraction * maxScroll)
                        .clamp(0.0, maxScroll);
                    widget.controller.jumpTo(newScroll);
                  },
                  onTapDown: (details) {
                    if (!hasClients || maxThumbOffset <= 0 || maxScroll <= 0) return;
                    final localX = details.localPosition.dx;
                    final targetProgress = (localX / trackWidth).clamp(0.0, 1.0);
                    final newScroll =
                        (targetProgress * maxScroll).clamp(0.0, maxScroll);
                    widget.controller.animateTo(
                      newScroll,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Container(
                    height: 16,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track
                        Container(
                          height: 4.5,
                          width: trackWidth,
                          decoration: BoxDecoration(
                            color: trackColor,
                            borderRadius: BorderRadius.circular(2.25),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          left: thumbOffset,
                          child: Container(
                            height: 4.5,
                            width: thumbWidth,
                            decoration: BoxDecoration(
                              color: thumbColor,
                              borderRadius: BorderRadius.circular(2.25),
                              boxShadow: [
                                BoxShadow(
                                  color: thumbColor.withValues(alpha: 0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
