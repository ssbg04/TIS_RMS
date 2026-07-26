import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';

/// Background isolate function to decode CSV bytes without blocking UI thread.
Map<String, List<List<String>>> _decodeCsvInBackground(List<int> bytes) {
  final content = utf8.decode(bytes);
  final lines = content.split('\n');
  final List<List<String>> rows = [];
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    if (rows.length >= 500) break; // Cap at 500 rows for mobile/desktop instant preview
    final cols = line.split(',').map((e) => e.trim()).toList();
    if (cols.length > 30) {
      rows.add(cols.sublist(0, 30));
    } else {
      rows.add(cols);
    }
  }
  return {'Sheet 1': rows};
}

/// Background isolate function to decode Excel bytes without blocking UI thread.
Map<String, List<List<String>>> _decodeExcelInBackground(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  final Map<String, List<List<String>>> parsedSheets = {};

  for (final table in excel.tables.keys) {
    final sheet = excel.tables[table];
    if (sheet == null || sheet.rows.isEmpty) continue;

    // 1st pass: find the actual last non-empty row and column in the sheet
    int maxNonEmptyRow = -1;
    int maxNonEmptyCol = -1;
    final int rowLimit = math.min(sheet.rows.length, 500); // Cap at 500 rows

    for (int r = 0; r < rowLimit; r++) {
      final row = sheet.rows[r];
      final int colLimit = math.min(row.length, 30); // Cap at 30 columns
      for (int c = 0; c < colLimit; c++) {
        final cell = row[c];
        if (cell != null &&
            cell.value != null &&
            cell.value.toString().trim().isNotEmpty) {
          if (r > maxNonEmptyRow) maxNonEmptyRow = r;
          if (c > maxNonEmptyCol) maxNonEmptyCol = c;
        }
      }
    }

    if (maxNonEmptyRow == -1 || maxNonEmptyCol == -1) {
      continue; // Skip completely empty sheets
    }

    // 2nd pass: extract ONLY up to maxNonEmptyRow and maxNonEmptyCol
    final List<List<String>> sheetRows = [];
    for (int r = 0; r <= maxNonEmptyRow; r++) {
      final row = sheet.rows[r];
      final List<String> rowCells = [];
      for (int c = 0; c <= maxNonEmptyCol; c++) {
        String valStr = '';
        if (c < row.length) {
          final cell = row[c];
          if (cell != null && cell.value != null) {
            final val = cell.value;
            try {
              if (val is TextCellValue) {
                valStr = val.value.toString();
              } else if (val is IntCellValue) {
                valStr = val.value.toString();
              } else if (val is DoubleCellValue) {
                valStr = val.value.toString();
              } else if (val is BoolCellValue) {
                valStr = val.value ? 'TRUE' : 'FALSE';
              } else {
                valStr = val.toString();
              }
            } catch (_) {
              valStr = val.toString();
            }
          }
        }
        rowCells.add(valStr);
      }
      sheetRows.add(rowCells);
    }
    parsedSheets[table] = sheetRows;
  }
  return parsedSheets;
}

class ExcelViewerWidget extends StatefulWidget {
  final File? localFile;
  final String? networkUrl;
  final String fileName;
  final bool isMobile;

  const ExcelViewerWidget({
    super.key,
    this.localFile,
    this.networkUrl,
    required this.fileName,
    required this.isMobile,
  });

  @override
  State<ExcelViewerWidget> createState() => _ExcelViewerWidgetState();
}

class _ExcelViewerWidgetState extends State<ExcelViewerWidget> {
  bool _isLoading = true;
  String? _errorMessage;

  // Workbook data
  Map<String, List<List<String>>> _sheetData = {};
  List<String> _sheetNames = [];
  String? _activeSheetName;

  // Search query
  String _searchQuery = '';

