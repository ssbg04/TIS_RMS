import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/report_models.dart';

class TransparencyBoardPdfService {
  static Future<Uint8List> generatePdf({
    required TransparencyBoardData data,
    String? schoolName,
    String? divisionName,
    String? regionName,
  }) async {
    final pdf = pw.Document();

    final years = data.years;
    final latestYear = years.isNotEmpty ? years.last : null;
    final previousYear = years.length > 1 ? years[years.length - 2] : null;
    final hasPrev = previousYear != null;

    final activeSyLabel = latestYear != null ? 'SY ${latestYear.yearRange}' : 'N/A';
    final prevSyLabel = hasPrev ? 'SY ${previousYear.yearRange}' : 'Previous SY';

    final generatedDate = DateTime.now().toString().substring(0, 19);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context context) => _buildPdfHeader(
          activeSyLabel: activeSyLabel,
          prevSyLabel: prevSyLabel,
          hasPrev: hasPrev,
          generatedDate: generatedDate,
          schoolName: schoolName ?? 'TIAONG INTEGRATED SCHOOL',
          divisionName: divisionName ?? 'DIVISION OF QUEZON',
          regionName: regionName ?? 'REGION IV-A CALABARZON',
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TIS-RMS DepEd Transparency Report',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          if (years.isEmpty || latestYear == null) {
            return [
              pw.Center(
                child: pw.Text(
                  'No transparency board data available to generate report.',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ];
          }

          return [
            pw.SizedBox(height: 12),

            // ── Section 1: Data on Enrollment ────────────────────────────────
            _buildSectionHeader('1. DATA ON ENROLLMENT'),
            pw.SizedBox(height: 6),
            _buildEnrollmentComparisonTable(
              latestYear: latestYear,
              previousYear: previousYear,
              hasPrev: hasPrev,
              prevLabel: prevSyLabel,
              currentLabel: activeSyLabel,
            ),
            pw.SizedBox(height: 14),

            // ── Section 2: Dropouts & Transferees ────────────────────────────
            _buildSectionHeader('2. DROPOUTS & TRANSFEREES'),
            pw.SizedBox(height: 6),
            pw.Text(
              'A. Dropouts Summary',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
            ),
            pw.SizedBox(height: 4),
            _buildMultiYearDropoutTable(years: years),
            pw.SizedBox(height: 8),
            pw.Text(
              'B. Transferees Summary',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
            ),
            pw.SizedBox(height: 4),
            _buildMultiYearTransfereeTable(years: years),
            pw.SizedBox(height: 14),

            // ── Section 3: 4Ps Beneficiaries ──────────────────────────────────
            _buildSectionHeader('3. 4Ps BENEFICIARIES'),
            pw.SizedBox(height: 6),
            _buildFourPsComparisonTable(
              latestYear: latestYear,
              previousYear: previousYear,
              hasPrev: hasPrev,
              prevLabel: prevSyLabel,
              currentLabel: activeSyLabel,
            ),
            pw.SizedBox(height: 24),

            // ── Signatory Footer ─────────────────────────────────────────────
            _buildSignatoryBlock(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Header Component ───────────────────────────────────────────────────────

  static pw.Widget _buildPdfHeader({
    required String activeSyLabel,
    required String prevSyLabel,
    required bool hasPrev,
    required String generatedDate,
    required String schoolName,
    required String divisionName,
    required String regionName,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Republic of the Philippines',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          'Department of Education',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.Text(
          '$regionName • $divisionName',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
        pw.Text(
          schoolName,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.green800,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'DEPED TRANSPARENCY & SCHOOL PERFORMANCE BOARD REPORT',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 0.4,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              hasPrev
                  ? 'Reference Period: $prevSyLabel vs. $activeSyLabel'
                  : 'Reference Period: $activeSyLabel (Baseline)',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            pw.Text(
              'Date Generated: $generatedDate',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 1: Data on Enrollment Table ─────────────────────────────────────

  static pw.Widget _buildEnrollmentComparisonTable({
    required YearlyTransparencyItem latestYear,
    required YearlyTransparencyItem? previousYear,
    required bool hasPrev,
    required String prevLabel,
    required String currentLabel,
  }) {
    final border = const pw.TableBorder(
      left: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      right: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      verticalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    );

    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green100),
          children: [
            _cellText('Key Stage / Grade Level', isHeader: true),
            _cellText(prevLabel, isHeader: true, align: pw.TextAlign.center),
            _cellText(currentLabel, isHeader: true, align: pw.TextAlign.center),
            _cellText('Difference', isHeader: true, align: pw.TextAlign.center),
            _cellText('Remarks', isHeader: true, align: pw.TextAlign.center),
          ],
        ),

        // Key Stage 3 Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('KEY STAGE 3 (JUNIOR HIGH SCHOOL)', isBold: true),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
          ],
        ),

        // JHS Grades 7-10
        ...[7, 8, 9, 10].map((grade) {
          final currRow = latestYear.enrollment.grades.firstWhere(
            (g) => g.gradeLevel == grade,
            orElse: () => GradeEnrollmentBreakdown(gradeLevel: grade, male: 0, female: 0, total: 0),
          );
          final prevRow = hasPrev
              ? previousYear!.enrollment.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => GradeEnrollmentBreakdown(gradeLevel: grade, male: 0, female: 0, total: 0),
                )
              : null;

          final curr = currRow.total;
          final prev = prevRow?.total;
          final diff = hasPrev ? (curr - (prev ?? 0)) : null;

          return pw.TableRow(
            children: [
              _cellText('  Grade $grade'),
              _cellText(hasPrev ? '$prev' : '—', align: pw.TextAlign.center),
              _cellText('$curr', align: pw.TextAlign.center, isBold: true),
              _cellDifference(diff, hasPrev),
              _cellRemark(diff, hasPrev),
            ],
          );
        }),

        // JHS Subtotal
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('Key Stage 3 (JHS) Subtotal', isBold: true),
            _cellText(hasPrev ? '${previousYear!.enrollment.jhsTotal.total}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.enrollment.jhsTotal.total}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.green900),
            _cellDifference(
              hasPrev ? (latestYear.enrollment.jhsTotal.total - previousYear!.enrollment.jhsTotal.total) : null,
              hasPrev,
              isBold: true,
            ),
            _cellRemark(
              hasPrev ? (latestYear.enrollment.jhsTotal.total - previousYear!.enrollment.jhsTotal.total) : null,
              hasPrev,
            ),
          ],
        ),

        // Key Stage 4 Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('KEY STAGE 4 (SENIOR HIGH SCHOOL)', isBold: true),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
          ],
        ),

        // SHS Grades 11-12
        ...[11, 12].map((grade) {
          final currRow = latestYear.enrollment.grades.firstWhere(
            (g) => g.gradeLevel == grade,
            orElse: () => GradeEnrollmentBreakdown(gradeLevel: grade, male: 0, female: 0, total: 0),
          );
          final prevRow = hasPrev
              ? previousYear!.enrollment.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => GradeEnrollmentBreakdown(gradeLevel: grade, male: 0, female: 0, total: 0),
                )
              : null;

          final curr = currRow.total;
          final prev = prevRow?.total;
          final diff = hasPrev ? (curr - (prev ?? 0)) : null;

          return pw.TableRow(
            children: [
              _cellText('  Grade $grade'),
              _cellText(hasPrev ? '$prev' : '—', align: pw.TextAlign.center),
              _cellText('$curr', align: pw.TextAlign.center, isBold: true),
              _cellDifference(diff, hasPrev),
              _cellRemark(diff, hasPrev),
            ],
          );
        }),

