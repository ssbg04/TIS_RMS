import 'dart:math' as math;
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Converts an Excel workbook into a single multi-page PDF — one page (or
/// chunk of pages) per sheet tab, rendered as a bordered grid.
Future<Uint8List> convertExcelBytesToPdf(
  List<int> bytes, {
  int maxRows = 500,
  int maxCols = 30,
}) async {
  final excel = Excel.decodeBytes(bytes);
  final doc = pw.Document();
  final sheetNames = excel.tables.keys.toList();

  if (sheetNames.isEmpty) {
    doc.addPage(_noDataPage('Workbook contains no sheets.'));
    return doc.save();
  }

  for (final name in sheetNames) {
    final sheet = excel.tables[name];
    if (sheet == null || sheet.rows.isEmpty) continue;
    final rows = _extractSheetRows(sheet, maxRows, maxCols);
    if (rows.isEmpty) continue;

    final colCount = rows
        .map((r) => r.length)
        .fold<int>(0, (acc, len) => len > acc ? len : acc);

    const rowsPerPage = 60;
    final pageCount = (rows.length / rowsPerPage).ceil();
    for (var start = 0; start < rows.length; start += rowsPerPage) {
      final end = math.min(start + rowsPerPage, rows.length);
      final pageNo = start ~/ rowsPerPage + 1;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.legal,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
              if (pageCount > 1) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Page $pageNo of $pageCount',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.4,
                ),
                columnWidths: {
                  for (var c = 0; c < colCount; c++)
                    c: pw.FlexColumnWidth(1),
                },
                children: _buildChunkRows(start, end, rows, colCount),
              ),
            ],
          ),
        ),
      );
    }
  }

  return doc.save();
}

pw.Page _noDataPage(String message) {
  return pw.Page(
    pageFormat: PdfPageFormat.legal,
    build: (_) => pw.Center(
      child: pw.Text(message, style: const pw.TextStyle(fontSize: 12)),
    ),
  );
}

List<List<String>> _extractSheetRows(Sheet sheet, int maxRows, int maxCols) {
  final rows = <List<String>>[];
  for (var r = 0; r < sheet.rows.length && r < maxRows; r++) {
    final row = sheet.rows[r];
    final rowCells = <String>[];
    final colLimit = math.min(row.length, maxCols);
    for (var c = 0; c < colLimit; c++) {
      rowCells.add(_cellToString(row[c]));
    }
    if (rowCells.any((v) => v.trim().isNotEmpty)) {
      rows.add(rowCells);
    }
  }
  return rows;
}

String _cellToString(Data? cell) {
  if (cell == null || cell.value == null) return '';
  final val = cell.value;
  try {
    if (val is TextCellValue) return val.value.toString();
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    if (val is BoolCellValue) return val.value ? 'TRUE' : 'FALSE';
    return val.toString();
  } catch (_) {
    return val.toString();
  }
}

List<pw.TableRow> _buildChunkRows(
  int start,
  int end,
  List<List<String>> rows,
  int colCount,
) {
  final out = <pw.TableRow>[];
  for (var r = start; r < end; r++) {
    final row = rows[r];
    final cells = <pw.Widget>[];
    for (var c = 0; c < colCount; c++) {
      cells.add(_cellWidget(c < row.length ? row[c] : '', bold: r == 0));
    }
    out.add(pw.TableRow(children: cells));
  }
  return out;
}

pw.Widget _cellWidget(String text, {required bool bold}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(2),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
