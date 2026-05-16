import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/report_models.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/cards/stat_card.dart';
import '../../providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const ReportsScreen({super.key, required this.userRole});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  // ── Excel Export ─────────────────────────────────────────────────────────────
  Future<void> _handleExportExcel() async {
    setState(() => _isExporting = true);
    try {
      final yearId = ref.read(selectedAcademicYearIdProvider);
      final data = await ref.read(reportRepositoryProvider).getExportData(academicYearId: yearId);

      final years = ref.read(academicYearsProvider).asData?.value ?? [];
      final yearLabel = yearId != null
          ? years.firstWhere((y) => y.id == yearId, orElse: () => AcademicYear(id: 0, yearRange: 'Selected', status: '')).yearRange
          : 'All Years';

      final bytes = _buildExcel(data, yearLabel);
      final defaultFileName = 'TIS_RMS_Report_${yearLabel.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      String? savePath;

      if (Platform.isAndroid) {
        // Request permissions
        var storageStatus = await Permission.storage.status;
        var manageStatus = await Permission.manageExternalStorage.status;

        if (!storageStatus.isGranted && !manageStatus.isGranted) {
          await [Permission.storage, Permission.manageExternalStorage].request();
          storageStatus = await Permission.storage.status;
          manageStatus = await Permission.manageExternalStorage.status;
        }

        if (!storageStatus.isGranted && !manageStatus.isGranted) {
          if (!mounted) return;
          final retry = await _showPermissionDeniedDialog();
          if (retry == true) {
            await openAppSettings();
            // Ask user to confirm after returning from settings
            if (!mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirm Permission'),
                content: const Text('Did you grant the storage permission in settings?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true), 
                    child: const Text('Yes')
                  ),
                ],
              ),
            );
            
            if (confirmed == true) {
              storageStatus = await Permission.storage.status;
              manageStatus = await Permission.manageExternalStorage.status;
              if (!storageStatus.isGranted && !manageStatus.isGranted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Storage permission is still denied. Cannot export.'),
                    backgroundColor: Colors.red,
                  ));
                  setState(() => _isExporting = false);
                }
                return;
              }
            } else {
              setState(() => _isExporting = false);
              return;
            }
          } else {
            setState(() => _isExporting = false);
            return;
          }
        }

        final selectedDirectory = await FilePicker.getDirectoryPath(
          dialogTitle: 'Select folder to save report',
        );

        if (selectedDirectory == null) {
          setState(() => _isExporting = false);
          return;
        }
        savePath = '$selectedDirectory/$defaultFileName';
      } else if (Platform.isWindows) {
        savePath = await FilePicker.saveFile(
          dialogTitle: 'Save Report As...',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (savePath == null) {
          setState(() => _isExporting = false);
          return;
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = '${dir.path}/$defaultFileName';
      }

      final file = File(savePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Saved successfully: ${file.path}'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool?> _showPermissionDeniedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text('Storage permission is required to save the exported Excel file. Would you like to open app settings to grant the permission?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }


  List<int> _buildExcel(ReportExportData data, String yearLabel) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1'); // Remove default sheet

    // ── Sheet 1: Summary ────────────────────────────────────────────────────
    final summary = excel['Summary'];
    _excelTitle(summary, 'A1', 'TIAONG INTEGRATED SCHOOL — TIS RMS', 7);
    _excelTitle(summary, 'A2', 'Annual Report: $yearLabel', 7);
    _excelTitle(summary, 'A3', 'Generated: ${DateTime.now().toString().substring(0, 19)}', 7);

    summary.cell(CellIndex.indexByString('A5')).value = TextCellValue('KEY METRICS');
    _boldCell(summary, 'A5');
    _header(summary, 'A6', 'Metric'); _header(summary, 'B6', 'Value');
    final stats = [
      ['Total Students Enrolled', data.students.length.toString()],
      ['Verified Documents', data.documentStatus.verified.toString()],
      ['Pending Documents', data.documentStatus.pending.toString()],
      ['Archived Documents', data.documentStatus.archived.toString()],
    ];
    for (int i = 0; i < stats.length; i++) {
      summary.cell(CellIndex.indexByString('A${7 + i}')).value = TextCellValue(stats[i][0]);
      summary.cell(CellIndex.indexByString('B${7 + i}')).value = TextCellValue(stats[i][1]);
    }

    summary.cell(CellIndex.indexByString('A13')).value = TextCellValue('ENROLLMENT BY GRADE LEVEL');
    _boldCell(summary, 'A13');
    _header(summary, 'A14', 'Grade Level'); _header(summary, 'B14', 'Total Students');
    for (int i = 0; i < data.enrollmentByGrade.length; i++) {
      final row = data.enrollmentByGrade[i];
      summary.cell(CellIndex.indexByString('A${15 + i}')).value = TextCellValue('Grade ${row.gradeLevel}');
      summary.cell(CellIndex.indexByString('B${15 + i}')).value = IntCellValue(row.totalStudents);
    }

    summary.setColumnWidth(0, 32);
    summary.setColumnWidth(1, 20);

    // ── Sheet 2: Student List ────────────────────────────────────────────────
    final students = excel['Student List'];
    _excelTitle(students, 'A1', 'STUDENT DOCUMENT COMPLIANCE REPORT — $yearLabel', 7);
    final headers = ['#', 'LRN', 'Last Name', 'First Name', 'Sex', 'Grade Level', 'Verified Docs', 'Pending Docs', 'Status'];
    for (int c = 0; c < headers.length; c++) {
      final cell = students.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1C8248'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
    }
    for (int r = 0; r < data.students.length; r++) {
      final s = data.students[r];
      final row = [
        (r + 1).toString(),
        s.lrn,
        s.lastName,
        s.firstName,
        s.sex,
        s.gradeLevel != null ? 'Grade ${s.gradeLevel}' : 'N/A',
        s.verifiedDocs.toString(),
        s.pendingDocs.toString(),
        s.pendingDocs == 0 ? 'Complete' : 'Incomplete',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = students.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 3));
        cell.value = TextCellValue(row[c]);
        if (row[c] == 'Incomplete') {
          cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#C62828'));
        } else if (row[c] == 'Complete') {
          cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#1C8248'));
        }
      }
    }
    students.setColumnWidth(0, 6); students.setColumnWidth(1, 18);
    students.setColumnWidth(2, 20); students.setColumnWidth(3, 20);
    students.setColumnWidth(4, 8); students.setColumnWidth(5, 14);
    students.setColumnWidth(6, 15); students.setColumnWidth(7, 15);
    students.setColumnWidth(8, 12);

    return excel.encode()!;
  }

  void _excelTitle(Sheet sheet, String addr, String text, int span) {
    final cell = sheet.cell(CellIndex.indexByString(addr));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.fromHexString('#1C8248'));
  }

  void _boldCell(Sheet sheet, String addr) {
    sheet.cell(CellIndex.indexByString(addr)).cellStyle = CellStyle(bold: true, fontSize: 11);
  }

  void _header(Sheet sheet, String addr, String text) {
    final cell = sheet.cell(CellIndex.indexByString(addr));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportStatsProvider);
            ref.invalidate(enrollmentByGradeProvider);
            ref.invalidate(documentStatusProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: AppSizes.p24),
                _buildMetricsGrid(),
                const SizedBox(height: AppSizes.p24),
                LayoutBuilder(builder: (ctx, constraints) {
                  if (constraints.maxWidth > 800) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: _buildEnrollmentChart()),
                      const SizedBox(width: AppSizes.p24),
                      Expanded(flex: 2, child: _buildDocumentStatusCard()),
                    ]);
                  }
                  return Column(children: [
                    _buildEnrollmentChart(),
                    const SizedBox(height: AppSizes.p24),
                    _buildDocumentStatusCard(),
                  ]);
                }),
                const SizedBox(height: AppSizes.p48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header + Filters ──────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsProvider);
    final selectedYearId = ref.watch(selectedAcademicYearIdProvider);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Reports & Analytics',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: AppSizes.p8),
                  Text('Live data from the TIS RMS database.',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (isDesktop) ...[
              // School Year Dropdown
              yearsAsync.when(
                loading: () => const SizedBox(width: 160, child: LinearProgressIndicator()),
                error: (e, st) => const SizedBox.shrink(),
                data: (years) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedYearId,
                      hint: const Text('All Years', style: TextStyle(fontWeight: FontWeight.bold)),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Years', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...years.map((y) => DropdownMenuItem<int?>(
                          value: y.id,
                          child: Text(y.yearRange, style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                      ],
                      onChanged: (val) => ref.read(selectedAcademicYearIdProvider.notifier).select(val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p16),
              SizedBox(
                width: 190,
                child: PrimaryButton(
                  label: 'EXPORT TO EXCEL',
                  isLoading: _isExporting,
                  onPressed: _handleExportExcel,
                ),
              ),
            ],
          ],
        ),
        // Mobile controls
        if (!isDesktop) ...[
          const SizedBox(height: AppSizes.p16),
          yearsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => const SizedBox.shrink(),
            data: (years) => DropdownButtonFormField<int?>(
              initialValue: selectedYearId,
              decoration: InputDecoration(
                labelText: 'School Year',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
                ...years.map((y) => DropdownMenuItem<int?>(value: y.id, child: Text(y.yearRange))),
              ],
              onChanged: (val) => ref.read(selectedAcademicYearIdProvider.notifier).select(val),
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          PrimaryButton(label: 'EXPORT TO EXCEL', isLoading: _isExporting, onPressed: _handleExportExcel),
        ],
      ],
    );
  }

  // ── KPI Cards ────────────────────────────────────────────────────────────
  Widget _buildMetricsGrid() {
    final statsAsync = ref.watch(reportStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox(height: 110, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => _errorWidget('Failed to load stats: $err'),
      data: (stats) => LayoutBuilder(
        builder: (ctx, constraints) {
          final cols = constraints.maxWidth >= 800 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 110,
            ),
            children: [
              StatCard(title: 'Total Enrollees', value: stats.totalStudents.toString(), icon: Icons.people, iconColor: AppColors.primaryGreen),
              StatCard(title: 'Verified Documents', value: stats.verifiedDocs.toString(), icon: Icons.verified, iconColor: Colors.blue),
              StatCard(title: 'Verification Rate', value: '${stats.verificationRate}%', icon: Icons.verified_user, iconColor: Colors.teal),
              StatCard(title: 'Pending Print Queue', value: stats.printQueueCount.toString(), icon: Icons.print, iconColor: Colors.orange),
            ],
          );
        },
      ),
    );
  }

  // ── Enrollment Bar Chart ─────────────────────────────────────────────────
  Widget _buildEnrollmentChart() {
    final enrollAsync = ref.watch(enrollmentByGradeProvider);
    final selectedYearId = ref.watch(selectedAcademicYearIdProvider);
    final years = ref.watch(academicYearsProvider).asData?.value ?? [];
    final yearLabel = selectedYearId != null
        ? years.firstWhere((y) => y.id == selectedYearId, orElse: () => AcademicYear(id: 0, yearRange: 'Selected', status: '')).yearRange
        : 'All Years';

    return Container(
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enrollment by Grade Level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('School Year: $yearLabel', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSizes.p24),
          enrollAsync.when(
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => _errorWidget('$err'),
            data: (grades) {
              if (grades.isEmpty) return _emptyWidget('No enrollment data for selected year.');
              final maxCount = grades.map((g) => g.count).reduce((a, b) => a > b ? a : b);
              return SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: grades.map((grade) {
                    final pct = maxCount > 0 ? grade.count / maxCount : 0.0;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(grade.count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 12)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutQuart,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 170 * pct,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryGreen, AppColors.primaryGreen.withValues(alpha: 0.55)],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(grade.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Document Status Card ─────────────────────────────────────────────────
  Widget _buildDocumentStatusCard() {
    final docAsync = ref.watch(documentStatusProvider);
    return Container(
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Document Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Overall document verification health', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSizes.p24),
          docAsync.when(
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => _errorWidget('$err'),
            data: (doc) {
              final verRate = doc.verificationRate;
              return Column(children: [
                Center(
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 140, height: 140,
                      child: CircularProgressIndicator(
                        value: verRate,
                        strokeWidth: 14,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          verRate >= 0.8 ? AppColors.primaryGreen : verRate >= 0.5 ? Colors.orange : Colors.red,
                        ),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(verRate * 100).round()}%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      const Text('Verified', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: AppSizes.p24),
                const Divider(),
                const SizedBox(height: AppSizes.p12),
                _legendRow('Verified', AppColors.primaryGreen, doc.verified),
                const SizedBox(height: 8),
                _legendRow('Pending', Colors.orange, doc.pending),
                const SizedBox(height: 8),
                _legendRow('Draft', Colors.blue, doc.draft),
                const SizedBox(height: 8),
                _legendRow('Archived', Colors.grey, doc.archived),
              ]);
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _legendRow(String label, Color color, int count) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
      Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ],
  );

  Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
    ]),
  );

  Widget _emptyWidget(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey.shade500)),
      ]),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.surfaceWhite,
    borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
  );
}