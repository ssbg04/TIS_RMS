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

class UploadOcrModal extends ConsumerStatefulWidget {
  /// If provided, the modal will automatically fetch and fill this student's LRN
  final int? prefilledStudentId;

  const UploadOcrModal({super.key, this.prefilledStudentId});

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

  @override
  void initState() {
    super.initState();
    // If we opened this from a specific student's folder, fetch their LRN automatically
    if (widget.prefilledStudentId != null) {
      _matchedStudentId = widget.prefilledStudentId;
      _fetchPrefilledStudentLrn();
    }
  }

  @override
  void dispose() {
    _lrnController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrefilledStudentLrn() async {
    try {
      final student = await ref.read(studentDetailProvider(widget.prefilledStudentId!).future);
      if (mounted) {
        setState(() {
          _lrnController.text = student.lrn; // Auto-fill the LRN
        });
      }
    } catch (e) {
      // Fails silently, the user can still type it manually if needed
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

    // Compute adaptive constraints
    final double maxW = isSmall ? screenSize.width * 0.98 : 600;
    final double maxH = isSmall
        ? screenSize.height * 0.92
        : screenSize.height * 0.85;

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 24,
        vertical: isSmall ? 16 : 40,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isSmall ? AppSizes.radiusMedium : AppSizes.radiusLarge,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: maxH,
        ),
        child: Padding(
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

              // ── Content (scrollable) ──
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ],
          ),
        ),
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
              color: Colors.blue.withOpacity(0.1),
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
          requirementsAsync.when(
            data: (requirements) {
              final jhsReqs = requirements.where((r) => r.category == 'JHS').toList();
              final shsReqs = requirements.where((r) => r.category == 'SHS').toList();

              List<DropdownMenuItem<int>> items = [];
              int _headerIndex = -1;

              void addGroup(String groupLabel, Color groupColor, List<dynamic> reqs) {
                if (reqs.isEmpty) return;
                // Section header (non-selectable)
                items.add(DropdownMenuItem<int>(
                  value: _headerIndex--, // Guaranteed unique negative value
                  enabled: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: groupColor.withOpacity(0.3))),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(groupLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: groupColor)),
                      ),
                      const SizedBox(width: 6),
                      Text('Requirements', style: TextStyle(fontSize: 11, color: groupColor)),
                    ]),
                  ),
                ));
                // Actual requirement items
                for (final req in reqs) {
                  items.add(DropdownMenuItem<int>(
                    value: req.id,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(req.name, style: const TextStyle(fontSize: 13)),
                    ),
                  ));
                }
              }

              addGroup('JHS', Colors.teal, jhsReqs);
              addGroup('SHS', Colors.purple, shsReqs);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedRequirementId,
                    hint: const Text('Select Document Type'),
                    isExpanded: true,
                    items: items,
                    onChanged: (val) {
                      if (val == null || val < 0) return; // ignore headers
                      setState(() {
                        _selectedRequirementId = val;
                        final reqMatch = requirements.firstWhere((r) => r.id == val);
                        _selectedDocumentType = reqMatch.name;
                      });
                    },
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
            error: (e, st) => Text('Failed to load types: $e', style: const TextStyle(color: AppColors.error)),
          ),
          
          const SizedBox(height: AppSizes.p32),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _selectedFile = null;
                  });
                },
                child: const Text('RE-UPLOAD', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: AppSizes.p16),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: 'UPLOAD DOCUMENT',
                  isLoading: _isSubmitting,
                  onPressed: _validateAndUpload,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}