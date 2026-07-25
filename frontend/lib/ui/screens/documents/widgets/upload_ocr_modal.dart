import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../../domain/entities/student_model.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'upload_modal_header.dart';

// ────────────────────────────────────────────────────────────
// Upload status enum
// ────────────────────────────────────────────────────────────
enum UploadStatus { pending, uploading, done, error }

// ────────────────────────────────────────────────────────────
// Per-file upload entry model
// ────────────────────────────────────────────────────────────
class _UploadEntry {
  final File file;
  final String fileName;
  final String fileSize;
  int? selectedRequirementId;
  String? selectedDocumentType;
  double progress; // 0.0 – 1.0
  UploadStatus status;
  String? errorMessage;

  _UploadEntry({
    required this.file,
    required this.fileName,
    required this.fileSize,
    this.selectedRequirementId,
    this.selectedDocumentType,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
  });
}

// ────────────────────────────────────────────────────────────
// Widget
// ────────────────────────────────────────────────────────────
class UploadOcrModal extends ConsumerStatefulWidget {
  /// If provided, the modal will automatically fetch and fill this student's LRN
  final int? prefilledStudentId;

  /// Files pre-populated from drag-and-drop (Windows)
  final List<File>? preloadedFiles;

  final ValueNotifier<int>? stepNotifier;

  const UploadOcrModal({super.key, this.prefilledStudentId, this.preloadedFiles, this.stepNotifier});

  static void show(
    BuildContext context, {
    int? prefilledStudentId,
    List<File>? preloadedFiles,
  }) {
    final stepNotifier = ValueNotifier<int>(0);
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: false,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            backgroundColor: AppColors.surfaceWhite,
            hasSabGradient: false,
            hasTopBarLayer: true,
            isTopBarLayerAlwaysVisible: true,
            topBarTitle: ValueListenableBuilder<int>(
              valueListenable: stepNotifier,
              builder: (ctx, step, _) => UploadModalHeaderWidget(step: step),
            ),
            child: UploadOcrModal(
              prefilledStudentId: prefilledStudentId,
              preloadedFiles: preloadedFiles,
              stepNotifier: stepNotifier,
            ),
          ),
        ];
      },
    );
  }

  @override
  ConsumerState<UploadOcrModal> createState() => _UploadOcrModalState();
}

class _UploadOcrModalState extends ConsumerState<UploadOcrModal> {
  // Step: 0 = pick files, 1 = review & upload
  int _currentStep = 0;

  final TextEditingController _lrnController = TextEditingController();
  StudentModel? _matchedStudent;
  int? _matchedStudentId;
  bool _isSearchingStudent = false;

