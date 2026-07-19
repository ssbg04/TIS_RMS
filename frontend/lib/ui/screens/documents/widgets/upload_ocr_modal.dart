import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/inputs/document_source_picker.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../../domain/entities/student_model.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class UploadOcrModal extends ConsumerStatefulWidget {
  /// If provided, the modal will automatically fetch and fill this student's LRN
  final int? prefilledStudentId;

  const UploadOcrModal({super.key, this.prefilledStudentId});

  static void show(BuildContext context, {int? prefilledStudentId}) {
    WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            backgroundColor: AppColors.surfaceWhite,
            hasSabGradient: false,
            hasTopBarLayer: false,
            isTopBarLayerAlwaysVisible: false,
            child: UploadOcrModal(prefilledStudentId: prefilledStudentId),
          ),
        ];
      },
    );
  }

  @override
  ConsumerState<UploadOcrModal> createState() => _UploadOcrModalState();
}

class _UploadOcrModalState extends ConsumerState<UploadOcrModal> {
  int _currentStep = 0; 
  
  File? _selectedFile;
  String? _fileName;
  String? _fileSize;

  final TextEditingController _lrnController = TextEditingController();
  
  String? _selectedDocumentType;
  int? _selectedRequirementId;
  int? _matchedStudentId;

  bool _isSubmitting = false;
  bool _isSearchingStudent = false;
  StudentModel? _matchedStudent;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledStudentId != null) {
      _matchedStudentId = widget.prefilledStudentId;
      _fetchPrefilledStudentLrn();
    }
    _lrnController.addListener(_onLrnChanged);
  }

  @override
  void dispose() {
    _lrnController.removeListener(_onLrnChanged);
    _lrnController.dispose();
    super.dispose();
  }

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
          _selectedRequirementId = null;
          _selectedDocumentType = null;
        });
      }
    }
  }

  Future<void> _fetchPrefilledStudentLrn() async {
    setState(() => _isSearchingStudent = true);
    try {
      final student = await ref.read(studentDetailProvider(widget.prefilledStudentId!).future);
      if (mounted) {
        setState(() {
          _lrnController.text = student.lrn;
          _matchedStudent = student;
          _isSearchingStudent = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingStudent = false);
    }
  }

  Future<void> _searchStudentByLrn(String lrn) async {
    setState(() => _isSearchingStudent = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl, headers: {'Authorization': 'Bearer $token'}));

      final studentsRes = await dio.get('/students', queryParameters: {'search': lrn});
      final studentsList = studentsRes.data['students'] as List;
      
      if (studentsList.isNotEmpty) {
        final studentId = studentsList[0]['id'] as int;
        final student = await ref.read(studentDetailProvider(studentId).future);
        if (mounted && _lrnController.text.trim() == lrn) {
          setState(() {
            _matchedStudent = student;
            _matchedStudentId = studentId;
            _isSearchingStudent = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _matchedStudent = null;
            _matchedStudentId = null;
            _isSearchingStudent = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingStudent = false);
    }
  }

  void _handleFileSelected(File file, String fileName, String fileSize) {
    setState(() {
      _selectedFile = file;
      _fileName = fileName;
      _fileSize = fileSize;
      
      // Skip the OCR scanning entirely and go straight to the form
      _currentStep = 1; 
    });
  }

  Future<void> _validateAndUpload() async {
    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12) {
      showErrorDialog(context, 'Invalid LRN', 'A valid 12-digit LRN is required.');
      return;
    }
    if (_selectedRequirementId == null) {
      showErrorDialog(context, 'Missing Document Type', 'Please select a Document Type before uploading.');
      return;
    }
    if (_selectedFile == null) {
      showErrorDialog(context, 'No File Selected', 'Please select a file to upload.');
      return;
    }

    final ext = _fileName?.split('.').last.toLowerCase() ?? _selectedFile!.path.split('.').last.toLowerCase();
    final requirementsAsync = ref.read(documentRequirementsProvider);
    final reqs = requirementsAsync.value;
    if (reqs != null) {
      final req = reqs.firstWhere((r) => r.id == _selectedRequirementId);
      final allowedExts = req.acceptedFileTypes.split(',').map((e) => e.trim().toLowerCase()).toList();
      
      if (!allowedExts.contains(ext)) {
        showErrorDialog(context, 'Invalid File Type', 'This requirement only accepts: ${req.acceptedFileTypes}. Your file is a $ext.');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl, headers: {'Authorization': 'Bearer $token'}));

      int finalStudentId;

      // 1. Determine Student ID (Use pre-matched if available, otherwise search API by LRN)
      if (_matchedStudentId != null) {
        finalStudentId = _matchedStudentId!;
      } else {
        final studentsRes = await dio.get('/students', queryParameters: {'search': lrn});
        final students = studentsRes.data['students'] as List;
        if (students.isEmpty) {
          setState(() => _isSubmitting = false);
          if (!mounted) return;
          showErrorDialog(context, 'Student Not Found', 'No student found with LRN $lrn. Please check the LRN and try again.');
          return;
        }
        finalStudentId = students[0]['id'];
      }

      // 2. Upload Document
      final ext = _fileName?.split('.').last ?? _selectedFile!.path.split('.').last;
      final newFileName = '${lrn}_$_selectedDocumentType.$ext';

      final formData = FormData.fromMap({
        'studentId': finalStudentId,
        'documentType': _selectedDocumentType,
        'requirementId': _selectedRequirementId,
        'document': await MultipartFile.fromFile(_selectedFile!.path, filename: newFileName),
      });

      await dio.post('/documents/upload', data: formData);

      if (!mounted) return;
      ref.invalidate(documentPageProvider); // Refresh the documents list
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
      
      // Show Success Dialog
      _showSuccessDialog();

    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      showErrorDialog(
        context,
        'Upload Failed',
        e.response?.data?['message'] ?? 'Failed to upload document.',
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      showErrorDialog(
        context,
        'Unexpected Error',
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  // ----------------------------------------------------------------
  // SHOW SUCCESS DIALOG (uses shared dialog)
  // ----------------------------------------------------------------
  void _showSuccessDialog() {
    showSuccessDialog(
      context,
      title: 'Upload Successful!',
      message: '$_fileName has been securely saved to the student\'s records.',
      buttonLabel: 'DONE',
      onDismissed: () => Navigator.of(context).pop(), // Close the upload modal
    );
  }

  // ----------------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------------
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
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_upload_rounded,
                    color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Upload Document',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (Platform.isWindows)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Step indicator
          Row(
            children: [
              _buildStepChip(1, 'Select File', _currentStep >= 0),
              _buildStepConnector(_currentStep >= 1),
              _buildStepChip(2, 'Document Info', _currentStep >= 1),
            ],
          ),
          const Divider(height: 20),

          if (widget.prefilledStudentId == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notice: You are not inside a specific student directory. Please ensure you provide the correct LRN to link this document.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Content (scrollable) ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(int step, String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 28,
        height: 2,
        color: active ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return DocumentSourcePicker(
        allowedExtensions: const ['pdf', 'jpg', 'png', 'jpeg'],
        onFileSelected: _handleFileSelected,
      );
      case 1: return _buildStep1Form();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Form() {
    final requirementsAsync = ref.watch(documentRequirementsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Text(
                    'File: $_fileName ($_fileSize). Please select the document type.',
                    style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p24),

          // LRN FIELD (Auto-filled if opened from a specific student's folder!)
          CustomTextField(
            hintText: 'Student LRN (12 Digits)',
            prefixIcon: Icons.pin_outlined,
            controller: _lrnController,
          ),
          const SizedBox(height: AppSizes.p16),
          
          // DOCUMENT TYPE DROPDOWN (Grouped by JHS / SHS)
          if (_isSearchingStudent)
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 24),
               child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
             )
          else if (_matchedStudent == null)
             Container(
               padding: const EdgeInsets.all(AppSizes.p16),
               decoration: BoxDecoration(
                 color: Colors.grey.shade50,
                 borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                 border: Border.all(color: Colors.grey.shade300),
               ),
               child: const Row(
                 children: [
                   Icon(Icons.search, color: AppColors.textSecondary),
                   SizedBox(width: AppSizes.p12),
                   Expanded(child: Text('Enter a valid 12-digit LRN to load applicable document types.', style: TextStyle(color: AppColors.textSecondary))),
                 ],
               ),
             )
          else
            requirementsAsync.when(
              data: (requirements) {
                bool hasJHS = false;
                bool hasSHS = false;
                
                if (_matchedStudent!.enrollments != null && _matchedStudent!.enrollments!.isNotEmpty) {
                  for (final env in _matchedStudent!.enrollments!) {
                    if (env.gradeLevel <= 10) hasJHS = true;
                    if (env.gradeLevel >= 11) hasSHS = true;
                  }
                } else {
                  // Fallback if no enrollments
                  hasJHS = true;
                  hasSHS = true;
                }

                List<dynamic> jhsReqs = [];
                List<dynamic> shsReqs = [];

                if (hasJHS) {
                  jhsReqs = requirements.where((r) => r.category == 'JHS').toList();
                  jhsReqs.sort((a, b) {
                    if (a.isMandatory && !b.isMandatory) return -1;
                    if (!a.isMandatory && b.isMandatory) return 1;
                    return a.name.compareTo(b.name);
                  });
                }
                
                if (hasSHS) {
                  shsReqs = requirements.where((r) => r.category == 'SHS').toList();
                  shsReqs.sort((a, b) {
                    if (a.isMandatory && !b.isMandatory) return -1;
                    if (!a.isMandatory && b.isMandatory) return 1;
                    return a.name.compareTo(b.name);
                  });
                }

                final entries = <DropdownMenuEntry<int>>[];
                
                if (jhsReqs.isNotEmpty) {
                  entries.add(const DropdownMenuEntry<int>(
                    value: -1,
                    label: 'Junior High School',
                    enabled: false,
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.teal),
                      textStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ));
                  for (final req in jhsReqs) {
                    entries.add(DropdownMenuEntry<int>(
                      value: req.id,
                      label: '${req.name}${req.isMandatory ? " *" : ""}',
                      trailingIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: req.isMandatory ? Colors.red.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: req.isMandatory ? Colors.red.shade200 : Colors.grey.shade300),
                        ),
                        child: Text(
                          req.isMandatory ? 'Mandatory' : 'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: req.isMandatory ? Colors.red.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(EdgeInsets.only(left: 32, right: 16)),
                        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
                      ),
                    ));
                  }
                }

                if (shsReqs.isNotEmpty) {
                  entries.add(const DropdownMenuEntry<int>(
                    value: -2,
                    label: 'Senior High School',
                    enabled: false,
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.purple),
                      textStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ));
                  for (final req in shsReqs) {
                    entries.add(DropdownMenuEntry<int>(
                      value: req.id,
                      label: '${req.name}${req.isMandatory ? " *" : ""}',
                      trailingIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: req.isMandatory ? Colors.red.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: req.isMandatory ? Colors.red.shade200 : Colors.grey.shade300),
                        ),
                        child: Text(
                          req.isMandatory ? 'Mandatory' : 'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: req.isMandatory ? Colors.red.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(EdgeInsets.only(left: 32, right: 16)),
                        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
                      ),
                    ));
                  }
                }

                if (entries.isEmpty) {
                  return const Text('No document types found for this student.', style: TextStyle(color: AppColors.error));
                }

                return DropdownMenu<int>(
                  initialSelection: _selectedRequirementId,
                  hintText: 'Select Document Type',
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: 300,
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                  dropdownMenuEntries: entries,
                  onSelected: (val) {
                    if (val == null || val < 0) return;
                    setState(() {
                      _selectedRequirementId = val;
                      final reqMatch = requirements.firstWhere((r) => r.id == val);
                      _selectedDocumentType = reqMatch.name;
                    });
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
              error: (e, st) => Text('Failed to load types: $e', style: const TextStyle(color: AppColors.error)),
            ),
          
          const SizedBox(height: AppSizes.p32),

          Builder(
            builder: (ctx) {
              final isSmall = MediaQuery.sizeOf(ctx).width < 600;
              return SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: isSmall ? WrapAlignment.center : WrapAlignment.end,
                  spacing: AppSizes.p16,
                  runSpacing: AppSizes.p16,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = 0;
                          _selectedFile = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      child: const Text('RE-UPLOAD', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      width: isSmall ? double.infinity : 200,
                      child: PrimaryButton(
                        label: 'UPLOAD',
                        isLoading: _isSubmitting,
                        onPressed: _validateAndUpload,
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}