        // SHS Subtotal
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('Key Stage 4 (SHS) Subtotal', isBold: true),
            _cellText(hasPrev ? '${previousYear!.enrollment.shsTotal.total}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.enrollment.shsTotal.total}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.green900),
            _cellDifference(
              hasPrev ? (latestYear.enrollment.shsTotal.total - previousYear!.enrollment.shsTotal.total) : null,
              hasPrev,
              isBold: true,
            ),
            _cellRemark(
              hasPrev ? (latestYear.enrollment.shsTotal.total - previousYear!.enrollment.shsTotal.total) : null,
              hasPrev,
            ),
          ],
        ),

        // Overall Total Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _cellText('OVERALL ENROLLMENT TOTAL', isBold: true, textColor: PdfColors.green900),
            _cellText(hasPrev ? '${previousYear!.enrollment.overallTotal.total}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.enrollment.overallTotal.total}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.green900),
            _cellDifference(
              hasPrev ? (latestYear.enrollment.overallTotal.total - previousYear!.enrollment.overallTotal.total) : null,
              hasPrev,
              isBold: true,
            ),
            _cellRemark(
              hasPrev ? (latestYear.enrollment.overallTotal.total - previousYear!.enrollment.overallTotal.total) : null,
              hasPrev,
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 2: Dropouts & Transferees Tables ───────────────────────────────

  static pw.Widget _buildMultiYearDropoutTable({required List<YearlyTransparencyItem> years}) {
    final grades = [7, 8, 9, 10, 11, 12];
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
    };
    for (int i = 0; i < years.length; i++) {
      colWidths[i + 1] = const pw.FlexColumnWidth(1.2);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.red50),
          children: [
            _cellText('Grade Level', isHeader: true),
            ...years.map((y) => _cellText('SY ${y.yearRange}', isHeader: true, align: pw.TextAlign.center)),
          ],
        ),
        ...grades.map((grade) {
          return pw.TableRow(
            children: [
              _cellText('Grade $grade'),
              ...years.map((y) {
                final row = y.dropouts.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => GradeDropoutCount(gradeLevel: grade, droppedCount: 0),
                );
                return _cellText('${row.droppedCount}', align: pw.TextAlign.center);
              }),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.red100),
          children: [
            _cellText('Total Dropouts', isBold: true, textColor: PdfColors.red900),
            ...years.map((y) => _cellText('${y.dropouts.totalDropped}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.red900)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMultiYearTransfereeTable({required List<YearlyTransparencyItem> years}) {
    final grades = [7, 8, 9, 10, 11, 12];
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
    };
    for (int i = 0; i < years.length; i++) {
      colWidths[i + 1] = const pw.FlexColumnWidth(1.2);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.orange50),
          children: [
            _cellText('Grade Level', isHeader: true),
            ...years.map((y) => _cellText('SY ${y.yearRange}', isHeader: true, align: pw.TextAlign.center)),
          ],
        ),
        ...grades.map((grade) {
          return pw.TableRow(
            children: [
              _cellText('Grade $grade'),
              ...years.map((y) {
                final row = y.transferees.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => GradeTransfereeCount(gradeLevel: grade, transferredCount: 0),
                );
                return _cellText('${row.transferredCount}', align: pw.TextAlign.center);
              }),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.orange100),
          children: [
            _cellText('Total Transferees', isBold: true, textColor: PdfColors.orange900),
            ...years.map((y) => _cellText('${y.transferees.totalTransferred}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.orange900)),
          ],
        ),
      ],
    );
  }

  // ── Section 3: 4Ps Beneficiaries Table ─────────────────────────────────────

  static pw.Widget _buildFourPsComparisonTable({
    required YearlyTransparencyItem latestYear,
    required YearlyTransparencyItem? previousYear,
    required bool hasPrev,
    required String prevLabel,
    required String currentLabel,
  }) {
    final border = const pw.TableBorder(
      left: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      right: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      verticalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    );

    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FlexColumnWidth(2.8),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.3),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.purple50),
          children: [
            _cellText('Key Stage / Grade Level', isHeader: true),
            _cellText(prevLabel, isHeader: true, align: pw.TextAlign.center),
            _cellText(currentLabel, isHeader: true, align: pw.TextAlign.center),
            _cellText('Difference', isHeader: true, align: pw.TextAlign.center),
            _cellText('4Ps Share', isHeader: true, align: pw.TextAlign.center),
            _cellText('Remarks', isHeader: true, align: pw.TextAlign.center),
          ],
        ),

        // Key Stage 3 Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('KEY STAGE 3 (JUNIOR HIGH SCHOOL)', isBold: true),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
          ],
        ),

        // JHS Grades 7-10
        ...[7, 8, 9, 10].map((grade) {
          final currRow = latestYear.fourPs.grades.firstWhere(
            (g) => g.gradeLevel == grade,
            orElse: () => Grade4PsCount(gradeLevel: grade, fourPsCount: 0, totalStudents: 0, percentage: 0.0),
          );
          final prevRow = hasPrev
              ? previousYear!.fourPs.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => Grade4PsCount(gradeLevel: grade, fourPsCount: 0, totalStudents: 0, percentage: 0.0),
                )
              : null;

          final curr = currRow.fourPsCount;
          final prev = prevRow?.fourPsCount;
          final diff = hasPrev ? (curr - (prev ?? 0)) : null;

          return pw.TableRow(
            children: [
              _cellText('  Grade $grade'),
              _cellText(hasPrev ? '$prev' : '—', align: pw.TextAlign.center),
              _cellText('$curr', align: pw.TextAlign.center, isBold: true),
              _cellDifference(diff, hasPrev),
              _cellText('${currRow.percentage}%', align: pw.TextAlign.center, textColor: PdfColors.purple900, isBold: true),
              _cellRemark(diff, hasPrev),
            ],
          );
        }),

        // JHS Subtotal
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('Key Stage 3 (JHS) Subtotal', isBold: true),
            _cellText(hasPrev ? '${previousYear!.fourPs.jhsTotal.fourPsCount}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.fourPs.jhsTotal.fourPsCount}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellDifference(
              hasPrev ? (latestYear.fourPs.jhsTotal.fourPsCount - previousYear!.fourPs.jhsTotal.fourPsCount) : null,
              hasPrev,
              isBold: true,
            ),
            _cellText('${latestYear.fourPs.jhsTotal.percentage}%', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellRemark(
              hasPrev ? (latestYear.fourPs.jhsTotal.fourPsCount - previousYear!.fourPs.jhsTotal.fourPsCount) : null,
              hasPrev,
            ),
          ],
        ),

        // Key Stage 4 Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('KEY STAGE 4 (SENIOR HIGH SCHOOL)', isBold: true),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
            _cellText(''),
          ],
        ),

        // SHS Grades 11-12
        ...[11, 12].map((grade) {
          final currRow = latestYear.fourPs.grades.firstWhere(
            (g) => g.gradeLevel == grade,
            orElse: () => Grade4PsCount(gradeLevel: grade, fourPsCount: 0, totalStudents: 0, percentage: 0.0),
          );
          final prevRow = hasPrev
              ? previousYear!.fourPs.grades.firstWhere(
                  (g) => g.gradeLevel == grade,
                  orElse: () => Grade4PsCount(gradeLevel: grade, fourPsCount: 0, totalStudents: 0, percentage: 0.0),
                )
              : null;

          final curr = currRow.fourPsCount;
          final prev = prevRow?.fourPsCount;
          final diff = hasPrev ? (curr - (prev ?? 0)) : null;

          return pw.TableRow(
            children: [
              _cellText('  Grade $grade'),
              _cellText(hasPrev ? '$prev' : '—', align: pw.TextAlign.center),
              _cellText('$curr', align: pw.TextAlign.center, isBold: true),
              _cellDifference(diff, hasPrev),
              _cellText('${currRow.percentage}%', align: pw.TextAlign.center, textColor: PdfColors.purple900, isBold: true),
              _cellRemark(diff, hasPrev),
            ],
          );
        }),

        // SHS Subtotal
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cellText('Key Stage 4 (SHS) Subtotal', isBold: true),
            _cellText(hasPrev ? '${previousYear!.fourPs.shsTotal.fourPsCount}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.fourPs.shsTotal.fourPsCount}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellDifference(
              hasPrev ? (latestYear.fourPs.shsTotal.fourPsCount - previousYear!.fourPs.shsTotal.fourPsCount) : null,
              hasPrev,
              isBold: true,
            ),
            _cellText('${latestYear.fourPs.shsTotal.percentage}%', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellRemark(
              hasPrev ? (latestYear.fourPs.shsTotal.fourPsCount - previousYear!.fourPs.shsTotal.fourPsCount) : null,
              hasPrev,
            ),
          ],
        ),

        // Overall Total Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.purple100),
          children: [
            _cellText('OVERALL 4Ps BENEFICIARIES TOTAL', isBold: true, textColor: PdfColors.purple900),
            _cellText(hasPrev ? '${previousYear!.fourPs.overallTotal.fourPsCount}' : '—', isBold: true, align: pw.TextAlign.center),
            _cellText('${latestYear.fourPs.overallTotal.fourPsCount}', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellDifference(
              hasPrev ? (latestYear.fourPs.overallTotal.fourPsCount - previousYear!.fourPs.overallTotal.fourPsCount) : null,
              hasPrev,
              isBold: true,
            ),
            _cellText('${latestYear.fourPs.overallTotal.percentage}%', isBold: true, align: pw.TextAlign.center, textColor: PdfColors.purple900),
            _cellRemark(
              hasPrev ? (latestYear.fourPs.overallTotal.fourPsCount - previousYear!.fourPs.overallTotal.fourPsCount) : null,
              hasPrev,
            ),
          ],
        ),
      ],
    );
  }

  // ── Signatory Block ────────────────────────────────────────────────────────

  static pw.Widget _buildSignatoryBlock() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _signatoryColumn(
          title: 'Prepared by:',
          line: '________________________________',
          role: 'Class Adviser / Guidance Counselor',
        ),
        _signatoryColumn(
          title: 'Verified by:',
          line: '________________________________',
          role: 'Planning Officer / Assistant Principal',
        ),
        _signatoryColumn(
          title: 'Approved by:',
          line: '________________________________',
          role: 'School Principal / Head Teacher',
        ),
      ],
    );
  }

  static pw.Widget _signatoryColumn({
    required String title,
    required String line,
    required String role,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 28),
        pw.Text(line, style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 2),
        pw.Text(role, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
      ],
    );
  }

  // ── Helper Cell Renderers ──────────────────────────────────────────────────

  static pw.Widget _cellText(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColors.black : PdfColors.grey900),
        ),
      ),
    );
  }

  static pw.Widget _cellDifference(int? diff, bool hasPrev, {bool isBold = false}) {
    if (!hasPrev || diff == null) {
      return _cellText('—', align: pw.TextAlign.center);
    }
    final text = diff > 0 ? '+$diff' : '$diff';
    final color = diff > 0
        ? PdfColors.green800
        : (diff < 0 ? PdfColors.red800 : PdfColors.grey700);

    return _cellText(text, align: pw.TextAlign.center, isBold: true, textColor: color);
  }

  static pw.Widget _cellRemark(int? diff, bool hasPrev) {
    if (!hasPrev || diff == null) {
      return _cellText('Baseline', align: pw.TextAlign.center, textColor: PdfColors.grey600);
    }
    if (diff > 0) {
      return _cellText('Increasing', align: pw.TextAlign.center, isBold: true, textColor: PdfColors.green800);
    } else if (diff < 0) {
      return _cellText('Decreasing', align: pw.TextAlign.center, isBold: true, textColor: PdfColors.red800);
    } else {
      return _cellText('Maintained', align: pw.TextAlign.center, textColor: PdfColors.grey700);
    }
  }
}
