import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../../../core/constants/app_colors.dart';

typedef SpreadsheetSheetInput = ({String name, List<List<String>> rows});

class SpreadsheetPdfResult {
  final Uint8List pdfBytes;
  final int sheetCount;
  final int totalRows;

  const SpreadsheetPdfResult({
    required this.pdfBytes,
    required this.sheetCount,
    required this.totalRows,
  });
}

/// Converts Excel (`.xlsx`) bytes into a formatted multi-page PDF for previewing.
Future<SpreadsheetPdfResult> buildPdfFromSpreadsheetBytes(
  List<int>? fileBytes, {
  List<SpreadsheetSheetInput> fallbackSheets = const [],
  int maxPreviewRowsPerSheet = 200,
}) async {
  final doc = pw.Document();
  final sheetSections = <SpreadsheetSheetInput>[];

  if (fileBytes != null && fileBytes.isNotEmpty) {
    try {
      final decoder = SpreadsheetDecoder.decodeBytes(fileBytes, update: false);
      for (final entry in decoder.tables.entries) {
        final rows = entry.value.rows
            .map((r) => r.map((c) => c?.toString() ?? '').toList())
            .where((r) => r.any((c) => c.trim().isNotEmpty))
            .toList();
        if (rows.isNotEmpty) {
          sheetSections.add((name: entry.key, rows: rows));
        }
      }
    } catch (_) {
      // Fall back to provided sheet data if raw xlsx decode fails
    }
  }

  if (sheetSections.isEmpty && fallbackSheets.isNotEmpty) {
    for (final s in fallbackSheets) {
      if (s.rows.isNotEmpty) {
        sheetSections.add(s);
      }
    }
  }

  final totalRows = sheetSections.fold<int>(0, (acc, s) => acc + s.rows.length);

  if (sheetSections.isEmpty) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(
          child: pw.Text(
            'No spreadsheet data available for preview.',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
    return SpreadsheetPdfResult(
      pdfBytes: await doc.save(),
      sheetCount: 0,
      totalRows: 0,
    );
  }

  for (final sheet in sheetSections) {
    final rawRows = sheet.rows;
    final maxCols = rawRows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final normalized = rawRows.take(maxPreviewRowsPerSheet).map((r) {
      if (r.length == maxCols) return r;
      return [...r, ...List.filled(maxCols - r.length, '')];
    }).toList();

    final headers = normalized.first;
    final dataRows = normalized.length > 1 ? normalized.sublist(1) : <List<String>>[];
    final truncatedCount = rawRows.length - normalized.length;
    final pageFormat =
        maxCols > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                sheet.name,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1D6F42),
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1D6F42),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 3.5,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
            ),
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          if (truncatedCount > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '+ $truncatedCount more rows included in Excel file',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  return SpreadsheetPdfResult(
    pdfBytes: await doc.save(),
    sheetCount: sheetSections.length,
    totalRows: totalRows,
  );
}

/// Minimalist, theme-aware PDF preview widget using `printing`'s `PdfPreview`.
class MinimalPdfPreviewView extends StatelessWidget {
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;
  final bool isDark;
  final Widget? errorFallback;

  const MinimalPdfPreviewView({
    super.key,
    required this.buildPdf,
    required this.isDark,
    this.errorFallback,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkPageBackground : const Color(0xFFF3F4F6);
    return Container(
      color: bgColor,
      child: PdfPreview(
        build: buildPdf,
        useActions: false,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        scrollViewDecoration: BoxDecoration(color: bgColor),
        loadingWidget: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
        onError: (ctx, err) =>
            errorFallback ??
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to render PDF preview.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