  List<_UploadEntry> _entries = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(documentRequirementsProvider);
      ref.read(documentRequirementsProvider.future);
    });
    if (widget.prefilledStudentId != null) {
      _matchedStudentId = widget.prefilledStudentId;
      _fetchPrefilledStudentLrn();
    }
    // Pre-populate entries from drag-and-drop files
    if (widget.preloadedFiles != null && widget.preloadedFiles!.isNotEmpty) {
      _entries = widget.preloadedFiles!.map((f) {
        final bytes = f.lengthSync();
        final kb = bytes / 1024;
        final size = kb >= 1024
            ? '${(kb / 1024).toStringAsFixed(1)} MB'
            : '${kb.toStringAsFixed(0)} KB';
        return _UploadEntry(
          file: f,
          fileName: f.path.split(Platform.pathSeparator).last,
          fileSize: size,
        );
      }).toList();
      _currentStep = 1;
      widget.stepNotifier?.value = _currentStep; // Jump to review step
    }
    _lrnController.addListener(_onLrnChanged);
  }

  @override
  void dispose() {
    _lrnController.removeListener(_onLrnChanged);
    _lrnController.dispose();
    super.dispose();
  }

  // ── Student search ──────────────────────────────────────────
  void _onLrnChanged() {
    final text = _lrnController.text.trim();
    if (text.length == 12) {
      if (_matchedStudent == null || _matchedStudent!.lrn != text) {
        _searchStudentByLrn(text);
      }
    } else {
      if (_matchedStudent != null) {
        setState(() {
          _matchedStudent = null;
          _matchedStudentId = null;
        });
      }
    }
  }

  Future<void> _fetchPrefilledStudentLrn() async {
    setState(() => _isSearchingStudent = true);
    try {
      final student = await ref.read(
        studentDetailProvider(widget.prefilledStudentId!).future,
      );
      if (mounted) {
        setState(() {
          _lrnController.text = student.lrn;
          _matchedStudent = student;
          _isSearchingStudent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingStudent = false);
    }
  }

  Future<void> _searchStudentByLrn(String lrn) async {
    setState(() => _isSearchingStudent = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));

      final res = await dio.get('/students', queryParameters: {'search': lrn});
      final list = res.data['students'] as List;

      if (list.isNotEmpty && mounted && _lrnController.text.trim() == lrn) {
        final sid = list[0]['id'] as int;
        final student = await ref.read(studentDetailProvider(sid).future);
        if (mounted && _lrnController.text.trim() == lrn) {
          setState(() {
            _matchedStudent = student;
            _matchedStudentId = sid;
            _isSearchingStudent = false;
            // Re-run auto-detect whenever student changes
            _autoDetectAll();
          });
        }
      } else if (mounted) {
        setState(() {
          _matchedStudent = null;
          _matchedStudentId = null;
          _isSearchingStudent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingStudent = false);
    }
  }

  // ── File picking ─────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    final requirements = ref.read(documentRequirementsProvider).value ?? [];

    final newEntries = result.files
        .where((f) => f.path != null)
        .map((f) {
          final file = File(f.path!);
          final sizeKb = (f.size / 1024).toStringAsFixed(1);
          final sizeLabel = f.size > 1048576
              ? '${(f.size / 1048576).toStringAsFixed(1)} MB'
              : '$sizeKb KB';
          final entry = _UploadEntry(
            file: file,
            fileName: f.name,
            fileSize: sizeLabel,
          );
          _applyAutoDetect(entry, requirements);
          return entry;
        })
        .toList();

    setState(() {
      _entries.addAll(newEntries);
      if (_entries.isNotEmpty) {
        _currentStep = 1;
        widget.stepNotifier?.value = _currentStep;
      }
    });
  }

  Future<void> _scanDocument() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.pdf},
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 20,
        ),
      );

      final result = await scanner.scanDocument();
      scanner.close();

      if (result != null && result.pdf != null) {
        final file = File(result.pdf!.uri);
        final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
        final sizeLabel = file.lengthSync() > 1048576
            ? '${(file.lengthSync() / 1048576).toStringAsFixed(1)} MB'
            : '$sizeKb KB';
        final name = 'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf';

        final requirements = ref.read(documentRequirementsProvider).value ?? [];
        final entry = _UploadEntry(
          file: file,
          fileName: name,
          fileSize: sizeLabel,
        );
        _applyAutoDetect(entry, requirements);

        setState(() {
          _entries.add(entry);
          if (_entries.isNotEmpty) {
            _currentStep = 1;
            widget.stepNotifier?.value = _currentStep;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Scanner Error', 'Failed to scan document: $e');
      }
    }
  }

  // ── Auto-detect document type from filename ──────────────────
  void _autoDetectAll() {
    final requirements = ref.read(documentRequirementsProvider).value ?? [];
    for (final e in _entries) {
      if (e.status == UploadStatus.pending) {
        _applyAutoDetect(e, requirements);
      }
    }
  }

  void _applyAutoDetect(_UploadEntry entry, List<dynamic> requirements) {
    final fileNameLower = entry.fileName.toLowerCase();
    final cleanFileName = fileNameLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    // Extract alphanumeric words from filename
    final fileWords = RegExp(r'[a-zA-Z0-9]+')
        .allMatches(fileNameLower)
        .map((m) => m.group(0)!)
        .toSet();

    dynamic best;
    int bestScore = 0;

    for (final req in requirements) {
      final reqNameLower = (req.name as String).toLowerCase();
      final cleanReqName = reqNameLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

      int matches = 0;
      
      // If the clean filename contains the clean requirement name, it's a very strong match
      if (cleanReqName.isNotEmpty && cleanFileName.contains(cleanReqName)) {
        matches += 100;
      }
      
      // Special logic for SF forms
      if (reqNameLower.contains('sf9') && cleanFileName.contains('sf9')) {
         matches += 50;
      }
      if (reqNameLower.contains('sf10') && cleanFileName.contains('sf10')) {
         matches += 50;
      }

      final reqWords = RegExp(r'[a-zA-Z0-9]+')
          .allMatches(reqNameLower)
          .map((m) => m.group(0)!)
          .toList();

      for (final rw in reqWords) {
        if (rw.length < 2) continue; // Ignore single characters
        
        if (fileWords.contains(rw)) {
          matches += 2; // Exact word match is stronger
        } else if (rw.length >= 3 && fileNameLower.contains(rw)) {
          matches += 1; // Substring match is weaker but helpful for concat strings like "108297100170SF9"
        }
      }

      if (matches > bestScore) {
        bestScore = matches;
        best = req;
      }
    }

    if (best != null && bestScore > 0) {
      entry.selectedRequirementId = best.id as int;
      entry.selectedDocumentType = best.name as String;
    }
  }

  // ── Sequential upload ─────────────────────────────────────────
  Future<void> _startUpload() async {
    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12) {
      showErrorDialog(context, 'Invalid LRN', 'A valid 12-digit LRN is required.');
      return;
    }

    final pending = _entries.where((e) => e.status == UploadStatus.pending).toList();
    if (pending.isEmpty) return;

    final unassigned = pending.where((e) => e.selectedRequirementId == null).toList();
    if (unassigned.isNotEmpty) {
      showErrorDialog(
        context,
        'Missing Document Type',
        '${unassigned.length} file(s) have no document type selected.\nPlease assign a type to each file.',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));

      // Resolve student ID
      int finalStudentId;
      if (_matchedStudentId != null) {
        finalStudentId = _matchedStudentId!;
      } else {
        final res = await dio.get('/students', queryParameters: {'search': lrn});
        final students = res.data['students'] as List;
        if (students.isEmpty) {
          setState(() => _isUploading = false);
          if (!mounted) return;
          showErrorDialog(context, 'Student Not Found',
              'No student found with LRN $lrn. Please check and try again.');
          return;
        }
        finalStudentId = students[0]['id'] as int;
      }

      // Upload sequentially
      for (final entry in pending) {
        if (!mounted) break;

        setState(() => entry.status = UploadStatus.uploading);

        try {
          final ext = entry.fileName.split('.').last;
          final newFileName = '${entry.selectedDocumentType}.$ext';

          final formData = FormData.fromMap({
            'studentId': finalStudentId,
            'documentType': entry.selectedDocumentType,
            'requirementId': entry.selectedRequirementId,
            'document': await MultipartFile.fromFile(
              entry.file.path,
              filename: newFileName,
            ),
          });

          await dio.post(
            '/documents/upload',
            data: formData,
            onSendProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => entry.progress = sent / total);
              }
            },
          );

          if (mounted) setState(() => entry.status = UploadStatus.done);
        } on DioException catch (e) {
          if (mounted) {
            setState(() {
              entry.status = UploadStatus.error;
              entry.errorMessage =
                  e.response?.data?['message'] ?? 'Upload failed';
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              entry.status = UploadStatus.error;
              entry.errorMessage = 'Unexpected error';
            });
          }
        }
      }

      if (mounted) {
        ref.invalidate(documentPageProvider);
        ref.invalidate(foldersProvider);
        ref.invalidate(studentFoldersProvider);

        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  bool get _allDone =>
      _entries.isNotEmpty &&
      _entries.every((e) => e.status == UploadStatus.done);

  bool get _hasError =>
      _entries.any((e) => e.status == UploadStatus.error);

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmall = screenSize.width < 600 || screenSize.height < 600;

    return Padding(
      padding: EdgeInsets.all(isSmall ? AppSizes.p16 : AppSizes.p24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No-student notice
          if (widget.prefilledStudentId == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are not inside a student folder. Make sure you provide the correct LRN.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Content ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentStep == 0 ? _buildStep0() : _buildStep1(),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Pick files ────────────────────────────────────────
  Widget _buildStep0() {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    return Container(
      key: const ValueKey('step0'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.upload_file_rounded,
              size: 56,
              color: AppColors.primaryGreen.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          const Text(
            'Select Document Source',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Supports PDF, JPG, JPEG, PNG\nYou can select multiple files at once',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSizes.p12,
            runSpacing: AppSizes.p12,
            children: [
              if (isMobile)
                ElevatedButton.icon(
                  onPressed: _scanDocument,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMobile ? Colors.white : AppColors.primaryGreen,
                  foregroundColor: isMobile ? AppColors.primaryGreen : Colors.white,
                  side: isMobile ? const BorderSide(color: AppColors.primaryGreen) : BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Review & Upload ───────────────────────────────────
  Widget _buildStep1() {
    final requirementsAsync = ref.watch(documentRequirementsProvider);

    return SingleChildScrollView(
      key: const ValueKey('step1'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LRN field
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  hintText: 'Student LRN (12 Digits)',
                  prefixIcon: Icons.pin_outlined,
                  controller: _lrnController,
                ),
              ),
              if (_isSearchingStudent)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryGreen),
                  ),
                ),
              if (_matchedStudent != null && !_isSearchingStudent)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.check_circle,
                      color: AppColors.primaryGreen, size: 22),
                ),
            ],
          ),
          if (_matchedStudent != null) ...[
            const SizedBox(height: 6),
            Text(
              '✓ ${_matchedStudent!.fullName}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),

          // File list
          requirementsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen)),
            error: (e, _) => Text('Failed to load types: $e',
                style: const TextStyle(color: AppColors.error)),
            data: (requirements) {
              return Column(
                children: [
                  ..._entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return _buildFileCard(idx, item, requirements);
                  }),
                  const SizedBox(height: 12),
                  // Add more files
                  if (!_isUploading && !_allDone)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (Platform.isAndroid || Platform.isIOS)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.document_scanner_outlined, size: 18),
                            label: const Text('Scan More'),
                            onPressed: _scanDocument,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Add Files'),
                          onPressed: _pickFiles,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Summary / action row
          if (_allDone)
            _buildDoneBanner()
          else
            _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildFileCard(int idx, _UploadEntry item, List<dynamic> requirements) {
    final isDone = item.status == UploadStatus.done;
    final isError = item.status == UploadStatus.error;
    final isUploading = item.status == UploadStatus.uploading;

    Color borderColor = Colors.grey.shade200;
    if (isDone) borderColor = Colors.green.shade300;
    if (isError) borderColor = Colors.red.shade300;
    if (isUploading) borderColor = AppColors.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withValues(alpha: 0.04)
            : isError
                ? Colors.red.withValues(alpha: 0.04)
                : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // File icon
              Icon(
                _fileIcon(item.fileName),
                color: isDone
                    ? Colors.green
                    : isError
                        ? Colors.red
                        : AppColors.primaryGreen,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.fileSize,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (item.selectedRequirementId != null &&
                            !isDone &&
                            !isError) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Icon(Icons.check_circle_outline,
                              size: 12, color: AppColors.primaryGreen),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'Auto-detected',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.primaryGreen),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (item.selectedRequirementId == null) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Icon(Icons.warning_amber_rounded,
                              size: 12, color: Colors.orange),
                          const SizedBox(width: 3),
                          const Text(
                            'Not detected — select manually',
                            style:
                                TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status icon / remove button
              if (isDone)
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 22)
              else if (isError)
                const Icon(Icons.error_outline, color: Colors.red, size: 22)
              else if (!_isUploading)
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 20),
                  onPressed: () => setState(() => _entries.removeAt(idx)),
                  tooltip: 'Remove',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
            ],
          ),

          // Progress bar (uploading)
          if (isUploading || isDone) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.status == UploadStatus.done ? 1.0 : item.progress,
                backgroundColor: Colors.grey.shade200,
                color: isDone ? Colors.green : AppColors.primaryGreen,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDone
                  ? 'Upload complete'
                  : '${(item.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: isDone ? Colors.green : AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Error message
          if (isError && item.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.errorMessage!,
              style:
                  const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],

          // Document type dropdown (pending state only)
          if (!isDone && !isError && !isUploading) ...[
            const SizedBox(height: 10),
            _buildRequirementDropdown(idx, item, requirements),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementDropdown(
      int idx, _UploadEntry item, List<dynamic> requirements) {
    // Filter requirements based on student grade
    List<dynamic> applicable = requirements;
    if (_matchedStudent != null) {
      bool hasJHS = false, hasSHS = false;
      if (_matchedStudent!.enrollments != null &&
          _matchedStudent!.enrollments!.isNotEmpty) {
        for (final e in _matchedStudent!.enrollments!) {
          if (e.gradeLevel <= 10) hasJHS = true;
          if (e.gradeLevel >= 11) hasSHS = true;
        }
      } else {
        hasJHS = hasSHS = true;
      }
      applicable = requirements.where((r) {
        if (!hasJHS && r.category == 'JHS') return false;
        if (!hasSHS && r.category == 'SHS') return false;
        return true;
      }).toList();
    }

    final entries = <DropdownMenuEntry<int>>[];
    final jhs = applicable.where((r) => r.category == 'JHS').toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final shs = applicable.where((r) => r.category == 'SHS').toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (jhs.isNotEmpty) {
      entries.add(const DropdownMenuEntry<int>(
        value: -1,
        label: 'Junior High School',
        enabled: false,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(Colors.teal),
          textStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ));
      for (final r in jhs) {
        entries.add(DropdownMenuEntry<int>(
          value: r.id as int,
          label: '${r.name}${r.isMandatory ? " *" : ""}',
        ));
      }
    }
    if (shs.isNotEmpty) {
      entries.add(const DropdownMenuEntry<int>(
        value: -2,
        label: 'Senior High School',
        enabled: false,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(Colors.purple),
          textStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ));
      for (final r in shs) {
        entries.add(DropdownMenuEntry<int>(
          value: r.id as int,
          label: '${r.name}${r.isMandatory ? " *" : ""}',
        ));
      }
    }

    return DropdownMenu<int>(
      key: ValueKey('dd_${idx}_${item.selectedRequirementId}'),
      initialSelection: item.selectedRequirementId,
      hintText: 'Select Document Type',
      expandedInsets: EdgeInsets.zero,
      menuHeight: 280,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      dropdownMenuEntries: entries,
      onSelected: (val) {
        if (val == null || val < 0) return;
        final req = requirements.firstWhere((r) => r.id == val);
        setState(() {
          item.selectedRequirementId = val;
          item.selectedDocumentType = req.name as String;
        });
      },
    );
  }

  Widget _buildActionRow() {
    final doneCnt = _entries.where((e) => e.status == UploadStatus.done).length;
    final totalCnt = _entries.length;
    final pendingCnt =
        _entries.where((e) => e.status == UploadStatus.pending).length;

    return Builder(builder: (ctx) {
      final isSmall = MediaQuery.sizeOf(ctx).width < 600;
      return Column(
        children: [
          if (doneCnt > 0 && totalCnt > doneCnt)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$doneCnt / $totalCnt uploaded',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: isSmall ? WrapAlignment.center : WrapAlignment.end,
              spacing: AppSizes.p16,
              runSpacing: AppSizes.p16,
              children: [
                TextButton(
                  onPressed: _isUploading
                      ? null
                      : () => setState(() {
                            _entries = [];
                            _currentStep = 0;
                            widget.stepNotifier?.value = _currentStep;
                          }),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24)),
                  child: const Text('START OVER',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: isSmall ? double.infinity : 200,
                  child: PrimaryButton(
                    label: pendingCnt > 1
                        ? 'UPLOAD $pendingCnt FILES'
                        : 'UPLOAD',
                    isLoading: _isUploading,
                    onPressed:
                        _entries.isEmpty || _isUploading ? null : () => _startUpload(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDoneBanner() {
    final errorCnt = _entries.where((e) => e.status == UploadStatus.error).length;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: errorCnt > 0
                ? Colors.orange.withValues(alpha: 0.08)
                : Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(
              color: errorCnt > 0
                  ? Colors.orange.shade300
                  : Colors.green.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                errorCnt > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: errorCnt > 0 ? Colors.orange : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorCnt > 0
                      ? '${_entries.length - errorCnt} uploaded, $errorCnt failed.'
                      : 'All ${_entries.length} file(s) uploaded successfully!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: errorCnt > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  IconData _fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

}
