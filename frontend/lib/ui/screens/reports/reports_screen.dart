import 'dart:io';
import 'package:excel/excel.dart' hide Border, TextSpan;
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
import '../../providers/navigation_provider.dart';
import '../../shared/dialogs/file_save_preview_dialog.dart';
import '../students/student_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const ReportsScreen({super.key, required this.userRole});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<String>? _tabListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (previous == 'Reports' || next == 'Reports') {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Excel Export ─────────────────────────────────────────────────────────────
  Future<void> _handleExportExcel(ReportStats data) async {
    setState(() => _isExporting = true);
    try {
      final yearId = ref.read(selectedAcademicYearIdProvider);
      final years     = ref.read(academicYearsProvider).asData?.value ?? [];
      final yearLabel = yearId != null
          ? years.firstWhere((y) => y.id == yearId, orElse: () => AcademicYear(id: 0, yearRange: 'Selected', status: '')).yearRange
          : 'All Years';

      // Build Excel bytes using the filtered data
      final bytes           = _buildExcel(data, yearLabel);
      final defaultFileName = 'TIS_RMS_Report_${yearLabel.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final generatedAt     = DateTime.now().toString().substring(0, 19);

      if (!mounted) return;
      setState(() => _isExporting = false);

      // Construct the sheets for the preview
      final summarySheet = SheetPreviewData(
        sheetName: 'Summary',
        headers: ['', ''],
        rows: [
          ['STUDENT STATISTICS', ''],
          ['Student Status', 'Total Count'],
          ['Active (Enrolled)', data.studentCounts.active.toString()],
          ['Dropouts (Dropped)', data.studentCounts.dropped.toString()],
          ['Transferees (Transferred)', data.studentCounts.transferee.toString()],
          ['Graduated', data.studentCounts.graduated.toString()],
          ['', ''],
          ['MISSING DOCUMENTS PER REQUIREMENT TYPE', ''],
          ['Document Type', 'Missing Count'],
          ...data.missingDocsBreakdown.map((e) => [e.name, e.count.toString()]),
        ],
      );

      final masterlistSheet = SheetPreviewData(
        sheetName: 'Student Compliance List',
        headers: ['#', 'LRN', 'Name', 'Sex', 'Grade Level', 'Section', 'Status', 'Missing Count', 'Missing Documents'],
        maxPreviewRows: 100,
        rows: data.students.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return [
            '${i + 1}',
            s.lrn,
            s.fullName,
            s.sex,
            s.gradeLevel != null ? 'Grade ${s.gradeLevel}' : 'N/A',
            s.sectionName ?? 'N/A',
            s.status,
            s.missingCount.toString(),
            s.missingRequirements ?? 'None',
          ];
        }).toList(),
      );

      // Show preview dialog before actual save
      await showFileSavePreviewDialog(
        context,
        fileName:  defaultFileName,
        fileType:  SaveFileType.excel,
        fileBytes: bytes,
        previewRows: [
          FilePreviewRow('School Year',    yearLabel),
          FilePreviewRow('Students',       data.students.length.toString()),
          FilePreviewRow('Sheets',         '2'),
          FilePreviewRow('Generated',      generatedAt),
        ],
        sheets: [summarySheet, masterlistSheet],
        onSave: (resolvedName) => _saveExcelFile(bytes, resolvedName),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
      setState(() => _isExporting = false);
    }
  }

  Future<void> _saveExcelFile(List<int> bytes, String fileName) async {
    String? savePath;

    if (Platform.isAndroid) {
      var storageStatus = await Permission.storage.status;
      var manageStatus  = await Permission.manageExternalStorage.status;

      if (!storageStatus.isGranted && !manageStatus.isGranted) {
        await [Permission.storage, Permission.manageExternalStorage].request();
        storageStatus = await Permission.storage.status;
        manageStatus  = await Permission.manageExternalStorage.status;
      }

      if (!storageStatus.isGranted && !manageStatus.isGranted) {
        if (!mounted) return;
        final retry = await _showPermissionDeniedDialog();
        if (retry == true) {
          await openAppSettings();
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
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            storageStatus = await Permission.storage.status;
            manageStatus  = await Permission.manageExternalStorage.status;
          }
          if (!storageStatus.isGranted && !manageStatus.isGranted) {
            throw Exception('Storage permission denied. Cannot save file.');
          }
        } else {
          return;
        }
      }

      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to save report',
      );
      if (selectedDirectory == null) return;
      savePath = '$selectedDirectory/$fileName';

    } else if (Platform.isWindows) {
      savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Report As...',
        fileName:    fileName,
        type:        FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;

    } else {
      final dir = await getApplicationDocumentsDirectory();
      savePath = '${dir.path}/$fileName';
    }

    final file = File(savePath);
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Saved: ${file.path}'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 5),
    ));
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

  List<int> _buildExcel(ReportStats data, String yearLabel) {
    final excel = Excel.createExcel();

    // ── Sheet 1: Summary ────────────────────────────────────────────────────
    final summary = excel['Summary'];
    _excelTitle(summary, 'A1', 'TIAONG INTEGRATED SCHOOL — TIS RMS', 7);
    _excelTitle(summary, 'A2', 'Annual Report Summary: $yearLabel', 7);
    _excelTitle(summary, 'A3', 'Generated: ${DateTime.now().toString().substring(0, 19)}', 7);

    summary.cell(CellIndex.indexByString('A5')).value = TextCellValue('STUDENT STATISTICS');
    _boldCell(summary, 'A5');
    _header(summary, 'A6', 'Student Status'); _header(summary, 'B6', 'Total Count');
    final stats = [
      ['Active (Enrolled)', data.studentCounts.active.toString()],
      ['Dropouts (Dropped)', data.studentCounts.dropped.toString()],
      ['Transferees (Transferred)', data.studentCounts.transferee.toString()],
      ['Graduated', data.studentCounts.graduated.toString()],
    ];
    for (int i = 0; i < stats.length; i++) {
      summary.cell(CellIndex.indexByString('A${7 + i}')).value = TextCellValue(stats[i][0]);
      summary.cell(CellIndex.indexByString('B${7 + i}')).value = TextCellValue(stats[i][1]);
    }

    summary.cell(CellIndex.indexByString('A13')).value = TextCellValue('MISSING DOCUMENTS PER REQUIREMENT TYPE');
    _boldCell(summary, 'A13');
    _header(summary, 'A14', 'Document Type'); _header(summary, 'B14', 'Missing Count');
    for (int i = 0; i < data.missingDocsBreakdown.length; i++) {
      final row = data.missingDocsBreakdown[i];
      summary.cell(CellIndex.indexByString('A${15 + i}')).value = TextCellValue(row.name);
      summary.cell(CellIndex.indexByString('B${15 + i}')).value = IntCellValue(row.count);
    }

    summary.setColumnWidth(0, 36);
    summary.setColumnWidth(1, 20);

    // ── Sheet 2: Student Compliance List ─────────────────────────────────────
    final students = excel['Student Compliance List'];
    _excelTitle(students, 'A1', 'STUDENT COMPLIANCE REPORT — $yearLabel', 7);
    final headers = ['#', 'LRN', 'Student Name', 'Sex', 'Grade Level', 'Section', 'Status', 'Missing Count', 'Missing Documents'];
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
        s.fullName,
        s.sex,
        s.gradeLevel != null ? 'Grade ${s.gradeLevel}' : 'N/A',
        s.sectionName ?? 'N/A',
        s.status,
        s.missingCount.toString(),
        s.missingRequirements ?? 'None',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = students.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 3));
        cell.value = TextCellValue(row[c]);
        if (s.missingCount > 0 && c == 7) {
          cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#C62828'));
        } else if (s.missingCount == 0 && c == 7) {
          cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#1C8248'));
        }
      }
    }
    students.setColumnWidth(0, 6); students.setColumnWidth(1, 18);
    students.setColumnWidth(2, 22); students.setColumnWidth(3, 8);
    students.setColumnWidth(4, 14); students.setColumnWidth(5, 14);
    students.setColumnWidth(6, 12); students.setColumnWidth(7, 15);
    students.setColumnWidth(8, 45);

    // Delete default Sheet1 only after custom sheets have been populated
    excel.delete('Sheet1');

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

  // ── Print Compliance Report Dialog ─────────────────────────────────────────


  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(reportStatsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportStatsProvider);
            ref.invalidate(academicYearsProvider);
            ref.invalidate(yearlyComparisonProvider);
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleAndExportActions(context),
                const SizedBox(height: AppSizes.p24),
                
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(100),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, st) => _errorWidget('Error fetching analytics: $err'),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. KPI Cards
                      _buildMetricsGrid(data.studentCounts),
                      const SizedBox(height: AppSizes.p24),
                      
                      // 2. Filter Panel (collapsible)
                      _buildFilterPanel(context),
                      const SizedBox(height: AppSizes.p24),

                      // 3. Yearly Comparison Chart
                      _buildYearlyComparisonChart(),
                      const SizedBox(height: AppSizes.p24),
                      
                      // 4. Row of Missing Documents Chart
                      _buildMissingDocsChart(data.missingDocsBreakdown),
                      const SizedBox(height: AppSizes.p24),
                      
                      // 5. Interactive Student Compliance Table
                      _buildComplianceTable(data),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header + Export Actions ───────────────────────────────────────────────
  Widget _buildTitleAndExportActions(BuildContext context) {
    final statsAsync = ref.watch(reportStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    final yearsAsync = ref.watch(academicYearsProvider);
    final selectedYearId = ref.watch(selectedAcademicYearIdProvider);
    final selectedGrade = ref.watch(selectedGradeLevelProvider);
    final selectedSection = ref.watch(selectedSectionIdProvider);
    final selectedStatus = ref.watch(selectedStatusFilterProvider);
    final sections = ref.watch(filteredSectionsProvider);

    final years = yearsAsync.asData?.value ?? [];
    final yearLabel = selectedYearId != null
        ? years.firstWhere((y) => y.id == selectedYearId, orElse: () => AcademicYear(id: 0, yearRange: 'Selected', status: '')).yearRange
        : 'All Years';
    final gradeLabel = selectedGrade != null ? 'Grade $selectedGrade' : 'All Grades';
    final statusLabel = selectedStatus ?? 'All Statuses';

    String sectionLabel = 'All Sections';
    if (selectedSection != null && sections.isNotEmpty) {
      final s = sections.firstWhere((sec) => (sec['id'] as num).toInt() == selectedSection, orElse: () => {});
      if (s.isNotEmpty) sectionLabel = s['name'] as String;
    }

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
                  Text('Document Compliance & Statistics Dashboard • Tiaong Integrated School',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (isDesktop && statsAsync.hasValue) ...[
              SizedBox(
                width: 185,
                child: PrimaryButton(
                  label: 'EXPORT',
                  isLoading: _isExporting,
                  onPressed: () => _handleExportExcel(statsAsync.value!),
                ),
              ),
            ],
          ],
        ),
        // Mobile Actions
        if (!isDesktop && statsAsync.hasValue) ...[
          const SizedBox(height: AppSizes.p16),
          Row(
            children: [

              Expanded(
                child: PrimaryButton(
                  label: 'EXPORT',
                  isLoading: _isExporting,
                  onPressed: () => _handleExportExcel(statsAsync.value!),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Filter Panel (collapsible) ────────────────────────────────────────────
  Widget _buildFilterPanel(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsProvider);
    final selectedYearId = ref.watch(selectedAcademicYearIdProvider);
    
    final selectedGrade = ref.watch(selectedGradeLevelProvider);
    final selectedSection = ref.watch(selectedSectionIdProvider);
    final selectedStatus = ref.watch(selectedStatusFilterProvider);
    final sections = ref.watch(filteredSectionsProvider);
    final showOnlyMissingDocs = ref.watch(showOnlyMissingDocsProvider);
    final isExpanded = ref.watch(filterPanelExpandedProvider);

    // Build active filter summary chips for collapsed state
    final List<String> activeFilters = [];
    if (selectedYearId != null) {
      final years = yearsAsync.asData?.value ?? [];
      final yr = years.firstWhere((y) => y.id == selectedYearId, orElse: () => AcademicYear(id: 0, yearRange: 'S.Y.', status: ''));
      activeFilters.add(yr.yearRange);
    }
    if (selectedGrade != null) activeFilters.add('Grade $selectedGrade');
    if (selectedSection != null) {
      if (sections.isNotEmpty) {
        final sec = sections.firstWhere((s) => (s['id'] as num).toInt() == selectedSection, orElse: () => {});
        if (sec.isNotEmpty) activeFilters.add(sec['name'] as String);
      }
    }
    if (selectedStatus != null) activeFilters.add(selectedStatus);
    if (showOnlyMissingDocs) activeFilters.add('Missing Only');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Collapsible Header ─────────────────────────────────────────────
          InkWell(
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge))
                : BorderRadius.circular(AppSizes.radiusLarge),
            onTap: () => ref.read(filterPanelExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: AppColors.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  const Text('Filter Status & Statistics',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(width: 12),
                  // Active filter chips (shown when collapsed)
                  if (!isExpanded && activeFilters.isNotEmpty) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: activeFilters.map((f) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(f, style: const TextStyle(fontSize: 11)),
                              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                              labelStyle: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ] else if (!isExpanded && activeFilters.isEmpty) ...[
                    Text('No active filters', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable Body ────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final wide = constraints.maxWidth > 800;
                        const spacing = AppSizes.p12;

                      final filterWidgets = [
                        // Dropdown 1: Academic Year
                        yearsAsync.when(
                          loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                          error: (e, st) => const SizedBox.shrink(),
                          data: (yearsList) => DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: selectedYearId,
                            decoration: _filterDecoration('School Year'),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
                              ...yearsList.map((y) => DropdownMenuItem<int?>(value: y.id, child: Text(y.yearRange))),
                            ],
                            onChanged: (val) {
                              ref.read(selectedAcademicYearIdProvider.notifier).select(val);
                              // Reset section
                              ref.read(selectedSectionIdProvider.notifier).state = null;
                            },
                          ),
                        ),
                        // Dropdown 2: Grade Level
                        DropdownButtonFormField<int?>(
                          isExpanded: true,
                          initialValue: selectedGrade,
                          decoration: _filterDecoration('Grade Level'),
                          items: const [
                            DropdownMenuItem<int?>(value: null, child: Text('All Grades')),
                            DropdownMenuItem<int?>(value: 7, child: Text('Grade 7')),
                            DropdownMenuItem<int?>(value: 8, child: Text('Grade 8')),
                            DropdownMenuItem<int?>(value: 9, child: Text('Grade 9')),
                            DropdownMenuItem<int?>(value: 10, child: Text('Grade 10')),
                            DropdownMenuItem<int?>(value: 11, child: Text('Grade 11')),
                            DropdownMenuItem<int?>(value: 12, child: Text('Grade 12')),
                          ],
                          onChanged: (val) {
                            ref.read(selectedGradeLevelProvider.notifier).state = val;
                            // Reset section
                            ref.read(selectedSectionIdProvider.notifier).state = null;
                          },
                        ),
                        // Dropdown 3: Section (Dependent on selected year and optionally grade)
                        DropdownButtonFormField<int?>(
                          isExpanded: true,
                          initialValue: selectedSection,
                          decoration: _filterDecoration('Section'),
                          disabledHint: const Text('Select a Year first'),
                          items: selectedYearId == null
                              ? null
                              : [
                                  const DropdownMenuItem<int?>(value: null, child: Text('All Sections')),
                                  ...sections.map((sec) => DropdownMenuItem<int?>(
                                        value: (sec['id'] as num).toInt(),
                                        child: Text(sec['name'] as String),
                                      )),
                                ],
                          onChanged: selectedYearId == null ? null : (val) {
                            ref.read(selectedSectionIdProvider.notifier).state = val;
                          },
                        ),
                        // Dropdown 4: Student Status
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: selectedStatus,
                          decoration: _filterDecoration('Status'),
                          items: const [
                            DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                            DropdownMenuItem<String?>(value: 'Enrolled', child: Text('Active (Enrolled)')),
                            DropdownMenuItem<String?>(value: 'Dropped', child: Text('Dropout (Dropped)')),
                            DropdownMenuItem<String?>(value: 'Transferred', child: Text('Transferee')),
                            DropdownMenuItem<String?>(value: 'Graduated', child: Text('Graduated')),
                          ],
                          onChanged: (val) => ref.read(selectedStatusFilterProvider.notifier).state = val,
                        ),
                      ];

                      if (wide) {
                        final items = filterWidgets.map((w) => Expanded(child: w)).toList();
                        return Row(
                          children: items.expand((w) => [w, const SizedBox(width: spacing)]).toList()..removeLast(),
                        );
                      } else {
                        final items = filterWidgets.map((w) => SizedBox(width: 170, child: w)).toList();
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: items.expand((w) => [w, const SizedBox(width: spacing)]).toList()..removeLast(),
                          ),
                        );
                      }
                      }),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Switch(
                            value: showOnlyMissingDocs,
                            onChanged: (val) {
                              ref.read(showOnlyMissingDocsProvider.notifier).state = val;
                            },
                            activeThumbColor: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Show only students with missing documents', 
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) => InputDecoration(
    labelText: label,
    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGreen, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    filled: false,
  );

  // ── KPI Cards: Student status grid ────────────────────────────────────────
  Widget _buildMetricsGrid(StudentCounts counts) {
    return LayoutBuilder(
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
            StatCard(title: 'Active Students', value: counts.active.toString(), icon: Icons.check_circle_outline, iconColor: AppColors.primaryGreen),
            StatCard(title: 'Dropped (Dropouts)', value: counts.dropped.toString(), icon: Icons.error_outline, iconColor: Colors.red),
            StatCard(title: 'Transferees', value: counts.transferee.toString(), icon: Icons.swap_horiz_outlined, iconColor: Colors.orange),
            StatCard(title: 'Graduated Students', value: counts.graduated.toString(), icon: Icons.school_outlined, iconColor: Colors.blue),
          ],
        );
      },
    );
  }

  // ── Missing Documents Breakdown Card ──────────────────────────────────────
  Widget _buildMissingDocsChart(List<MissingDocBreakdown> breakdown) {
    final isFilterExpanded = ref.watch(missingDocsFilterExpandedProvider);

    // Categorize by SHS (grade 11-12) vs JHS (grade 7-10)
    // The requirement name may contain grade info – we rely on the name for best-effort.
    // Since the backend doesn't yet return grade_level per requirement, we detect via
    // common keywords or a "SHS"/"JHS" prefix approach. Fall back to showing both tags.
    Widget levelBadge(String level, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );

    // Heuristic: if name contains 'Grade 11' or 'Grade 12' or 'SHS' → SHS; 'Grade 7–10' or 'JHS' → JHS; else both
    String detectLevel(String name) {
      final upper = name.toUpperCase();
      if (upper.contains('SHS') || upper.contains('GRADE 11') || upper.contains('GRADE 12')) { return 'SHS'; }
      if (upper.contains('JHS') || upper.contains('GRADE 7') || upper.contains('GRADE 8') ||
          upper.contains('GRADE 9') || upper.contains('GRADE 10')) { return 'JHS'; }
      return 'ALL';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header with show/hide ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Missing Documents by Requirement Type',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Count of active student compliance requirements currently unsubmitted/unverified.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Show/Hide toggle
              TextButton.icon(
                onPressed: () => ref.read(missingDocsFilterExpandedProvider.notifier).state = !isFilterExpanded,
                icon: Icon(isFilterExpanded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16, color: AppColors.primaryGreen),
                label: Text(isFilterExpanded ? 'Hide' : 'Show',
                    style: const TextStyle(color: AppColors.primaryGreen, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.primaryGreen, width: 0.8),
                  ),
                ),
              ),
            ],
          ),
          // ── Expandable content ──────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.p24),
                if (breakdown.isEmpty)
                  _emptyWidget('No missing document requirements found. Compliance is 100%!')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: breakdown.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = breakdown[index];
                      final maxCount = breakdown.first.count;
                      final pct = maxCount > 0 ? item.count / maxCount : 0.0;
                      final level = detectLevel(item.name);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Level badge
                          SizedBox(
                            width: 34,
                            child: level == 'SHS'
                                ? levelBadge('SHS', Colors.purple.shade50, Colors.purple.shade700)
                                : level == 'JHS'
                                    ? levelBadge('JHS', Colors.teal.shade50, Colors.teal.shade700)
                                    : levelBadge('ALL', Colors.grey.shade100, Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          // Name
                          SizedBox(
                            width: 155,
                            child: Text(item.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                          const SizedBox(width: 10),
                          // Progress bar (compact height)
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5)),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  height: 10,
                                  width: (MediaQuery.of(context).size.width - 300) * 0.45 * pct,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Colors.orange, Colors.redAccent]),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Count badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.count}',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            crossFadeState: isFilterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ── Interactive Compliance Table ──────────────────────────────────────────
  Widget _buildComplianceTable(ReportStats data) {
    final showOnlyMissing = ref.watch(showOnlyMissingDocsProvider);
    final filteredStudents = showOnlyMissing 
        ? data.students.where((s) => s.missingCount > 0).toList() 
        : data.students;

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student Document Status List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text('List of students and their missing documents. Tap on a student row to view details.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSizes.radiusLarge)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(AppColors.primaryGreen.withValues(alpha: 0.04)),
                columnSpacing: 32,
                columns: const [
                  DataColumn(label: Text('LRN', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Grade/Sec', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Missing Docs', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Missing Requirements list', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filteredStudents.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('No students match the selected filters.')),
                          DataCell(Text('')), DataCell(Text('')),
                          DataCell(Text('')), DataCell(Text('')),
                          DataCell(Text('')),
                        ])
                      ]
                    : filteredStudents.map((student) {
                        return DataRow(
                          onSelectChanged: (_) {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                child: Container(
                                  width: 800,
                                  height: 600,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                  child: StudentDetailScreen(studentId: student.id, userRole: widget.userRole),
                                ),
                              ),
                            );
                          },
                          cells: [
                            DataCell(Text(student.lrn, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(student.fullName)),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: student.status == 'Enrolled'
                                    ? Colors.green.shade50
                                    : student.status == 'Graduated'
                                        ? Colors.blue.shade50
                                        : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                student.status == 'Enrolled' ? 'Active' : student.status,
                                style: TextStyle(
                                  color: student.status == 'Enrolled'
                                      ? Colors.green.shade700
                                      : student.status == 'Graduated'
                                          ? Colors.blue.shade700
                                          : Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            )),
                            DataCell(Text('${student.gradeLevel ?? 'N/A'}/${student.sectionName ?? 'N/A'}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: student.missingCount > 0 ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  student.missingCount.toString(),
                                  style: TextStyle(
                                    color: student.missingCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                student.missingRequirements ?? 'None — Complete',
                                style: TextStyle(
                                  color: student.missingCount > 0 ? Colors.grey.shade700 : Colors.green.shade700,
                                  fontSize: 12,
                                  fontStyle: student.missingCount > 0 ? FontStyle.normal : FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      );

  // ── Yearly Comparison Chart ───────────────────────────────────────────────
  Widget _buildYearlyComparisonChart() {
    final yearlyAsync = ref.watch(yearlyComparisonProvider);
    final selectedYears = ref.watch(yearlyComparisonSelectedYearsProvider);
    final selectedStatuses = ref.watch(yearlyComparisonSelectedStatusesProvider);

    // Available status options for yearly comparison
    const allStatusOptions = [
      _StatusOption(key: 'enrolled',    label: 'Active',      color: AppColors.primaryGreen),
      _StatusOption(key: 'dropped',     label: 'Dropped',     color: Colors.red),
      _StatusOption(key: 'graduated',   label: 'Graduated',   color: Colors.blue),
      _StatusOption(key: 'transferred', label: 'Transferee',  color: Colors.orange),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chart Title & Filter Row ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Yearly Comparison by Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Trend of student statuses across academic years (ascending).',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Underline Filter Dropdown Row ─────────────────────────────────
          yearlyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, e) => const SizedBox.shrink(),
            data: (allData) {
              // All available year strings from DB, sorted ascending
              final allYearStrings = allData.map((d) => d.year).toSet().toList()..sort();

              return Row(
                children: [
                  // Year multi-select dropdown
                  _buildUnderlineDropdown(
                    label: selectedYears.isEmpty
                        ? 'All Years'
                        : selectedYears.length == 1
                            ? selectedYears.first
                            : '${selectedYears.length} Years',
                    icon: Icons.calendar_today_outlined,
                    onTap: (btnCtx) => _showYearMultiSelectMenu(btnCtx, allYearStrings, selectedYears),
                  ),
                  const SizedBox(width: 20),
                  // Status multi-select dropdown
                  _buildUnderlineDropdown(
                    label: selectedStatuses.length == allStatusOptions.length
                        ? 'All Statuses'
                        : selectedStatuses.isEmpty
                            ? 'No Status'
                            : selectedStatuses.length == 1
                                ? allStatusOptions
                                    .firstWhere((o) => o.key == selectedStatuses.first,
                                        orElse: () => const _StatusOption(key: '', label: '', color: Colors.grey))
                                    .label
                                : '${selectedStatuses.length} Statuses',
                    icon: Icons.people_alt_outlined,
                    onTap: (btnCtx) => _showStatusMultiSelectMenu(btnCtx, allStatusOptions, selectedStatuses),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSizes.p24),

          // ── Chart ─────────────────────────────────────────────────────────
          yearlyAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (e, st) => _errorWidget('Error loading yearly data: $e'),
            data: (rawData) {
              if (rawData.isEmpty) return _emptyWidget('No academic years data found.');

              // Filter by selected years (ascending sort)
              var data = List<YearlyComparisonData>.from(rawData)
                ..sort((a, b) => a.year.compareTo(b.year));
              if (selectedYears.isNotEmpty) {
                data = data.where((d) => selectedYears.contains(d.year)).toList();
              }
              if (data.isEmpty) return _emptyWidget('No data for selected years.');

              // Build bar rods only for selected statuses
              final activeOptions = allStatusOptions
                  .where((o) => selectedStatuses.contains(o.key))
                  .toList();

              // Find max Y
              double maxY = 0;
              for (var y in data) {
                for (var opt in activeOptions) {
                  final val = _getStatusValue(y, opt.key).toDouble();
                  if (val > maxY) maxY = val;
                }
              }
              maxY = maxY * 1.2;
              if (maxY == 0) maxY = 10;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double chartWidth = constraints.maxWidth > (data.length * 150.0)
                      ? constraints.maxWidth
                      : (data.length * 150.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 300,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => Colors.blueGrey.shade800,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                if (groupIndex >= data.length) return null;
                                final yearData = data[groupIndex];
                                final opt = rodIndex < activeOptions.length ? activeOptions[rodIndex] : null;
                                if (opt == null) return null;
                                final val = _getStatusValue(yearData, opt.key);
                                return BarTooltipItem(
                                  '${opt.label}\n',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  children: [
                                    TextSpan(
                                        text: val.toString(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.normal)),
                                  ],
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= data.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      data[value.toInt()].year,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                                reservedSize: 32,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  if (value % (maxY / 5).ceil() != 0) return const SizedBox.shrink();
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: (maxY / 5) > 0 ? (maxY / 5) : 1,
                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: data.asMap().entries.map((entry) {
                            final i = entry.key;
                            final d = entry.value;
                            return BarChartGroupData(
                              x: i,
                              barsSpace: 4,
                              barRods: activeOptions.map((opt) => BarChartRodData(
                                toY: _getStatusValue(d, opt.key).toDouble(),
                                color: opt.color,
                                width: activeOptions.length > 2 ? 12 : 16,
                                borderRadius: BorderRadius.circular(4),
                              )).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Legend (dynamic based on selected statuses) ───────────────────
          Consumer(
            builder: (context, ref, _) {
              final statuses = ref.watch(yearlyComparisonSelectedStatusesProvider);
              const allStatusOptions = [
                _StatusOption(key: 'enrolled',    label: 'Active',      color: AppColors.primaryGreen),
                _StatusOption(key: 'dropped',     label: 'Dropped',     color: Colors.red),
                _StatusOption(key: 'graduated',   label: 'Graduated',   color: Colors.blue),
                _StatusOption(key: 'transferred', label: 'Transferee',  color: Colors.orange),
              ];
              final active = allStatusOptions.where((o) => statuses.contains(o.key)).toList();
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: active.map((o) => _buildLegendItem(o.color, o.label)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  int _getStatusValue(YearlyComparisonData data, String key) {
    switch (key) {
      case 'enrolled': return data.enrolled;
      case 'dropped': return data.dropped;
      case 'graduated': return data.graduated;
      case 'transferred': return data.transferred;
      default: return 0;
    }
  }

  /// Builds an underline-style dropdown button
  Widget _buildUnderlineDropdown({
    required String label,
    required IconData icon,
    required void Function(BuildContext) onTap,
  }) {
    return Builder(
      builder: (btnCtx) => InkWell(
        onTap: () => onTap(btnCtx),
        borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primaryGreen, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primaryGreen),
          ],
        ),
      ),
      )
    );
  }

  /// Shows a popup multi-select menu for years
  void _showYearMultiSelectMenu(BuildContext context, List<String> allYears, Set<String> selected) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<void>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Consumer(
            builder: (ctx, ref, _) {
              final currentSelected = ref.watch(yearlyComparisonSelectedYearsProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Text('Select School Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref.read(yearlyComparisonSelectedYearsProvider.notifier).clear();
                          },
                          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...allYears.map((year) {
                    final isChecked = currentSelected.contains(year);
                    return CheckboxListTile(
                      dense: true,
                      value: isChecked,
                      title: Text(year, style: const TextStyle(fontSize: 13)),
                      activeColor: AppColors.primaryGreen,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        ref.read(yearlyComparisonSelectedYearsProvider.notifier).toggle(year);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Shows a popup multi-select menu for statuses
  void _showStatusMultiSelectMenu(
      BuildContext context, List<_StatusOption> options, Set<String> selected) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<void>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Consumer(
            builder: (ctx, ref, _) {
              final currentSelected = ref.watch(yearlyComparisonSelectedStatusesProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Text('Select Statuses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref.read(yearlyComparisonSelectedStatusesProvider.notifier).selectAll();
                          },
                          child: const Text('All', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...options.map((opt) {
                    final isChecked = currentSelected.contains(opt.key);
                    return CheckboxListTile(
                      dense: true,
                      value: isChecked,
                      title: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: opt.color, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(opt.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      activeColor: AppColors.primaryGreen,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        ref.read(yearlyComparisonSelectedStatusesProvider.notifier).toggle(opt.key);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Helper data class for status options ─────────────────────────────────────
class _StatusOption {
  final String key;
  final String label;
  final Color color;
  const _StatusOption({required this.key, required this.label, required this.color});
}
