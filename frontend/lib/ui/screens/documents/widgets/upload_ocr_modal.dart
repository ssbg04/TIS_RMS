import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../providers/document_provider.dart';

class UploadOcrModal extends ConsumerStatefulWidget {
  const UploadOcrModal({super.key});

  @override
  ConsumerState<UploadOcrModal> createState() => _UploadOcrModalState();
}

class _UploadOcrModalState extends ConsumerState<UploadOcrModal> {
  int _currentStep = 0; 
  
  File? _selectedFile;
  String? _fileName;
  String? _fileSize;

  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  String? _selectedDocumentType;
  int? _selectedRequirementId;
  int? _matchedStudentId;

  bool _isSubmitting = false;
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _lrnController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
      
      setState(() {
        _selectedFile = file;
        _fileName = result.files.single.name;
        _fileSize = '$size MB';
        _currentStep = 1; 
      });

      _processOCR();
    }
  }

  void _processOCR() async {
    // Simulate OCR delay
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _currentStep = 2; 
    });
  }

  Future<void> _validateAndUpload() async {
    setState(() {
      _errorMessage = null;
    });

    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12) {
      setState(() => _errorMessage = 'Valid 12-digit LRN is required.');
      return;
    }
    if (_selectedDocumentType == null) {
      setState(() => _errorMessage = 'Please select a Document Type.');
      return;
    }
    if (_selectedFile == null) {
      setState(() => _errorMessage = 'No file selected.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl, headers: {'Authorization': 'Bearer $token'}));

      // 1. Validate LRN and get Student ID
      final studentsRes = await dio.get('/students', queryParameters: {'search': lrn});
      final students = studentsRes.data['students'] as List;
      if (students.isEmpty) {
        setState(() {
          _errorMessage = 'Student with LRN $lrn not found.';
          _isSubmitting = false;
        });
        return;
      }
      final studentId = students[0]['id'];

      // 2. Upload Document
      final formData = FormData.fromMap({
        'studentId': studentId,
        'documentType': _selectedDocumentType,
        'requirementId': _selectedRequirementId,
        'remarks': _remarksController.text.trim(),
        'document': await MultipartFile.fromFile(_selectedFile!.path, filename: _fileName),
      });

      await dio.post('/documents/upload', data: formData);

      if (!mounted) return;
      ref.invalidate(documentPageProvider); // Refresh list
      Navigator.of(context).pop(); 
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response?.data?['message'] ?? 'Failed to upload document.';
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, minHeight: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload & Scan Document',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 32),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSizes.p12),
                  margin: const EdgeInsets.only(bottom: AppSizes.p16),
                  color: AppColors.error.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: AppSizes.p8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),

              Expanded(
                flex: _currentStep == 2 ? 1 : 0, 
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

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0Upload();
      case 1: return _buildStep1Processing();
      case 2: return _buildStep2Review();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep0Upload() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      child: Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.05),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: AppSizes.p16),
            const Text(
              'Click to browse or drag file here',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'Supports PDF, JPG, PNG (Max 10MB)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.p24),
            ElevatedButton(
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Select Document'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Processing() {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: AppSizes.p24),
          const Text(
            'Running OCR Engine...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSizes.p8),
          Text(
            'Analyzing $_fileName',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Review() {
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
                    'File: $_fileName ($_fileSize). Please select the document type and enter the student LRN.',
                    style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p24),

          CustomTextField(
            hintText: 'Student LRN (12 Digits)',
            prefixIcon: Icons.pin_outlined,
            controller: _lrnController,
          ),
          const SizedBox(height: AppSizes.p16),
          
          requirementsAsync.when(
            data: (requirements) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDocumentType,
                    hint: const Text('Select Document Type'),
                    isExpanded: true,
                    items: requirements.map((req) {
                      return DropdownMenuItem<String>(
                        value: req.name,
                        child: Text('${req.name} (${req.category})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDocumentType = val;
                        final reqMatch = requirements.firstWhere((r) => r.name == val);
                        _selectedRequirementId = reqMatch.id;
                      });
                    },
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Failed to load types: $e', style: const TextStyle(color: AppColors.error)),
          ),

          const SizedBox(height: AppSizes.p16),
          CustomTextField(
            hintText: 'Remarks (Optional)',
            prefixIcon: Icons.comment_outlined,
            controller: _remarksController,
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