  // Scroll controllers for synchronized scrolling
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSpreadsheet();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadSpreadsheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<int> bytes;
      if (widget.localFile != null) {
        bytes = await widget.localFile!.readAsBytes();
      } else if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
        final token = await const FlutterSecureStorage().read(key: 'jwt_token');
        final dio = Dio();
        final response = await dio.get<List<int>>(
          widget.networkUrl!,
          options: Options(
            responseType: ResponseType.bytes,
            headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          ),
        );
        if (response.data == null) {
          throw Exception('Failed to download spreadsheet file.');
        }
        bytes = response.data!;
      } else {
        throw Exception('No file source provided.');
      }

      final lowerName = widget.fileName.toLowerCase();
      Map<String, List<List<String>>> parsedSheets;
      if (lowerName.endsWith('.csv')) {
        // Run CSV parsing in background isolate
        parsedSheets = await compute(_decodeCsvInBackground, bytes);
      } else {
        // Run Excel parsing in background isolate to avoid Windows UI freeze
        parsedSheets = await compute(_decodeExcelInBackground, bytes);
      }

      if (mounted) {
        setState(() {
          _sheetData = parsedSheets;
          _sheetNames = parsedSheets.keys.toList();
          _activeSheetName = _sheetNames.isNotEmpty ? _sheetNames.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not read spreadsheet: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _columnLetter(int index) {
    String name = '';
    int idx = index;
    while (idx >= 0) {
      name = String.fromCharCode((idx % 26) + 65) + name;
      idx = (idx ~/ 26) - 1;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 12),
            Text(
              'Loading spreadsheet preview...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Preview Error',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<List<String>> activeRows =
        _activeSheetName != null
            ? (_sheetData[_activeSheetName] ?? <List<String>>[])
            : <List<String>>[];
    final List<List<String>> filteredRows =
        _searchQuery.isEmpty
            ? activeRows
            : activeRows.where((row) {
              return row.any(
                (cell) =>
                    cell.toLowerCase().contains(_searchQuery.toLowerCase()),
              );
            }).toList();

    // Determine max columns in this sheet (capped at 50 to prevent horizontal bloat)
    int maxCols = 0;
    for (final r in filteredRows) {
      if (r.length > maxCols) maxCols = r.length;
    }
    if (maxCols == 0) maxCols = 1;
    maxCols = math.min(maxCols, 50);

    const double rowNumberWidth = 50.0;
    const double cellWidth = 120.0;
    final double totalTableWidth = rowNumberWidth + (maxCols * cellWidth);

    return Column(
      children: [
        // Top search and statistics toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 18,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '${filteredRows.length} Rows × $maxCols Columns',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Search field
              SizedBox(
                width: widget.isMobile ? 140 : 220,
                height: 34,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search table...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
            ],
          ),
        ),

        // Main table grid - using Scrollbar and virtualized ListView.builder for instant rendering
        Expanded(
          child: Container(
            color: Colors.white,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalTableWidth,
                  child: Column(
                    children: [
                      // Fixed Column Header Row (A, B, C...)
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Row number corner cell
                            Container(
                              width: rowNumberWidth,
                              alignment: Alignment.center,
                              color: Colors.grey.shade300,
                              child: const Text(
                                '#',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            for (int c = 0; c < maxCols; c++)
                              Container(
                                width: cellWidth,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _columnLetter(c),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Virtualized Data Rows - builds ONLY visible rows instantly
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredRows.length,
                          itemBuilder: (context, r) {
                            final rowCells = filteredRows[r];
                            return Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color:
                                    r % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Left Row Number (1, 2, 3...)
                                  Container(
                                    width: rowNumberWidth,
                                    alignment: Alignment.center,
                                    color: Colors.grey.shade200,
                                    child: Text(
                                      '${r + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  // Cell Values
                                  for (int c = 0; c < maxCols; c++)
                                    Container(
                                      width: cellWidth,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        c < rowCells.length ? rowCells[c] : '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom sheets TabBar (if multiple tabs exist)
        if (_sheetNames.isNotEmpty)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sheetNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final name = _sheetNames[index];
                final isSelected = name == _activeSheetName;
                return Center(
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeSheetName = name);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.green.shade700
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          color:
                              isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
