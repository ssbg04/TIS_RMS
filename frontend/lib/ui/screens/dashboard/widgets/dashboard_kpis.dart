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
        const _SectionHeader(title: 'Analytics & KPIs', icon: Icons.insights_rounded),
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
              Expanded(child: _DocTypePieCard(entries: kpis.docTypeBreakdown)),
            ],
          )
        else
          Column(
            children: [
              _StatusDistributionCard(entries: kpis.statusDistribution),
              const SizedBox(height: 16),
              _DocTypePieCard(entries: kpis.docTypeBreakdown),
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

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor = AppColors.primaryGreen,
    this.subtitle,
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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                        ),
                      ),
                  ],
                ),
              ),
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
// 1. DIGITALIZATION DONUT
// ──────────────────────────────────────────────────────────────
class _DigitalizationCard extends StatelessWidget {
  final DigitalizationData data;
  const _DigitalizationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Digitalization Rate',
      icon: Icons.donut_large_rounded,
      subtitle: 'Students with at least one uploaded document',
      child: Row(
        children: [
          Expanded(child: _DonutWidget(label: 'JHS', category: data.jhs, color: AppColors.primaryGreen)),
          const SizedBox(width: 8),
          Expanded(child: _DonutWidget(label: 'SHS', category: data.shs, color: Colors.blue.shade600)),
          const SizedBox(width: 8),
          Expanded(child: _DonutWidget(label: 'Overall', category: data.overall, color: Colors.purple.shade600)),
        ],
      ),
    );
  }
}

class _DonutWidget extends StatelessWidget {
  final String label;
  final DigitalizationCategory category;
  final Color color;
  const _DonutWidget({required this.label, required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (category.percent * 100).round();
    final remaining = category.total - category.digitized;

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      value: category.digitized.toDouble().clamp(0.01, double.infinity),
                      color: color,
                      radius: 20,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: remaining.clamp(0, double.maxFinite.toInt()).toDouble().clamp(0.01, double.infinity),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurface2
                          : Colors.grey.shade200,
                      radius: 20,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          '${category.digitized}/${category.total}',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
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
                              fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
// 4. DOCUMENT TYPE PIE
// ──────────────────────────────────────────────────────────────
class _DocTypePieCard extends StatefulWidget {
  final List<DocTypeEntry> entries;
  const _DocTypePieCard({required this.entries});

  @override
  State<_DocTypePieCard> createState() => _DocTypePieCardState();
}

class _DocTypePieCardState extends State<_DocTypePieCard> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF1C8248), Color(0xFF2196F3), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    Color(0xFFF97316), Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF6366F1),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.entries.fold(0, (s, e) => s + e.count);
    final sections = <PieChartSectionData>[];

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

    return _ChartCard(
      title: 'Document Type Breakdown',
      icon: Icons.donut_small_rounded,
      iconColor: Colors.purple.shade600,
      subtitle: 'Top ${widget.entries.length} document types',
      child: Row(
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
                final pct = total == 0 ? 0.0 : e.count / total * 100;
                final color = _palette[i % _palette.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
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
    final maxCount =
        students.isEmpty ? 1 : students.map((s) => s.docCount).reduce(max);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ChartCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      child: students.isEmpty
          ? Text(
              'No data yet.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            )
          : Column(
              children: students.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final pct = maxCount == 0 ? 0.0 : s.docCount / maxCount;
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
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
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
                            '${s.docCount} docs',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
        color: isDark ? color.withOpacity(0.12) : color.withValues(alpha: 0.06),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
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
                TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),),
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
