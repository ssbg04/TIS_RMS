import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/report_models.dart';
import '../../../providers/reports_provider.dart';

class TransparencyBoardSection extends ConsumerStatefulWidget {
  const TransparencyBoardSection({super.key});

  @override
  ConsumerState<TransparencyBoardSection> createState() =>
      _TransparencyBoardSectionState();
}

class _TransparencyBoardSectionState
    extends ConsumerState<TransparencyBoardSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(transparencyBoardProvider);

    return asyncData.when(
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error:
          (err, _) => Container(
            padding: const EdgeInsets.all(AppSizes.p20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              'Error loading DepEd Transparency Board: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      data: (data) => _buildBoardContent(context, data),
    );
  }

  Widget _buildBoardContent(
    BuildContext context,
    TransparencyBoardData data,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner ──────────────────────────────────────────────────
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
                final isMobileHeader = headerConstraints.maxWidth < 650;
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildThemeChip('ACCESS', Colors.amber),
                          _buildThemeChip('EQUITY', Colors.lightBlueAccent),
                        ],
                      ),
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
                          _buildThemeChip('ACCESS', Colors.amber),
                          const SizedBox(width: 8),
                          _buildThemeChip('EQUITY', Colors.lightBlueAccent),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Comparative student population, mobility, and equity indicators across consecutive academic years.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Tab Bar ────────────────────────────────────────────────────────
          Container(
            color: Colors.grey.withOpacity(0.05),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGreen,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                  icon: Icon(Icons.bar_chart),
                  text: '1. ACCESS - ENROLLMENT BY SEX & YEAR',
                ),
                Tab(
                  icon: Icon(Icons.trending_down),
                  text: '2. ACCESS - DROPOUTS & TRANSFEREES',
                ),
                Tab(
                  icon: Icon(Icons.family_restroom),
                  text: '3. EQUITY - 4Ps BENEFICIARIES',
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────────
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnrollmentTab(data.years),
                _buildDropoutTransfereeTab(data.years),
                _buildEquity4PsTab(data.equity4Ps),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── TAB 1: Enrollment Comparative & Table ──────────────────────────────────
  Widget _buildEnrollmentTab(List<YearlyTransparencyItem> years) {
    if (years.isEmpty) {
      return const Center(
        child: Text('No comparative academic years found.'),
      );
    }

    // Latest year for detailed JHS/SHS sex breakdown table
    final latestYear = years.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparative Enrollment Data for Consecutive Years',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          SizedBox(
            height: 240,
            child: _buildEnrollmentGroupedBarChart(years),
          ),
          const SizedBox(height: AppSizes.p24),
          const Divider(),
          const SizedBox(height: AppSizes.p16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Key Stage 3 (JHS) & Key Stage 4 (SHS) Enrollment Breakdown (${latestYear.yearRange})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Overall Total: ${latestYear.enrollment.overallTotal.total}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          _buildEnrollmentTable(latestYear.enrollment),
        ],
      ),
    );
  }

  Widget _buildEnrollmentGroupedBarChart(
    List<YearlyTransparencyItem> years,
  ) {
    final gradeLevels = [7, 8, 9, 10, 11, 12];
    final yearColors = [
      Colors.blueGrey.shade300,
      Colors.teal.shade400,
      AppColors.primaryGreen,
    ];

    double maxVal = 10;
    for (final y in years) {
      for (final g in y.enrollment.grades) {
        if (g.total > maxVal) maxVal = g.total.toDouble();
      }
    }

    return Column(
      children: [
        // Legend
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
        const SizedBox(height: 12),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.15,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final yr = years[rodIndex % years.length].yearRange;
                    return BarTooltipItem(
                      '$yr\nGrade ${gradeLevels[group.x.toInt()]}: ${rod.toY.toInt()} enrolled',
                      const TextStyle(
                        color: Colors.white,
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
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= gradeLevels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Grade ${gradeLevels[idx]}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) {
                      if (val == 0) return const SizedBox.shrink();
                      return Text(
                        val.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
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
                    width: 14,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  );
                }).toList();

                return BarChartGroupData(x: xIdx, barRods: rods);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentTable(YearlyEnrollmentSummary summary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 550),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage / Grade Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Male',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Female',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Key Stage 3 Header
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
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
            ],
          ),
          // JHS Grades
          ...summary.grades.where((g) => g.gradeLevel <= 10).map((g) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Grade ${g.gradeLevel}'),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(g.male.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(g.female.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    g.total.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }),
          // JHS Subtotal Row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.05),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage 3 Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.jhsTotal.male.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.jhsTotal.female.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.jhsTotal.total.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          // Key Stage 4 Header
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
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
            ],
          ),
          // SHS Grades
          ...summary.grades.where((g) => g.gradeLevel > 10).map((g) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Grade ${g.gradeLevel}'),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(g.male.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(g.female.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    g.total.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }),
          // SHS Subtotal Row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.05),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Key Stage 4 Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.shsTotal.male.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.shsTotal.female.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  summary.shsTotal.total.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
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

  // ── TAB 2: Dropout & Transferee Mobility ──────────────────────────────────
  Widget _buildDropoutTransfereeTab(List<YearlyTransparencyItem> years) {
    if (years.isEmpty) {
      return const Center(
        child: Text('No comparative data found.'),
      );
    }

    final grades = [7, 8, 9, 10, 11, 12];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'DATA ON DROPOUT (For 3 Consecutive Years)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiYearGradeTable(
            years: years,
            grades: grades,
            getValue: (y, g) {
              final row = y.dropouts.grades.firstWhere(
                (item) => item.gradeLevel == g,
                orElse: () =>
                    GradeDropoutCount(gradeLevel: g, droppedCount: 0),
              );
              return row.droppedCount;
            },
            getTotal: (y) => y.dropouts.totalDropped,
            headerColor: Colors.red.withOpacity(0.08),
            totalColor: Colors.redAccent,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_outlined,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'DATA ON TRANSFEREES (For 3 Consecutive Years)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiYearGradeTable(
            years: years,
            grades: grades,
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
            headerColor: Colors.orange.withOpacity(0.1),
            totalColor: Colors.orange.shade800,
          ),
        ],
      ),
    );
  }

  Widget _buildMultiYearGradeTable({
    required List<YearlyTransparencyItem> years,
    required List<int> grades,
    required int Function(YearlyTransparencyItem year, int grade)
    getValue,
    required int Function(YearlyTransparencyItem year) getTotal,
    required Color headerColor,
    required Color totalColor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 550),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
      child: Table(
        columnWidths: {
          0: const FlexColumnWidth(2),
          for (int i = 0; i < years.length; i++)
            (i + 1): const FlexColumnWidth(1.2),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
              color: Colors.grey.withOpacity(0.08),
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
    ),
  ),
);
  }

  // ── TAB 3: Equity (4Ps Beneficiaries) ──────────────────────────────────────
  Widget _buildEquity4PsTab(Equity4PsSummary equity) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.family_restroom,
                    color: Colors.deepPurple,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EQUITY - 4Ps BENEFICIARIES DISTRIBUTION',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Overall: ${equity.total4Ps} of ${equity.totalStudents} (${equity.overallPercentage}%)',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 550),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.08),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Grade Level',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        '4Ps Learners',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Total Students',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Equity Percentage',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...equity.grades.map((g) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'Grade ${g.gradeLevel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(g.fourPsCount.toString()),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(g.totalStudents.toString()),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (g.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor:
                                    Colors.grey.withOpacity(0.15),
                                color: Colors.deepPurple,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${g.percentage}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                // Total Row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'OVERALL EQUITY TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        equity.total4Ps.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        equity.totalStudents.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${equity.overallPercentage}% of Total Population',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
  }
}
