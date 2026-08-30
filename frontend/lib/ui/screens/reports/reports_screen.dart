import 'dart:async';
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
import '../../providers/auth_provider.dart';
import '../../shared/dialogs/file_save_preview_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../documents/widgets/student_profile_modal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/transparency_board_section.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const ReportsScreen({super.key, required this.userRole});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tableHorizontalScrollController = ScrollController();
  final ScrollController _chartHorizontalScrollController = ScrollController();
  final ScrollController _gradeComplianceScrollController = ScrollController();
  final ScrollController _missingDocsScrollController = ScrollController();
  ProviderSubscription<String>? _tabListener;
  Timer? _pollingTimer;

  int _currentPage = 0;
  int _rowsPerPage = 10;
  int _selectedViewMode = 0; // 0: DepEd Transparency Board, 1: Compliance & Analytics, 2: Combined

  // Table search & sort state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _sortColumn;
  bool _sortAscending = true;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Initial fetch
      _refreshData();

      // Setup tab listener
      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (previous == 'Reports' || next == 'Reports') {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
          setState(() {
            _rowsPerPage = 10;
            _currentPage = 0;
            _searchQuery = '';
            _searchController.clear();
          });
        }
      });

      // Polling every 5 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted &&
            ref.read(authProvider).value != null &&
            ref.read(activeTabProvider) == 'Reports') {
          _refreshData();
        }
      });
    });
  }

  void _refreshData() {
    ref.invalidate(reportStatsProvider);
    ref.invalidate(academicYearsProvider);
    ref.invalidate(yearlyComparisonProvider);
    ref.invalidate(storageStatsProvider);
    ref.invalidate(transparencyBoardProvider);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabListener?.close();
    _scrollController.dispose();
    _tableHorizontalScrollController.dispose();
    _chartHorizontalScrollController.dispose();
    _gradeComplianceScrollController.dispose();
    _missingDocsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // â”€â”€ Excel Export â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _handleExportExcel(ReportStats data) async {
    setState(() => _isExporting = true);
    try {
      final yearId = ref.read(selectedAcademicYearIdProvider);
      final years = ref.read(academicYearsProvider).asData?.value ?? [];
      final yearLabel = yearId != null
          ? years
                .firstWhere(
                  (y) => y.id == yearId,
                  orElse: () =>
                      AcademicYear(id: 0, yearRange: 'Selected', status: ''),
                )
                .yearRange
          : 'All Years';

      // Build Excel bytes using the filtered data
      final bytes = _buildExcel(data, yearLabel);
      final defaultFileName =
          'TIS_RMS_Report_${yearLabel.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final generatedAt = DateTime.now().toString().substring(0, 19);

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
          [
            'Transferees (Transferred)',
            data.studentCounts.transferee.toString(),
          ],
          ['Graduated', data.studentCounts.graduated.toString()],
          ['', ''],
          ['MISSING DOCUMENTS PER REQUIREMENT TYPE', ''],
          ['Document Type', 'Missing Count'],
          ...data.missingDocsBreakdown.map((e) => [e.name, e.count.toString()]),
        ],
      );

      final masterlistSheet = SheetPreviewData(
        sheetName: 'Student Compliance List',
        headers: [
          '#',
          'LRN',
          'Name',
          'Sex',
          'Grade Level',
          'Section',
          'Status',
          'Missing Count',
          'Missing Documents',
        ],
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
      String? savedPath;
      final saved = await showFileSavePreviewDialog(
        context,
        fileName: defaultFileName,
        fileType: SaveFileType.excel,
        fileBytes: bytes,
        previewRows: [
          FilePreviewRow('School Year', yearLabel),
          FilePreviewRow('Students', data.students.length.toString()),
          FilePreviewRow('Sheets', '2'),
          FilePreviewRow('Generated', generatedAt),
        ],
        sheets: [summarySheet, masterlistSheet],
        onSave: (resolvedName) async {
          savedPath = await _saveExcelFile(bytes, resolvedName);
        },
      );

      if (saved == true && savedPath != null && mounted) {
        showSuccessDialog(
          context,
          title: 'Export Successful',
          message: 'Report has been exported successfully.',
          filePath: savedPath,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Export Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
      setState(() => _isExporting = false);
    }
  }

  Future<String?> _saveExcelFile(List<int> bytes, String fileName) async {
    String? savePath;

    if (Platform.isAndroid) {
      var storageStatus = await Permission.storage.status;
      var manageStatus = await Permission.manageExternalStorage.status;

      if (!storageStatus.isGranted && !manageStatus.isGranted) {
        await [Permission.storage, Permission.manageExternalStorage].request();
        storageStatus = await Permission.storage.status;
        manageStatus = await Permission.manageExternalStorage.status;
      }

      if (!storageStatus.isGranted && !manageStatus.isGranted) {
        if (!mounted) return null;
        final retry = await _showPermissionDeniedDialog();
        if (retry == true) {
          await openAppSettings();
          if (!mounted) return null;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm Permission'),
              content: const Text(
                'Did you grant the storage permission in settings?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No'),
                 ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Yes'),
                 ),
              ],
            ),
          );
          if (confirmed == true) {
            storageStatus = await Permission.storage.status;
            manageStatus = await Permission.manageExternalStorage.status;
          }
          if (!storageStatus.isGranted && !manageStatus.isGranted) {
            throw Exception('Storage permission denied. Cannot save file.');
          }
        } else {
          return null;
        }
      }

      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to save report',
      );
      if (selectedDirectory == null) return null;
      savePath = '$selectedDirectory/$fileName';
    } else if (Platform.isWindows) {
      savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Report As...',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return null;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      savePath = '${dir.path}/$fileName';
    }

    final file = File(savePath);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<bool?> _showPermissionDeniedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Storage permission is required to save the exported Excel file. Would you like to open app settings to grant the permission?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  List<int> _buildExcel(ReportStats data, String yearLabel) {
    final excel = Excel.createExcel();

    // â”€â”€ Sheet 1: Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final summary = excel['Summary'];
    _excelTitle(summary, 'A1', 'TIAONG INTEGRATED SCHOOL â€” TIS RMS', 7);
    _excelTitle(summary, 'A2', 'Annual Report Summary: $yearLabel', 7);
    _excelTitle(
      summary,
      'A3',
      'Generated: ${DateTime.now().toString().substring(0, 19)}',
      7,
    );

    summary.cell(CellIndex.indexByString('A5')).value = TextCellValue(
      'STUDENT STATISTICS',
    );
    _boldCell(summary, 'A5');
    _header(summary, 'A6', 'Student Status');
    _header(summary, 'B6', 'Total Count');
    final stats = [
      ['Active (Enrolled)', data.studentCounts.active.toString()],
      ['Dropouts (Dropped)', data.studentCounts.dropped.toString()],
      ['Transferees (Transferred)', data.studentCounts.transferee.toString()],
      ['Graduated', data.studentCounts.graduated.toString()],
    ];
    for (int i = 0; i < stats.length; i++) {
      summary.cell(CellIndex.indexByString('A${7 + i}')).value = TextCellValue(
        stats[i][0],
      );
      summary.cell(CellIndex.indexByString('B${7 + i}')).value = TextCellValue(
        stats[i][1],
      );
    }

    summary.cell(CellIndex.indexByString('A13')).value = TextCellValue(
      'MISSING DOCUMENTS PER REQUIREMENT TYPE',
    );
    _boldCell(summary, 'A13');
    _header(summary, 'A14', 'Document Type');
    _header(summary, 'B14', 'Missing Count');
    for (int i = 0; i < data.missingDocsBreakdown.length; i++) {
      final row = data.missingDocsBreakdown[i];
      summary.cell(CellIndex.indexByString('A${15 + i}')).value = TextCellValue(
        row.name,
      );
      summary.cell(CellIndex.indexByString('B${15 + i}')).value = IntCellValue(
        row.count,
      );
    }

    summary.setColumnWidth(0, 36);
    summary.setColumnWidth(1, 20);

    // â”€â”€ Sheet 2: Student Compliance List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final students = excel['Student Compliance List'];
    _excelTitle(students, 'A1', 'STUDENT COMPLIANCE REPORT â€” $yearLabel', 7);
    final headers = [
      '#',
      'LRN',
      'Student Name',
      'Sex',
      'Grade Level',
      'Section',
      'Status',
      'Missing Count',
      'Missing Documents',
    ];
    for (int c = 0; c < headers.length; c++) {
      final cell = students.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1C8248'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
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
        final cell = students.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 3),
        );
        cell.value = TextCellValue(row[c]);
        if (s.missingCount > 0 && c == 7) {
          cell.cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#C62828'),
          );
        } else if (s.missingCount == 0 && c == 7) {
          cell.cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#1C8248'),
          );
        }
      }
    }
    students.setColumnWidth(0, 6);
    students.setColumnWidth(1, 18);
    students.setColumnWidth(2, 22);
    students.setColumnWidth(3, 8);
    students.setColumnWidth(4, 14);
    students.setColumnWidth(5, 14);
    students.setColumnWidth(6, 12);
    students.setColumnWidth(7, 15);
    students.setColumnWidth(8, 45);

    // Delete default Sheet1 only after custom sheets have been populated
    excel.delete('Sheet1');

    return excel.encode()!;
  }

  void _excelTitle(Sheet sheet, String addr, String text, int span) {
    final cell = sheet.cell(CellIndex.indexByString(addr));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#1C8248'),
    );
  }

  void _boldCell(Sheet sheet, String addr) {
    sheet.cell(CellIndex.indexByString(addr)).cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
    );
  }

  void _header(Sheet sheet, String addr, String text) {
    final cell = sheet.cell(CellIndex.indexByString(addr));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
    );
  }

  // â”€â”€ Print Compliance Report Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(reportStatsProvider);
    final storageAsync = ref.watch(storageStatsProvider);
    final yearsAsync = ref.watch(academicYearsProvider);
    final selectedYearId = ref.watch(selectedAcademicYearIdProvider);
    final selectedYearNotifier = ref.read(selectedAcademicYearIdProvider.notifier);

    // Auto-select active academic year on initial load if not explicitly chosen
    if (!selectedYearNotifier.hasExplicitSelection && selectedYearId == null && yearsAsync.hasValue) {
      final yearsList = yearsAsync.value ?? [];
      if (yearsList.isNotEmpty) {
        final activeYear = yearsList.firstWhere(
          (y) => y.status.toLowerCase() == 'active',
          orElse: () => yearsList.last,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            selectedYearNotifier.setDefaultIfUnset(activeYear.id);
          }
        });
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportStatsProvider);
            ref.invalidate(academicYearsProvider);
            ref.invalidate(yearlyComparisonProvider);
            ref.invalidate(storageStatsProvider);
            ref.invalidate(transparencyBoardProvider);
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
                _buildViewModeToggle(),
                const SizedBox(height: AppSizes.p24),

                if (_selectedViewMode == 0 || _selectedViewMode == 2) ...[
                  const TransparencyBoardSection(),
                  const SizedBox(height: AppSizes.p32),
                ],

                if (_selectedViewMode == 1 || _selectedViewMode == 2) ...[
                  statsAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(100),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, st) =>
                        _errorWidget('Error fetching analytics: $err'),
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Filter Panel (collapsible)
                        _buildFilterPanel(context),
                        const SizedBox(height: AppSizes.p16),

                        // 2. Summary Banner
                        _buildSummaryBanner(data),
                        const SizedBox(height: AppSizes.p24),

                        // 3. KPI Cards
                        _buildMetricsGrid(data, storageAsync.asData?.value),
                        const SizedBox(height: AppSizes.p24),

                        // 4. Charts Row 1: Yearly Comparison + Status Donut
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 1100) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _buildYearlyComparisonChart(
                                      isDesktop: true,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p24),
                                  Expanded(
                                    flex: 4,
                                    child: _buildStatusDonutChart(
                                      data.studentCounts,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  _buildYearlyComparisonChart(isDesktop: false),
                                  const SizedBox(height: AppSizes.p24),
                                  _buildStatusDonutChart(data.studentCounts),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // 5. Grade Compliance Chart (full width)
                        _buildGradeComplianceChart(data.students),
                        const SizedBox(height: AppSizes.p24),

                        // 6. Missing Docs Breakdown (full width)
                        _buildMissingDocsChart(
                          data.missingDocsBreakdown,
                          isDesktop: false,
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // 7. Interactive Student Compliance Table
                        _buildComplianceTable(data),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.p48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final items = [
          _buildToggleItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            title: 'DepEd Transparency Board',
            subtitle: 'Recommended DepEd metrics & equity',
          ),
          _buildToggleItem(
            index: 1,
            icon: Icons.analytics_outlined,
            title: 'Compliance & Analytics',
            subtitle: 'Student masterlist & documents',
          ),
          _buildToggleItem(
            index: 2,
            icon: Icons.view_agenda_outlined,
            title: 'Unified Combined View',
            subtitle: 'Display all reporting modules',
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  children: items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: item,
                          ))
                      .toList(),
                )
              : Row(
                  children: items
                      .map((item) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: item,
                            ),
                          ))
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _buildToggleItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedViewMode == index;
    return InkWell(
        onTap: () => setState(() {
          _selectedViewMode = index;
          _rowsPerPage = 10;
          _currentPage = 0;
        }),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primaryGreen
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? AppColors.primaryGreen.withValues(alpha: 0.8)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }


  // â”€â”€ Header + Export Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTitleAndExportActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(reportStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

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
                  Text(
                    'System Reports & Analytics',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p8),
                  Text(
                    'Document Compliance & Statistics Dashboard Tiaong Integrated School',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
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

  // â”€â”€ Filter Panel (collapsible) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilterPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      final yr = years.firstWhere(
        (y) => y.id == selectedYearId,
        orElse: () => AcademicYear(id: 0, yearRange: 'S.Y.', status: ''),
      );
      activeFilters.add(yr.yearRange);
    }
    if (selectedGrade != null) activeFilters.add('Grade $selectedGrade');
    if (selectedSection != null) {
      if (sections.isNotEmpty) {
        final sec = sections.firstWhere(
          (s) => (s['id'] as num).toInt() == selectedSection,
          orElse: () => {},
        );
        if (sec.isNotEmpty) activeFilters.add(sec['name'] as String);
      }
    }
    if (selectedStatus != null) activeFilters.add(selectedStatus);
    if (showOnlyMissingDocs) activeFilters.add('Missing Only');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Collapsible Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          InkWell(
            borderRadius: isExpanded
                ? const BorderRadius.vertical(
                    top: Radius.circular(AppSizes.radiusLarge),
                  )
                : BorderRadius.circular(AppSizes.radiusLarge),
            onTap: () => ref.read(filterPanelExpandedProvider.notifier).state =
                !isExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Active filter chips (shown when collapsed)
                  if (!isExpanded && activeFilters.isNotEmpty) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: activeFilters
                              .map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      f,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: AppColors.primaryGreen
                                        .withValues(alpha: 0.1),
                                    labelStyle: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 0,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ] else if (!isExpanded && activeFilters.isEmpty) ...[
                    Text(
                      'No filters set',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // â”€â”€ Expandable Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 800;
                          const spacing = AppSizes.p12;

                          final filterWidgets = [
                            // Dropdown 1: Academic Year
                            yearsAsync.when(
                              skipLoadingOnReload: true,
                              loading: () => const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (e, st) => const SizedBox.shrink(),
                              data: (yearsList) =>
                                  DropdownButtonFormField<int?>(
                                    isExpanded: true,
                                    value: selectedYearId,
                                    decoration: _filterDecoration(
                                      'School Year',
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('All Years'),
                                      ),
                                      ...yearsList.map(
                                        (y) => DropdownMenuItem<int?>(
                                          value: y.id,
                                          child: Text(y.yearRange),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      ref
                                          .read(
                                            selectedAcademicYearIdProvider
                                                .notifier,
                                          )
                                          .select(val);
                                      // Reset section
                                      ref
                                              .read(
                                                selectedSectionIdProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      setState(() => _currentPage = 0);
                                    },
                                  ),
                            ),
                            // Dropdown 2: Grade Level
                            DropdownButtonFormField<int?>(
                              isExpanded: true,
                              initialValue: selectedGrade,
                              decoration: _filterDecoration('Grade Level'),
                              items: const [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All Grades'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 7,
                                  child: Text('Grade 7'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 8,
                                  child: Text('Grade 8'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 9,
                                  child: Text('Grade 9'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 10,
                                  child: Text('Grade 10'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 11,
                                  child: Text('Grade 11'),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 12,
                                  child: Text('Grade 12'),
                                ),
                              ],
                              onChanged: (val) {
                                ref
                                        .read(
                                          selectedGradeLevelProvider.notifier,
                                        )
                                        .state =
                                    val;
                                // Reset section
                                ref
                                        .read(
                                          selectedSectionIdProvider.notifier,
                                        )
                                        .state =
                                    null;
                                setState(() => _currentPage = 0);
                              },
                            ),
                            // Dropdown 3: Section (Dependent on selected year and optionally grade)
                            DropdownButtonFormField<int?>(
                              isExpanded: true,
                              initialValue: selectedSection,
                              decoration: _filterDecoration('Section'),
                              disabledHint: const Text('Pick a year first'),
                              items: selectedYearId == null
                                  ? null
                                  : [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('All Sections'),
                                      ),
                                      ...sections.map(
                                        (sec) => DropdownMenuItem<int?>(
                                          value: (sec['id'] as num).toInt(),
                                          child: Text(sec['name'] as String),
                                        ),
                                      ),
                                    ],
                              onChanged: selectedYearId == null
                                  ? null
                                  : (val) {
                                      ref
                                              .read(
                                                selectedSectionIdProvider
                                                    .notifier,
                                              )
                                              .state =
                                          val;
                                      setState(() => _currentPage = 0);
                                    },
                            ),
                            // Dropdown 4: Student Status
                            DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: selectedStatus,
                              decoration: _filterDecoration('Status'),
                              items: const [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Statuses'),
                                ),
                                DropdownMenuItem<String?>(
                                  value: 'Enrolled',
                                  child: Text('Active (Enrolled)'),
                                ),
                                DropdownMenuItem<String?>(
                                  value: 'Dropped',
                                  child: Text('Dropout (Dropped)'),
                                ),
                                DropdownMenuItem<String?>(
                                  value: 'Transferred',
                                  child: Text('Transferee'),
                                ),
                                DropdownMenuItem<String?>(
                                  value: 'Graduated',
                                  child: Text('Graduated'),
                                ),
                              ],
                              onChanged: (val) {
                                ref
                                        .read(
                                          selectedStatusFilterProvider.notifier,
                                        )
                                        .state =
                                    val;
                                setState(() => _currentPage = 0);
                              },
                            ),
                          ];

                          if (wide) {
                            final items = filterWidgets
                                .map((w) => Expanded(child: w))
                                .toList();
                            return Row(
                              children:
                                  items
                                      .expand(
                                        (w) => [
                                          w,
                                          const SizedBox(width: spacing),
                                        ],
                                      )
                                      .toList()
                                    ..removeLast(),
                            );
                          } else {
                            final items = filterWidgets
                                .map((w) => SizedBox(width: 170, child: w))
                                .toList();
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    items
                                        .expand(
                                          (w) => [
                                            w,
                                            const SizedBox(width: spacing),
                                          ],
                                        )
                                        .toList()
                                      ..removeLast(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Switch(
                            value: showOnlyMissingDocs,
                            onChanged: (val) {
                              ref
                                      .read(
                                        showOnlyMissingDocsProvider.notifier,
                                      )
                                      .state =
                                  val;
                              setState(() => _currentPage = 0);
                            },
                            activeThumbColor: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Show only students who have missing documents',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkTextSecondary : null,
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        ),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      filled: false,
    );
  }

  // â”€â”€ KPI Cards: Compliance + Student status grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMetricsGrid(ReportStats reportData, int? storageBytes) {
    final counts = reportData.studentCounts;
    final students = reportData.students;
    final breakdown = reportData.missingDocsBreakdown;

    final total = counts.active +
        counts.inactive +
        counts.dropped +
        counts.transferee +
        counts.graduated;
    final compliantCount = students.where((s) => s.missingCount == 0).length;
    final withIssuesCount = students.where((s) => s.missingCount > 0).length;
    final totalMissing = breakdown.fold<int>(0, (a, b) => a + b.count);
    final complianceRate =
        students.isNotEmpty ? (compliantCount / students.length * 100) : 0.0;

    final inactiveRate = total > 0
        ? (counts.inactive / total * 100).toStringAsFixed(1)
        : '0.0';
    final gradRate = total > 0
        ? (counts.graduated / total * 100).toStringAsFixed(1)
        : '0.0';
    final dropRate = total > 0
        ? (counts.dropped / total * 100).toStringAsFixed(1)
        : '0.0';
    final transRate = total > 0
        ? (counts.transferee / total * 100).toStringAsFixed(1)
        : '0.0';
    final fourPsRate = total > 0
        ? (counts.fourPs / total * 100).toStringAsFixed(1)
        : '0.0';

    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824) {
        return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      }
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card Color Guide Tip Banner ──────────────────────────────
        Builder(
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFE5A663) : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Color Guide:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        _buildColorTipItem(
                          dotColor: isDark ? const Color(0xFF76BA8A) : AppColors.primaryGreen,
                          label: 'Green',
                          meaning: 'Good (≥80% compliance, 0 issues)',
                          isDark: isDark,
                        ),
                        _buildColorTipItem(
                          dotColor: isDark ? const Color(0xFFE5A663) : Colors.orange.shade700,
                          label: 'Orange',
                          meaning: 'Warning (50–79% compliance or missing docs)',
                          isDark: isDark,
                        ),
                        _buildColorTipItem(
                          dotColor: isDark ? const Color(0xFFD67878) : Colors.red.shade600,
                          label: 'Red',
                          meaning: 'Needs Action (<50% compliance or student issues)',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Primary KPI Row (3 cards) ────────────────────────────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final cols = constraints.maxWidth >= 700
                ? 3
                : (constraints.maxWidth >= 480 ? 2 : 1);
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: constraints.maxWidth < 480 ? 150 : 165,
              ),
              children: [
                _buildPrimaryKpiCard(
                  title: 'Overall Compliance',
                  value: '${complianceRate.toStringAsFixed(1)}%',
                  subtitle:
                      '$compliantCount of ${students.length} students complete',
                  icon: Icons.verified_outlined,
                  color: complianceRate >= 80
                      ? AppColors.primaryGreen
                      : complianceRate >= 50
                      ? Colors.orange
                      : Colors.red,
                ),
                _buildPrimaryKpiCard(
                  title: 'Students with Issues',
                  value: '$withIssuesCount',
                  subtitle: 'Missing at least 1 document',
                  icon: Icons.person_off_outlined,
                  color: withIssuesCount == 0
                      ? AppColors.primaryGreen
                      : Colors.red.shade600,
                ),
                _buildPrimaryKpiCard(
                  title: 'Total Missing Docs',
                  value: '$totalMissing',
                  subtitle: 'Across ${breakdown.length} requirement types',
                  icon: Icons.file_copy_outlined,
                  color: totalMissing == 0
                      ? AppColors.primaryGreen
                      : Colors.orange.shade700,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Secondary Status Row (6 cards) ───────────────────────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isDesktop = Theme.of(ctx).platform == TargetPlatform.windows ||
                Theme.of(ctx).platform == TargetPlatform.macOS ||
                Theme.of(ctx).platform == TargetPlatform.linux;
            final isWide = constraints.maxWidth >= 750 || isDesktop;
            final cols = isWide
                ? 6
                : (constraints.maxWidth >= 480 ? 3 : 2);
            final spacing = isWide ? 10.0 : 12.0;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 10,
                mainAxisExtent: cols == 6 ? 94 : (constraints.maxWidth < 480 ? 115 : 125),
              ),
              children: [
                StatCard(
                  title: 'Active Students',
                  value: counts.active.toString(),
                  subtitle: 'Total: $total',
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.primaryGreen,
                ),
                StatCard(
                  title: 'Inactive',
                  value: counts.inactive.toString(),
                  subtitle: 'Rate: $inactiveRate%',
                  icon: Icons.pause_circle_outline,
                  iconColor: Colors.blueGrey,
                ),
                StatCard(
                  title: 'Dropouts',
                  value: counts.dropped.toString(),
                  subtitle: 'Rate: $dropRate%',
                  icon: Icons.person_remove_outlined,
                  iconColor: Colors.red,
                ),
                StatCard(
                  title: 'Transferees',
                  value: counts.transferee.toString(),
                  subtitle: 'Rate: $transRate%',
                  icon: Icons.transfer_within_a_station,
                  iconColor: Colors.orange,
                ),
                StatCard(
                  title: 'Graduated',
                  value: counts.graduated.toString(),
                  subtitle: 'Rate: $gradRate%',
                  icon: Icons.school_outlined,
                  iconColor: Colors.blue,
                ),
                StatCard(
                  title: '4Ps Beneficiaries',
                  value: counts.fourPs.toString(),
                  subtitle: 'Rate: $fourPsRate%',
                  icon: Icons.card_membership_outlined,
                  iconColor: Colors.purple,
                ),
              ],
            );
          },
        ),

        // ── Storage chip (small, right-aligned) ───────────────────────
        if (storageBytes != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.blueGrey.shade100,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_outlined,
                        size: 13,
                        color: isDark ? AppColors.darkTextSecondary : Colors.blueGrey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Storage: ${formatBytes(storageBytes)} used',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorTipItem({
    required Color dotColor,
    required String label,
    required String meaning,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: dotColor,
                ),
              ),
              TextSpan(text: meaning),
            ],
          ),
        ),
      ],
    );
  }

  /// Highlighted primary KPI card with colored accent border.
  Widget _buildPrimaryKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In dark mode, slightly desaturate bright accents for a softer, eye-friendly look
    final effectiveColor = isDark
        ? (color == AppColors.primaryGreen
            ? const Color(0xFF76BA8A)
            : color == Colors.orange
                ? const Color(0xFFE5A663)
                : color == Colors.redAccent || color == Colors.red
                    ? const Color(0xFFD67878)
                    : color == Colors.blue
                        ? const Color(0xFF7EAAD8)
                        : color)
        : color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: effectiveColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: effectiveColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Missing Documents Breakdown Card ──────────────────────────────────────
  Widget _buildMissingDocsChart(
    List<MissingDocBreakdown> breakdown, {
    required bool isDesktop,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFilterExpanded = ref.watch(missingDocsFilterExpandedProvider);
    final totalMissingAll = breakdown.fold<int>(0, (sum, item) => sum + item.count);

    // Categorize by SHS (grade 11-12) vs JHS (grade 7-10)
    // The requirement name may contain grade info – we rely on the name for best-effort.
    // Since the backend doesn't yet return grade_level per requirement, we detect via
    // common keywords or a "SHS"/"JHS" prefix approach. Fall back to showing both tags.
    Widget levelBadge(String level, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );

    // Heuristic: if name contains 'Grade 11' or 'Grade 12' or 'SHS' → SHS; 'Grade 7–10' or 'JHS' → JHS; else both
    String detectLevel(String name) {
      final upper = name.toUpperCase();
      if (upper.contains('SHS') ||
          upper.contains('GRADE 11') ||
          upper.contains('GRADE 12')) {
        return 'SHS';
      }
      if (upper.contains('JHS') ||
          upper.contains('GRADE 7') ||
          upper.contains('GRADE 8') ||
          upper.contains('GRADE 9') ||
          upper.contains('GRADE 10')) {
        return 'JHS';
      }
      return 'ALL';
    }

    Widget buildMissingDocRow(MissingDocBreakdown item) {
      final pct = totalMissingAll > 0 ? (item.count / totalMissingAll).clamp(0.0, 1.0) : 0.0;
      final level = detectLevel(item.name);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Level badge
              SizedBox(
                width: 36,
                child: level == 'SHS'
                    ? levelBadge(
                        'SHS',
                        isDark
                            ? const Color(0xFFB39DDB).withValues(alpha: 0.14)
                            : Colors.purple.shade50,
                        isDark ? const Color(0xFFB39DDB) : Colors.purple.shade700,
                      )
                    : level == 'JHS'
                    ? levelBadge(
                        'JHS',
                        isDark
                            ? const Color(0xFF80CBC4).withValues(alpha: 0.14)
                            : Colors.teal.shade50,
                        isDark ? const Color(0xFF80CBC4) : Colors.teal.shade700,
                      )
                    : levelBadge(
                        'ALL',
                        isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                        isDark
                            ? AppColors.darkTextSecondary
                            : Colors.grey.shade600,
                      ),
              ),
              const SizedBox(width: 8),
              // Name
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              // Count: (count of missing documents / overall total missing documents)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFD67878).withValues(alpha: 0.14)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFD67878).withValues(alpha: 0.3)
                        : Colors.red.shade200,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${item.count} / $totalMissingAll',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFD67878)
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Slim underline progress bar
          LayoutBuilder(
            builder: (context, bc) => Stack(
              children: [
                Container(
                  height: 3.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 3.5,
                  width: bc.maxWidth * pct,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFFE5A663), Color(0xFFD67878)]
                          : const [Colors.orange, Colors.redAccent],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: isDesktop ? 460 : null,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header with show/hide ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missing Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How many documents are missing from each requirement type.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Show/Hide toggle
              if (!isDesktop)
                TextButton.icon(
                  onPressed: () =>
                      ref
                              .read(missingDocsFilterExpandedProvider.notifier)
                              .state =
                          !isFilterExpanded,
                  icon: Icon(
                    isFilterExpanded
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  label: Text(
                    isFilterExpanded ? 'Hide' : 'Show',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (isDesktop) const SizedBox(height: AppSizes.p24),

          // ── Expandable content ─────────────────────────────────────────────
          if (isDesktop)
            Expanded(
              child: breakdown.isEmpty
                  ? _emptyWidget(
                      'No missing document requirements found. Compliance is 100%!',
                    )
                  : ListView.separated(
                      controller: _missingDocsScrollController,
                      shrinkWrap: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: breakdown.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          buildMissingDocRow(breakdown[index]),
                    ),
            )
          else
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.p24),
                  if (breakdown.isEmpty)
                    _emptyWidget(
                      'No missing document requirements found. Compliance is 100%!',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: breakdown.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          buildMissingDocRow(breakdown[index]),
                    ),
                ],
              ),
              crossFadeState: isFilterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
        ],
      ),
    );
  }

  // ── Missing Documents Hover Tooltip (Theme Responsive) ──────────────────────
  Widget _buildMissingDocsTooltip({
    required BuildContext context,
    required int missingCount,
    required String? missingRequirementsStr,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    InlineSpan richMessage;

    if (missingCount == 0 ||
        missingRequirementsStr == null ||
        missingRequirementsStr.trim().isEmpty) {
      richMessage = TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: isDark ? const Color(0xFF76BA8A) : Colors.green.shade700,
              ),
            ),
          ),
          TextSpan(
            text: 'All documents completed',
            style: TextStyle(
              color: isDark ? const Color(0xFF76BA8A) : Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else {
      final rawList = missingRequirementsStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final jhsDocs = rawList
          .where((d) => d.toUpperCase().startsWith('[JHS]'))
          .map((d) => d.replaceFirst(RegExp(r'^\[JHS\]\s*', caseSensitive: false), '').trim())
          .toList();
      final shsDocs = rawList
          .where((d) => d.toUpperCase().startsWith('[SHS]'))
          .map((d) => d.replaceFirst(RegExp(r'^\[SHS\]\s*', caseSensitive: false), '').trim())
          .toList();
      final otherDocs = rawList
          .where((d) =>
              !d.toUpperCase().startsWith('[JHS]') &&
              !d.toUpperCase().startsWith('[SHS]'))
          .map((d) => d.trim())
          .toList();

      final spanChildren = <InlineSpan>[
        TextSpan(
          text: 'Missing Documents ($missingCount):\n',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ];

      if (jhsDocs.isNotEmpty) {
        spanChildren.add(
          TextSpan(
            text: '\nJHS Requirements:\n',
            style: TextStyle(
              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        );
        for (final doc in jhsDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      if (shsDocs.isNotEmpty) {
        spanChildren.add(
          TextSpan(
            text: '\nSHS Requirements:\n',
            style: TextStyle(
              color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF6A1B9A),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        );
        for (final doc in shsDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      if (otherDocs.isNotEmpty) {
        if (jhsDocs.isNotEmpty || shsDocs.isNotEmpty) {
          spanChildren.add(
            TextSpan(
              text: '\nOther Requirements:\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          );
        }
        for (final doc in otherDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      richMessage = TextSpan(children: spanChildren);
    }

    return Tooltip(
      richMessage: richMessage,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      preferBelow: false,
      child: child,
    );
  }

  Widget _buildHorizontalScrollHint(BuildContext context, {String text = 'Scroll horizontally to view more'}) {
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

  // ── Interactive Compliance Table ──────────────────────────────────────────
  Widget _buildComplianceTable(ReportStats data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showOnlyMissing = ref.watch(showOnlyMissingDocsProvider);
    final activeYearId = ref.watch(selectedAcademicYearIdProvider);
    final activeGrade = ref.watch(selectedGradeLevelProvider);
    final activeSection = ref.watch(selectedSectionIdProvider);
    final activeStatus = ref.watch(selectedStatusFilterProvider);
    final hasActiveFilters = activeYearId != null ||
        activeGrade != null ||
        activeSection != null ||
        activeStatus != null ||
        showOnlyMissing;

    // Filter students
    final filteredStudents = data.students.where((student) {
      if (showOnlyMissing && student.missingCount == 0) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchLrn = student.lrn.toLowerCase().contains(q);
        final matchName = student.fullName.toLowerCase().contains(q);
        if (!matchLrn && !matchName) return false;
      }
      return true;
    }).toList();

    // Sort students
    if (_sortColumn != null) {
      filteredStudents.sort((a, b) {
        int comparison = 0;
        switch (_sortColumn) {
          case 'lrn':
            comparison = a.lrn.compareTo(b.lrn);
            break;
          case 'name':
            comparison = a.fullName.compareTo(b.fullName);
            break;
          case 'missing':
            comparison = a.missingCount.compareTo(b.missingCount);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    final totalRows = filteredStudents.length;
    final totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 99999);
    final startIndex = (_currentPage * _rowsPerPage).clamp(0, totalRows);
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
    final paginatedStudents = totalRows == 0
        ? <ReportStudent>[]
        : filteredStudents.sublist(startIndex, endIndex);

    Widget sortableHeader(String label, String columnKey) {
      final isSelected = _sortColumn == columnKey;
      return InkWell(
        onTap: () {
          setState(() {
            if (_sortColumn == columnKey) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = columnKey;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(
              isSelected
                  ? (_sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isSelected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Document Compliance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'List of students with their document compliance status.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Total: $totalRows',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Search Field ───────────────────────────────────────────
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : null,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by student name or LRN...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                            ),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _currentPage = 0;
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // ── Clear All Chip ─────────────────────────────────────────
                if (hasActiveFilters || _searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ActionChip(
                    label: const Text(
                      'Clear filters & search',
                      style: TextStyle(fontSize: 12),
                    ),
                    avatar: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                    backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _sortColumn = null;
                        _currentPage = 0;
                      });
                      ref
                          .read(selectedAcademicYearIdProvider.notifier)
                          .select(null);
                      ref.read(selectedGradeLevelProvider.notifier).state =
                          null;
                      ref.read(selectedSectionIdProvider.notifier).state =
                          null;
                      ref.read(selectedStatusFilterProvider.notifier).state =
                          null;
                      ref.read(showOnlyMissingDocsProvider.notifier).state =
                          false;
                    },
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : null,
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppSizes.radiusLarge),
            ),
            child: LayoutBuilder(
              builder: (context, tableConstraints) {
                // On wide screens let the table fill naturally.
                // On narrow screens allow horizontal scroll.
                final isWideTable = tableConstraints.maxWidth >= 700;
                Widget tableWidget = SizedBox(
                  width: isWideTable ? tableConstraints.maxWidth : null,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.primaryGreen.withValues(alpha: 0.04),
                    ),
                    columnSpacing: isWideTable ? ((tableConstraints.maxWidth - 480) / 6).clamp(16.0, 56.0) : 16,
                  columns: [
                    DataColumn(label: sortableHeader('LRN', 'lrn')),
                    DataColumn(label: sortableHeader('Name', 'name')),
                    const DataColumn(
                      label: Text(
                        'Sex',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Grade/Sec',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(label: sortableHeader('Missing', 'missing')),
                  ],
                  rows: paginatedStudents.isEmpty
                      ? <DataRow>[
                          const DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  'No students found for these filters.',
                                ),
                              ),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                            ],
                          ),
                        ]
                      : paginatedStudents.map((student) {
                        Color? rowBg;
                        if (student.missingCount == 0) {
                          rowBg = isDark
                              ? const Color(0xFF76BA8A).withValues(alpha: 0.08)
                              : Colors.green.shade50;
                        } else if (student.missingCount >= 3) {
                          rowBg = isDark
                              ? const Color(0xFFD67878).withValues(alpha: 0.08)
                              : Colors.red.shade50;
                        }
                        return DataRow(
                          color: rowBg != null
                              ? WidgetStateProperty.all(rowBg)
                              : null,
                          onSelectChanged: (_) {
                            showStudentProfileModal(
                              context,
                              studentId: student.id,
                              userRole: widget.userRole,
                              hideEnrollmentActions: true,
                            );
                          },
                          cells: [
                            DataCell(
                              Text(
                                student.lrn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                student.fullName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            DataCell(
                              Text(
                                student.sex,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: student.status == 'Enrolled'
                                      ? (isDark
                                          ? const Color(0xFF76BA8A).withValues(alpha: 0.14)
                                          : Colors.green.shade50)
                                      : student.status == 'Graduated'
                                      ? (isDark
                                          ? const Color(0xFF7EAAD8).withValues(alpha: 0.14)
                                          : Colors.blue.shade50)
                                      : (isDark
                                          ? const Color(0xFFE5A663).withValues(alpha: 0.14)
                                          : Colors.orange.shade50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  student.status == 'Enrolled'
                                      ? 'Active'
                                      : student.status,
                                  style: TextStyle(
                                    color: student.status == 'Enrolled'
                                        ? (isDark
                                            ? const Color(0xFF76BA8A)
                                            : Colors.green.shade700)
                                        : student.status == 'Graduated'
                                        ? (isDark
                                            ? const Color(0xFF7EAAD8)
                                            : Colors.blue.shade700)
                                        : (isDark
                                            ? const Color(0xFFE5A663)
                                            : Colors.orange.shade700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${student.gradeLevel ?? 'N/A'}/${student.sectionName ?? 'N/A'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            DataCell(
                              _buildMissingDocsTooltip(
                                context: context,
                                missingCount: student.missingCount,
                                missingRequirementsStr: student.missingRequirements,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: student.missingCount > 0
                                        ? (isDark
                                            ? const Color(0xFFD67878).withValues(alpha: 0.14)
                                            : Colors.red.shade50)
                                        : (isDark
                                            ? const Color(0xFF76BA8A).withValues(alpha: 0.14)
                                            : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: student.missingCount > 0
                                          ? (isDark
                                              ? const Color(0xFFD67878).withValues(alpha: 0.3)
                                              : Colors.red.shade200)
                                          : (isDark
                                              ? const Color(0xFF76BA8A).withValues(alpha: 0.3)
                                              : Colors.green.shade200),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        student.missingCount > 0
                                            ? Icons.info_outline_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 13,
                                        color: student.missingCount > 0
                                            ? (isDark
                                                ? const Color(0xFFD67878)
                                                : Colors.red.shade700)
                                            : (isDark
                                                ? const Color(0xFF76BA8A)
                                                : Colors.green.shade700),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        student.missingCount.toString(),
                                        style: TextStyle(
                                          color: student.missingCount > 0
                                              ? (isDark
                                                  ? const Color(0xFFD67878)
                                                  : Colors.red.shade700)
                                              : (isDark
                                                  ? const Color(0xFF76BA8A)
                                                  : Colors.green.shade700),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                  ),
                );
                if (isWideTable) {
                  return tableWidget;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      controller: _tableHorizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: tableWidget,
                    ),
                    const SizedBox(height: 6),
                    _CustomHorizontalScrollBar(
                      controller: _tableHorizontalScrollController,
                      isDark: isDark,
                    ),
                    _buildHorizontalScrollHint(
                      context,
                      text: 'Scroll horizontally to view full table',
                    ),
                  ],
                );
              },
            ),
          ),
          if (totalRows > 0) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p24,
                vertical: 12,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rows per page:',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _rowsPerPage,
                            isDense: true,
                            dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                            items: const [10, 25, 50, 100].map((count) {
                              return DropdownMenuItem<int>(
                                value: count,
                                child: Text('$count'),
                              );
                            }).toList(),
                            onChanged: (newCount) {
                              if (newCount != null) {
                                setState(() {
                                  _rowsPerPage = newCount;
                                  _currentPage = 0;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        totalRows == 0
                            ? 'Showing 0 of 0'
                            : 'Showing ${startIndex + 1} - $endIndex of $totalRows',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (totalPages > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        ...List.generate(
                          totalPages,
                          (i) => i,
                        ).where((p) => (p - _currentPage).abs() <= 2).map((p) {
                          final isActive = p == _currentPage;
                          return GestureDetector(
                            onTap: () => setState(() => _currentPage = p),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primaryGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isActive
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : Colors.grey.shade300,
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  '${p + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  // ── Summary Banner ────────────────────────────────────────────────────────
  Widget _buildSummaryBanner(ReportStats data) {
    final total = data.students.length;
    final compliant = data.students.where((s) => s.missingCount == 0).length;
    final withIssues = total - compliant;
    final totalMissing = data.missingDocsBreakdown.fold<int>(
      0,
      (a, b) => a + b.count,
    );
    final complianceRate = total > 0 ? (compliant / total * 100) : 0.0;
    final rateColor = complianceRate >= 80
        ? AppColors.primaryGreen
        : complianceRate >= 50
        ? Colors.orange.shade700
        : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.08),
            AppColors.primaryGreen.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _summaryItem(Icons.people_outline, '$total', 'Students',
                AppColors.primaryGreen),
            _summaryItem(Icons.check_circle_outline, '$compliant', 'Complete',
                AppColors.primaryGreen),
            _summaryItem(Icons.warning_amber_outlined, '$withIssues',
                'Need Docs', Colors.orange.shade700),
            _summaryItem(Icons.description_outlined, '$totalMissing',
                'Missing', Colors.red.shade400),
            _summaryItem(Icons.analytics_outlined,
                '${complianceRate.toStringAsFixed(1)}%', 'Complete Rate',
                rateColor),
          ];
          if (constraints.maxWidth < 750) {
            return Wrap(
              spacing: 20,
              runSpacing: 12,
              alignment: WrapAlignment.spaceAround,
              children: items,
            );
          }
          final row = <Widget>[];
          for (int i = 0; i < items.length; i++) {
            row.add(Expanded(child: items[i]));
            if (i < items.length - 1) {
              row.add(Container(
                width: 1,
                height: 36,
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
              ));
            }
          }
          return Row(children: row);
        },
      ),
    );
  }

  Widget _summaryItem(
      IconData icon, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Status Donut Chart ───────────────────────────────────────────────────
  Widget _buildStatusDonutChart(StudentCounts counts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = counts.active +
        counts.inactive +
        counts.dropped +
        counts.transferee +
        counts.graduated;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Status Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How students are grouped by their current status.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSizes.p24),
          if (total == 0)
            _emptyWidget('No student data for current filters.')
          else ...[
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: [
                        if (counts.active > 0)
                          PieChartSectionData(
                            color: AppColors.primaryGreen,
                            value: counts.active.toDouble(),
                            title:
                                '${(counts.active / total * 100).toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (counts.inactive > 0)
                          PieChartSectionData(
                            color: Colors.blueGrey,
                            value: counts.inactive.toDouble(),
                            title:
                                '${(counts.inactive / total * 100).toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (counts.dropped > 0)
                          PieChartSectionData(
                            color: Colors.red,
                            value: counts.dropped.toDouble(),
                            title:
                                '${(counts.dropped / total * 100).toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (counts.graduated > 0)
                          PieChartSectionData(
                            color: Colors.blue,
                            value: counts.graduated.toDouble(),
                            title:
                                '${(counts.graduated / total * 100).toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (counts.transferee > 0)
                          PieChartSectionData(
                            color: Colors.orange,
                            value: counts.transferee.toDouble(),
                            title:
                                '${(counts.transferee / total * 100).toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                      centerSpaceRadius: 55,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(enabled: true),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                    AppColors.primaryGreen, 'Active (${counts.active})'),
                if (counts.inactive > 0)
                  _buildLegendItem(
                      Colors.blueGrey, 'Inactive (${counts.inactive})'),
                _buildLegendItem(Colors.red, 'Dropped (${counts.dropped})'),
                _buildLegendItem(
                    Colors.blue, 'Graduated (${counts.graduated})'),
                _buildLegendItem(
                    Colors.orange, 'Transferred (${counts.transferee})'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Grade Compliance Chart ──────────────────────────────────────────
  Widget _buildGradeComplianceChart(List<ReportStudent> students) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradeMap = <int, _GradeCompliance>{};
    for (final s in students) {
      if (s.gradeLevel == null) continue;
      final g = s.gradeLevel!;
      gradeMap.putIfAbsent(g, () => _GradeCompliance(g));
      gradeMap[g]!.total++;
      if (s.missingCount == 0) gradeMap[g]!.compliant++;
    }
    final grades = gradeMap.values.toList()
      ..sort((a, b) => a.grade.compareTo(b.grade));

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minChartWidth = (grades.length * 64.0).clamp(320.0, 1000.0);
        final bool isNarrow = constraints.maxWidth < minChartWidth;
        final double chartWidth = isNarrow ? minChartWidth : constraints.maxWidth;

        final Widget chartWidget = SizedBox(
          width: chartWidth,
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: 100,
              barGroups: grades.asMap().entries.map((entry) {
                final g = entry.value;
                final pct = g.total > 0
                    ? g.compliant / g.total * 100
                    : 0.0;
                final barColor = pct >= 80
                    ? AppColors.primaryGreen
                    : pct >= 50
                    ? Colors.orange
                    : Colors.red;
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: pct,
                      color: barColor,
                      width: grades.length <= 6 ? 36 : 22,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                      ),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= grades.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'G${grades[idx].grade}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
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
                    getTitlesWidget: (value, meta) {
                      if (value % 25 != 0) return const SizedBox.shrink();
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => isDark
                      ? AppColors.darkSurface2
                      : Colors.blueGrey.shade800,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= grades.length) return null;
                    final g = grades[groupIndex];
                    return BarTooltipItem(
                      'Grade ${g.grade}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${g.compliant}/${g.total} complete (${rod.toY.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.p24),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document Completion by Grade',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How many students per grade have all their documents.',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSizes.p24),
              if (grades.isEmpty)
                _emptyWidget('No grade data for current filters.')
              else if (!isNarrow)
                chartWidget
              else ...[
                SingleChildScrollView(
                  controller: _gradeComplianceScrollController,
                  scrollDirection: Axis.horizontal,
                  child: chartWidget,
                ),
                const SizedBox(height: 6),
                _CustomHorizontalScrollBar(
                  controller: _gradeComplianceScrollController,
                  isDark: isDark,
                ),
                _buildHorizontalScrollHint(
                  context,
                  text: 'Scroll horizontally to view all grades',
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _buildLegendItem(AppColors.primaryGreen, '≥ 80% Good'),
                  _buildLegendItem(Colors.orange, '50–79% Moderate'),
                  _buildLegendItem(Colors.red, '< 50% Critical'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _errorWidget(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: isDark ? Colors.red.shade300 : Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
      ),
    );
  }

  // â”€â”€ Yearly Comparison Chart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildYearlyComparisonChart({required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearlyAsync = ref.watch(yearlyComparisonProvider);
    final selectedYears = ref.watch(yearlyComparisonSelectedYearsProvider);
    final selectedStatuses = ref.watch(
      yearlyComparisonSelectedStatusesProvider,
    );

    // Available status options for yearly comparison
    const allStatusOptions = [
      _StatusOption(
        key: 'enrolled',
        label: 'Active',
        color: AppColors.primaryGreen,
      ),
      _StatusOption(key: 'dropped', label: 'Dropped', color: Colors.red),
      _StatusOption(key: 'graduated', label: 'Graduated', color: Colors.blue),
      _StatusOption(
        key: 'transferred',
        label: 'Transferee',
        color: Colors.orange,
      ),
    ];

    return Container(
      width: double.infinity,
      height: isDesktop ? 460 : null,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Chart Title & Filter Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students Per Year',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How student numbers changed each school year.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Underline Filter Dropdown Row ──────────────────────────────────────────
          yearlyAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox.shrink(),
            error: (_, e) => const SizedBox.shrink(),
            data: (allData) {
              // Combine all available academic years from setup and data
              final allSysYears = (ref.watch(academicYearsProvider).asData?.value ?? [])
                  .map((y) => y.yearRange)
                  .toSet();
              final allDataYears = allData.map((d) => d.year).toSet();
              final allYearStrings = {...allSysYears, ...allDataYears}.toList()
                ..sort();

              final default4 = allYearStrings.length <= 4
                  ? allYearStrings
                  : allYearStrings.sublist(allYearStrings.length - 4);

              return Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  // Year multi-select dropdown
                  _buildUnderlineDropdown(
                    label: selectedYears.isEmpty
                        ? (default4.length > 1
                            ? '${default4.first} – ${default4.last}'
                            : 'Latest 4 Years')
                        : selectedYears.length == 1
                        ? selectedYears.first
                        : selectedYears.length == allYearStrings.length
                        ? 'All Years'
                        : '${selectedYears.length} Years',
                    icon: Icons.calendar_today_outlined,
                    onTap: (btnCtx) => _showYearMultiSelectMenu(
                      btnCtx,
                      allYearStrings,
                      selectedYears,
                    ),
                  ),
                  // Status multi-select dropdown
                  _buildUnderlineDropdown(
                    label: selectedStatuses.length == allStatusOptions.length
                        ? 'All Statuses'
                        : selectedStatuses.isEmpty
                        ? 'No Status'
                        : selectedStatuses.length == 1
                        ? allStatusOptions
                              .firstWhere(
                                (o) => o.key == selectedStatuses.first,
                                orElse: () => const _StatusOption(
                                  key: '',
                                  label: '',
                                  color: Colors.grey,
                                ),
                              )
                              .label
                        : '${selectedStatuses.length} Statuses',
                    icon: Icons.people_alt_outlined,
                    onTap: (btnCtx) => _showStatusMultiSelectMenu(
                      btnCtx,
                      allStatusOptions,
                      selectedStatuses,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSizes.p24),

          // ── Chart ──────────────────────────────────────────────────────────
          yearlyAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, st) => _errorWidget('Error loading yearly data: $e'),
            data: (rawData) {
              if (rawData.isEmpty) {
                return _emptyWidget('No academic years data found.');
              }

              // Filter by selected years (ascending sort)
              var data = List<YearlyComparisonData>.from(rawData)
                ..sort((a, b) => a.year.compareTo(b.year));
              if (selectedYears.isNotEmpty) {
                data = data
                    .where((d) => selectedYears.contains(d.year))
                    .toList();
              } else {
                if (data.length > 4) {
                  data = data.sublist(data.length - 4);
                }
              }
              if (data.isEmpty) {
                return _emptyWidget('No data for selected years.');
              }

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
                  final double chartWidth =
                      constraints.maxWidth > (data.length * 150.0)
                      ? constraints.maxWidth
                      : (data.length * 150.0);
                  final Widget chartWidget = SizedBox(
                    width: chartWidth,
                    height: 300,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => isDark
                                ? AppColors.darkSurface2
                                : Colors.blueGrey.shade800,
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) {
                                  if (groupIndex >= data.length) return null;
                                  final yearData = data[groupIndex];
                                  final opt = rodIndex < activeOptions.length
                                      ? activeOptions[rodIndex]
                                      : null;
                                  if (opt == null) return null;
                                  final val = _getStatusValue(
                                    yearData,
                                    opt.key,
                                  );
                                  return BarTooltipItem(
                                    '${opt.label}\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: val.toString(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
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
                                if (value.toInt() >= data.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    data[value.toInt()].year,
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                if (value % (maxY / 5).ceil() != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontSize: 12,
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
                          horizontalInterval: (maxY / 5) > 0 ? (maxY / 5) : 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: data.asMap().entries.map((entry) {
                          final i = entry.key;
                          final d = entry.value;
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: activeOptions
                                .map(
                                  (opt) => BarChartRodData(
                                    toY: _getStatusValue(
                                      d,
                                      opt.key,
                                    ).toDouble(),
                                    color: opt.color,
                                    width: activeOptions.length > 2 ? 12 : 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                                .toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  );

                  if (chartWidth <= constraints.maxWidth) {
                    return chartWidget;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        controller: _chartHorizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: chartWidget,
                      ),
                      const SizedBox(height: 6),
                      _CustomHorizontalScrollBar(
                        controller: _chartHorizontalScrollController,
                        isDark: isDark,
                      ),
                      _buildHorizontalScrollHint(
                        context,
                        text: 'Scroll horizontally to view all years',
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Legend (dynamic based on selected statuses) ─────────────────────
          Consumer(
            builder: (context, ref, _) {
              final statuses = ref.watch(
                yearlyComparisonSelectedStatusesProvider,
              );
              const allStatusOptions = [
                _StatusOption(
                  key: 'enrolled',
                  label: 'Active',
                  color: AppColors.primaryGreen,
                ),
                _StatusOption(
                  key: 'dropped',
                  label: 'Dropped',
                  color: Colors.red,
                ),
                _StatusOption(
                  key: 'graduated',
                  label: 'Graduated',
                  color: Colors.blue,
                ),
                _StatusOption(
                  key: 'transferred',
                  label: 'Transferee',
                  color: Colors.orange,
                ),
              ];
              final active = allStatusOptions
                  .where((o) => statuses.contains(o.key))
                  .toList();
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: active
                    .map((o) => _buildLegendItem(o.color, o.label))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  int _getStatusValue(YearlyComparisonData data, String key) {
    switch (key) {
      case 'enrolled':
        return data.enrolled;
      case 'dropped':
        return data.dropped;
      case 'graduated':
        return data.graduated;
      case 'transferred':
        return data.transferred;
      default:
        return 0;
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
            border: Border(
              bottom: BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a popup multi-select menu for years
  void _showYearMultiSelectMenu(
    BuildContext context,
    List<String> allYears,
    Set<String> selected,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
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
              final currentSelected = ref.watch(
                yearlyComparisonSelectedYearsProvider,
              );
              final default4 = allYears.length <= 4
                  ? allYears.toSet()
                  : allYears.sublist(allYears.length - 4).toSet();

              return SizedBox(
                width: 290,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select School Years',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        yearlyComparisonSelectedYearsProvider
                                            .notifier,
                                      )
                                      .setYears(default4);
                                },
                                child: const Text(
                                  'Latest 4',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        yearlyComparisonSelectedYearsProvider
                                            .notifier,
                                      )
                                      .setYears(allYears.toSet());
                                },
                                child: const Text(
                                  'All Years',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        yearlyComparisonSelectedYearsProvider
                                            .notifier,
                                      )
                                      .clear();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView(
                        shrinkWrap: true,
                        children: allYears.map((year) {
                          final isChecked = currentSelected.isEmpty
                              ? default4.contains(year)
                              : currentSelected.contains(year);
                          return CheckboxListTile(
                            dense: true,
                            value: isChecked,
                            title: Text(year, style: const TextStyle(fontSize: 13)),
                            activeColor: AppColors.primaryGreen,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              if (currentSelected.isEmpty) {
                                final updated = Set<String>.from(default4);
                                if (updated.contains(year)) {
                                  updated.remove(year);
                                } else {
                                  updated.add(year);
                                }
                                ref
                                    .read(
                                      yearlyComparisonSelectedYearsProvider
                                          .notifier,
                                    )
                                    .setYears(updated);
                              } else {
                                ref
                                    .read(
                                      yearlyComparisonSelectedYearsProvider
                                          .notifier,
                                    )
                                    .toggle(year);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Shows a popup multi-select menu for statuses
  void _showStatusMultiSelectMenu(
    BuildContext context,
    List<_StatusOption> options,
    Set<String> selected,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
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
              final currentSelected = ref.watch(
                yearlyComparisonSelectedStatusesProvider,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Text(
                          'Select Statuses',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(
                                  yearlyComparisonSelectedStatusesProvider
                                      .notifier,
                                )
                                .selectAll();
                          },
                          child: const Text(
                            'All',
                            style: TextStyle(fontSize: 12),
                          ),
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
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: opt.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(opt.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      activeColor: AppColors.primaryGreen,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        ref
                            .read(
                              yearlyComparisonSelectedStatusesProvider.notifier,
                            )
                            .toggle(opt.key);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Helper data class for grade compliance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _GradeCompliance {
  final int grade;
  int total = 0;
  int compliant = 0;
  _GradeCompliance(this.grade);
}

// â”€â”€ Helper data class for status options â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StatusOption {
  final String key;
  final String label;
  final Color color;
  const _StatusOption({
    required this.key,
    required this.label,
    required this.color,
  });
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
