import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../../domain/entities/dashboard_models.dart';

// ──────────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ──────────────────────────────────────────────────────────────
class DashboardKpisSection extends ConsumerWidget {
  const DashboardKpisSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isTeacher = user?.role == 'teacher';
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return kpisAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _KpiSkeleton(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'KPI data unavailable: $e',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ),
      data: (kpis) => _KpisContent(
        kpis: kpis,
        isWide: isWide,
        isTeacher: isTeacher,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CONTENT
// ──────────────────────────────────────────────────────────────
class _KpisContent extends StatelessWidget {
  final DashboardKpis kpis;
  final bool isWide;
  final bool isTeacher;

  const _KpisContent({
    required this.kpis,
    required this.isWide,
    this.isTeacher = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isTeacher) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StudentDocCard(
                    title: 'Top Students by Documents',
                    icon: Icons.emoji_events_rounded,
                    iconColor: Colors.amber.shade700,
                    students: kpis.topStudents,
                    isTop: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StudentDocCard(
                    title: 'Needs Attention',
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.orange,
                    students: kpis.bottomStudents,
                    isTop: false,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _StudentDocCard(
                  title: 'Top Students by Documents',
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.amber.shade700,
                  students: kpis.topStudents,
                  isTop: true,
                ),
                const SizedBox(height: 16),
                _StudentDocCard(
                  title: 'Needs Attention',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange,
                  students: kpis.bottomStudents,
                  isTop: false,
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Analytics & KPIs',
          icon: Icons.insights_rounded,
          activeYear: kpis.activeAcademicYear,
        ),
        const SizedBox(height: 16),

        // Row 1: Digitalization donuts + Activity bar
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DigitalizationCard(data: kpis.digitalization)),
              const SizedBox(width: 16),
              Expanded(child: _ActivityBarCard(entries: kpis.activityByDay)),
            ],
          )
        else
          Column(
            children: [
              _DigitalizationCard(data: kpis.digitalization),
              const SizedBox(height: 16),
              _ActivityBarCard(entries: kpis.activityByDay),
            ],
          ),

        const SizedBox(height: 16),

        // Row 2: Status distribution + Doc type pie
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatusDistributionCard(entries: kpis.statusDistribution)),
              const SizedBox(width: 16),
              Expanded(
                child: _DocTypePieCard(
                  entries: kpis.docTypeBreakdown,
                  docTypeByGrade: kpis.docTypeByGrade,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _StatusDistributionCard(entries: kpis.statusDistribution),
              const SizedBox(height: 16),
              _DocTypePieCard(
                entries: kpis.docTypeBreakdown,
                docTypeByGrade: kpis.docTypeByGrade,
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Upload trend line (full width)
        _UploadTrendCard(entries: kpis.uploadTrend),

        const SizedBox(height: 16),

        // Row 3: Top students + Bottom students
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StudentDocCard(
                  title: 'Top Students by Documents',
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.amber.shade700,
                  students: kpis.topStudents,
                  isTop: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StudentDocCard(
                  title: 'Needs Attention',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange,
                  students: kpis.bottomStudents,
                  isTop: false,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _StudentDocCard(
                title: 'Top Students by Documents',
                icon: Icons.emoji_events_rounded,
                iconColor: Colors.amber.shade700,
                students: kpis.topStudents,
                isTop: true,
              ),
              const SizedBox(height: 16),
              _StudentDocCard(
                title: 'Needs Attention',
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                students: kpis.bottomStudents,
                isTop: false,
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Storage analytics (full width)
        _StorageCard(analytics: kpis.storageAnalytics),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CHART CARD WRAPPER
// ──────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor = AppColors.primaryGreen,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceCard
          : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 1. DIGITALIZATION (JHS / SHS / Overall donuts)
// ──────────────────────────────────────────────────────────────
class _DigitalizationCard extends StatelessWidget {
  final DigitalizationData data;
  const _DigitalizationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Digitalization Progress',
      icon: Icons.donut_large_rounded,
      subtitle: 'Enrolled students with all mandatory requirements completed',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DonutTile(
            label: 'JHS',
            percent: data.jhs.percent,
            digitized: data.jhs.digitized,
            total: data.jhs.total,
            color: AppColors.primaryGreen,
          ),
          _DonutTile(
            label: 'SHS',
            percent: data.shs.percent,
            digitized: data.shs.digitized,
            total: data.shs.total,
            color: Colors.blue.shade700,
          ),
          _DonutTile(
            label: 'Overall',
            percent: data.overall.percent,
            digitized: data.overall.digitized,
            total: data.overall.total,
            color: Colors.purple.shade600,
          ),
        ],
      ),
    );
  }
}

class _DonutTile extends StatelessWidget {
  final String label;
  final double percent;
  final int digitized;
  final int total;
  final Color color;

  const _DonutTile({
    required this.label,
    required this.percent,
    required this.digitized,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pctInt = (percent * 100).toInt();
    return Column(
      children: [
        SizedBox(
          height: 80,
          width: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 28,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      value: digitized.toDouble(),
                      color: color,
                      radius: 12,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: max(0, total - digitized).toDouble(),
                      color: color.withValues(alpha: 0.12),
                      radius: 12,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Text(
                '$pctInt%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          '$digitized / $total',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 2. ACTIVITY BAR CHART (last 7 days)
// ──────────────────────────────────────────────────────────────
class _ActivityBarCard extends StatelessWidget {
  final List<ActivityByDayEntry> entries;
  const _ActivityBarCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, int>> byDay = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay[key] = {'uploads': 0, 'deletes': 0, 'updates': 0};
    }
    for (final e in entries) {
      if (!byDay.containsKey(e.day)) continue;
      if (e.action == 'CREATE') {
        byDay[e.day]!['uploads'] = (byDay[e.day]!['uploads'] ?? 0) + e.count;
      } else if (e.action == 'DELETE') {
        byDay[e.day]!['deletes'] = (byDay[e.day]!['deletes'] ?? 0) + e.count;
      } else {
        byDay[e.day]!['updates'] = (byDay[e.day]!['updates'] ?? 0) + e.count;
      }
    }

    final days = byDay.keys.toList();
    double maxY = 1;
    for (final v in byDay.values) {
      final total = (v['uploads']! + v['deletes']! + v['updates']!).toDouble();
      if (total > maxY) maxY = total;
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < days.length; i++) {
      final v = byDay[days[i]]!;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v['uploads']!.toDouble(),
            color: AppColors.primaryGreen,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: v['deletes']!.toDouble(),
            color: Colors.red.shade400,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: v['updates']!.toDouble(),
            color: Colors.blue.shade400,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
    }

    return _ChartCard(
      title: 'Recent Activities',
      icon: Icons.bar_chart_rounded,
      iconColor: Colors.blue.shade600,
      subtitle: 'Last 7 days by action type',
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = days[idx].split('-');
                        return Text(
                          '${parts[1]}/${parts[2]}',
                          style: TextStyle(
                              fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        );
                      },
                      reservedSize: 20,
                    ),
                  ),
                ),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.primaryGreen, label: 'Uploads'),
              const SizedBox(width: 12),
              _Legend(color: Colors.red.shade400, label: 'Deletes'),
              const SizedBox(width: 12),
              _Legend(color: Colors.blue.shade400, label: 'Updates'),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 3. STATUS DISTRIBUTION
// ──────────────────────────────────────────────────────────────
class _StatusDistributionCard extends StatelessWidget {
  final List<StatusDistributionEntry> entries;
  const _StatusDistributionCard({required this.entries});

  static const Map<String, Color> _colorMap = {
    'Completed': AppColors.primaryGreen,
    'Archived': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0, (sum, e) => sum + e.count);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ChartCard(
      title: 'Document Status Distribution',
      icon: Icons.pie_chart_outline_rounded,
      iconColor: Colors.orange,
      subtitle: 'By unique document types uploaded',
      child: Column(
        children: entries.map((e) {
          final pct = total == 0 ? 0.0 : e.count / total;
          final color = _colorMap[e.status] ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade500);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.status,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${e.count} (${(pct * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 4. DOCUMENT TYPE PIE WITH DROPDOWN FILTER & GRADE BREAKDOWN
// ──────────────────────────────────────────────────────────────
class _DocTypePieCard extends StatefulWidget {
  final List<DocTypeEntry> entries;
  final Map<String, List<DocTypeGradeEntry>> docTypeByGrade;

  const _DocTypePieCard({
    required this.entries,
    this.docTypeByGrade = const {},
  });

  @override
  State<_DocTypePieCard> createState() => _DocTypePieCardState();
}

class _DocTypePieCardState extends State<_DocTypePieCard> {
  String? _selectedDocType; // null = "All Document Types"
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF1C8248), Color(0xFF2196F3), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    Color(0xFFF97316), Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF6366F1),
  ];

  static const Map<String, Color> _gradeColorMap = {
    'Grade 7': Color(0xFF1C8248),
    'Grade 8': Color(0xFF2196F3),
    'Grade 9': Color(0xFFF59E0B),
    'Grade 10': Color(0xFFEF4444),
    'Grade 11': Color(0xFF8B5CF6),
    'Grade 12': Color(0xFF06B6D4),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allDocTypeNames = <String>[];
    if (widget.docTypeByGrade.isNotEmpty) {
      allDocTypeNames.addAll(widget.docTypeByGrade.keys);
    } else {
      allDocTypeNames.addAll(widget.entries.map((e) => e.name));
    }

    final jhsTypes = allDocTypeNames.where((k) => k.startsWith('JHS - ') || k.contains('(JHS)')).toList();
    final shsTypes = allDocTypeNames.where((k) => k.startsWith('SHS - ') || k.contains('(SHS)')).toList();
    final otherTypes = allDocTypeNames.where((k) => !jhsTypes.contains(k) && !shsTypes.contains(k)).toList();

    final isAll = _selectedDocType == null;

    // Data for "All Document Types"
    final allTotal = widget.entries.fold(0, (s, e) => s + e.count);

    // Data for specific doc type
    final selectedGradeList = _selectedDocType != null
        ? (widget.docTypeByGrade[_selectedDocType] ?? <DocTypeGradeEntry>[])
        : <DocTypeGradeEntry>[];
    final selectedTotalUploaded =
        selectedGradeList.fold(0, (s, g) => s + g.count);
    final selectedTotalEnrolled =
        selectedGradeList.fold(0, (s, g) => s + g.totalStudents);

    final isSelectedJhs = _selectedDocType != null && (_selectedDocType!.startsWith('JHS - ') || _selectedDocType!.contains('(JHS)'));
    final isSelectedShs = _selectedDocType != null && (_selectedDocType!.startsWith('SHS - ') || _selectedDocType!.contains('(SHS)'));
    final categoryLabel = isSelectedJhs ? 'JHS ' : (isSelectedShs ? 'SHS ' : '');

    // Build Pie Chart Sections
    final sections = <PieChartSectionData>[];
    if (isAll) {
      if (widget.entries.isEmpty) {
        sections.add(PieChartSectionData(
          value: 1,
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade300,
          radius: 50,
          showTitle: false,
        ));
      } else {
        for (int i = 0; i < widget.entries.length; i++) {
          final e = widget.entries[i];
          final color = _palette[i % _palette.length];
          final isTouched = i == _touchedIndex;
          sections.add(PieChartSectionData(
            value: e.count.toDouble(),
            color: color,
            radius: isTouched ? 70 : 60,
            showTitle: false,
          ));
        }
      }
    } else {
      if (selectedTotalUploaded == 0) {
        sections.add(PieChartSectionData(
          value: 1,
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade300,
          radius: 50,
          showTitle: false,
        ));
      } else {
        for (int i = 0; i < selectedGradeList.length; i++) {
          final g = selectedGradeList[i];
          if (g.count == 0) continue;
          final color = _gradeColorMap[g.gradeLevel] ?? _palette[i % _palette.length];
          final isTouched = i == _touchedIndex;
          sections.add(PieChartSectionData(
            value: g.count.toDouble(),
            color: color,
            radius: isTouched ? 70 : 60,
            showTitle: false,
          ));
        }
      }
    }

    final subtitle = isAll
        ? 'Top ${widget.entries.length} document types ($allTotal uploaded)'
        : '$selectedTotalUploaded / $selectedTotalEnrolled ${categoryLabel}students (${selectedTotalEnrolled == 0 ? "0.0" : (selectedTotalUploaded / selectedTotalEnrolled * 100).toStringAsFixed(1)}% complete)';

    // Build grouped dropdown menu items
    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('All Document Types', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    ];

    if (jhsTypes.isNotEmpty) {
      dropdownItems.add(
        DropdownMenuItem<String?>(
          enabled: false,
          value: '__header_jhs__',
          child: Container(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'JHS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF66BB6A) : AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Junior High School',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final name in jhsTypes) {
        final displayName = name.startsWith('JHS - ') ? name.substring(6) : name;
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: name,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }
    }

    if (shsTypes.isNotEmpty) {
      dropdownItems.add(
        DropdownMenuItem<String?>(
          enabled: false,
          value: '__header_shs__',
          child: Container(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SHS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Senior High School',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final name in shsTypes) {
        final displayName = name.startsWith('SHS - ') ? name.substring(6) : name;
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: name,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }
    }

    if (otherTypes.isNotEmpty) {
      for (final name in otherTypes) {
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: name,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return _ChartCard(
      title: 'Document Type Breakdown',
      icon: Icons.donut_small_rounded,
      iconColor: Colors.purple.shade600,
      subtitle: subtitle,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _selectedDocType,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: dropdownItems,
            selectedItemBuilder: (context) {
              return dropdownItems.map((item) {
                final val = item.value;
                if (val == null) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Document Types',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                final isJhs = val.startsWith('JHS - ');
                final isShs = val.startsWith('SHS - ');
                final cleanName = isJhs
                    ? val.substring(6)
                    : (isShs ? val.substring(6) : val);

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isJhs || isShs)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isJhs ? AppColors.primaryGreen : Colors.blue)
                                .withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isJhs ? 'JHS' : 'SHS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isJhs
                                  ? (isDark ? const Color(0xFF66BB6A) : AppColors.primaryGreen)
                                  : (isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          cleanName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            onChanged: (val) {
              if (val != null && val.startsWith('__header_')) return;
              setState(() {
                _selectedDocType = val;
                _touchedIndex = -1;
              });
            },
          ),
        ),
      ),
      child: isAll
          ? (widget.entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No document types uploaded yet.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (e, resp) {
                              setState(() {
                                _touchedIndex =
                                    resp?.touchedSection?.touchedSectionIndex ?? -1;
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: sections,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(widget.entries.length, (i) {
                          final e = widget.entries[i];
                          final pct = allTotal == 0 ? 0.0 : e.count / allTotal * 100;
                          final color = _palette[i % _palette.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration:
                                      BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${e.count} (${pct.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ))
          : (selectedGradeList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No grade level data available for this document type.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (e, resp) {
                              setState(() {
                                _touchedIndex =
                                    resp?.touchedSection?.touchedSectionIndex ?? -1;
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: sections,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(selectedGradeList.length, (i) {
                          final g = selectedGradeList[i];
                          final pct = g.totalStudents == 0
                              ? 0.0
                              : (g.count / g.totalStudents * 100);
                          final color = _gradeColorMap[g.gradeLevel] ??
                              _palette[i % _palette.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration:
                                      BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    g.gradeLevel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${g.count} / ${g.totalStudents} (${pct.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: g.count > 0
                                        ? AppColors.primaryGreen
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                )),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 5. UPLOAD TREND LINE (last 30 days)
// ──────────────────────────────────────────────────────────────
class _UploadTrendCard extends StatelessWidget {
  final List<UploadTrendEntry> entries;
  const _UploadTrendCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> byDay = {};
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay[key] = 0;
    }
    for (final e in entries) {
      byDay[e.day] = e.count;
    }

    final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].value.toDouble()));
    }
    final maxY = spots.map((s) => s.y).fold(1.0, max);

    return _ChartCard(
      title: 'Upload Trend',
      icon: Icons.show_chart_rounded,
      subtitle: 'Documents uploaded over the last 30 days',
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 7,
                  reservedSize: 20,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= sorted.length) {
                      return const SizedBox.shrink();
                    }
                    final parts = sorted[idx].key.split('-');
                    return Text(
                      '${parts[1]}/${parts[2]}',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primaryGreen,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.2),
                      AppColors.primaryGreen.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()} docs',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 6. STUDENT DOC COUNT (horizontal bars)
// ──────────────────────────────────────────────────────────────
class _StudentDocCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<StudentDocCount> students;
  final bool isTop;

  const _StudentDocCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.students,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ChartCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      subtitle: isTop
          ? 'Most required document types completed'
          : 'Most missing required document types',
      child: students.isEmpty
          ? Text(
              'No data yet.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            )
          : Column(
              children: students.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final pct = s.percent.clamp(0.0, 1.0);
                final color = isTop
                    ? Color.lerp(
                        AppColors.primaryGreen, Colors.blue.shade700, i / 5)!
                    : Colors.orange.shade400;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isTop)
                            Text(
                              '${i + 1}.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: i == 0
                                    ? Colors.amber.shade700
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                            ),
                          if (isTop) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s.uploadedCount} / ${s.totalRequired} (${s.missingCount} missing)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: s.missingCount == 0
                                  ? AppColors.primaryGreen
                                  : (isTop
                                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                                      : Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 7. STORAGE ANALYTICS
// ──────────────────────────────────────────────────────────────
class _StorageCard extends StatelessWidget {
  final StorageAnalytics analytics;
  const _StorageCard({required this.analytics});

  String _fmt(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final maxBytes = analytics.byType.isEmpty
        ? 1
        : analytics.byType.map((t) => t.bytes).reduce(max);

    final growthColor = analytics.growthRate >= 0
        ? AppColors.primaryGreen
        : Colors.red.shade500;

    return _ChartCard(
      title: 'Storage Analytics',
      icon: Icons.storage_rounded,
      iconColor: Colors.indigo.shade600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StorageStat(
                  label: 'Total Used',
                  value: _fmt(analytics.totalBytes),
                  icon: Icons.folder_rounded,
                  color: Colors.indigo.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StorageStat(
                  label: 'Total Files',
                  value: '${analytics.totalFiles}',
                  icon: Icons.insert_drive_file_rounded,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StorageStat(
                  label: '30-Day Growth',
                  value:
                      '${analytics.growthRate >= 0 ? '+' : ''}${analytics.growthRate}%',
                  icon: analytics.growthRate >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: growthColor,
                ),
              ),
            ],
          ),
          if (analytics.byType.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Storage by Document Type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            ...analytics.byType.map((t) {
              final pct = t.bytes / maxBytes;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _fmt(t.bytes),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.indigo.shade400),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StorageStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? activeYear;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.activeYear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (activeYear != null && activeYear!.trim().isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF66BB6A) : AppColors.primaryGreen,
                ),
                const SizedBox(width: 5),
                Text(
                  activeYear!.toLowerCase().contains('s.y.') || activeYear!.toLowerCase().contains('a.y.')
                      ? activeYear!
                      : 'S.Y. $activeYear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),),
      ],
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceCard
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
