import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/haptic_service.dart';

class ReportIssueModal extends StatefulWidget {
  const ReportIssueModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const ReportIssueModal(),
    );
  }

  @override
  State<ReportIssueModal> createState() => _ReportIssueModalState();
}

class _ReportIssueModalState extends State<ReportIssueModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  String _category = 'bug'; // 'bug', 'feature', 'question'
  String _urgency = 'medium'; // 'low', 'medium', 'high'
  final List<PlatformFile> _attachments = [];
  bool _isSending = false;
  String? _errorMessage;

  static const int _maxFiles = 5;
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    HapticService.light();
    if (_attachments.length >= _maxFiles) {
      setState(() {
        _errorMessage = 'Maximum of $_maxFiles attachments allowed.';
      });
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'log', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        String? sizeWarning;
        setState(() {
          _errorMessage = null;
          for (final f in result.files) {
            if (_attachments.length >= _maxFiles) break;
            if (f.size > _maxFileSizeBytes) {
              sizeWarning = '${f.name} exceeds 10 MB limit and was skipped.';
              continue;
            }
            if (!_attachments.any((a) => a.path == f.path && a.name == f.name)) {
              _attachments.add(f);
            }
          }
          if (sizeWarning != null) {
            _errorMessage = sizeWarning;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to pick attachments: $e';
        });
      }
    }
  }

  void _removeAttachment(int index) {
    HapticService.light();
    setState(() {
      _attachments.removeAt(index);
      _errorMessage = null;
    });
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    if (!_formKey.currentState!.validate()) return;
    HapticService.medium();
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiConstants.createDio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final token = await _storage.read(key: 'jwt_token');
      String appVersion = 'Unknown';
      try {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = 'v${pkg.version} (Build ${pkg.buildNumber})';
      } catch (_) {}

      final attachmentFiles = <MultipartFile>[];
      for (final file in _attachments) {
        if (file.bytes != null) {
          attachmentFiles.add(
            MultipartFile.fromBytes(file.bytes!, filename: file.name),
          );
        } else if (file.path != null && file.path!.isNotEmpty) {
          attachmentFiles.add(
            await MultipartFile.fromFile(file.path!, filename: file.name),
          );
        }
      }

      final formData = FormData.fromMap({
        'category': _category,
        'urgency': _urgency,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'platform': ApiConstants.clientPlatform,
        'deviceName': ApiConstants.clientDeviceName,
        'appVersion': appVersion,
        if (attachmentFiles.isNotEmpty) 'attachments': attachmentFiles,
      });

      final response = await dio.post(
        '/settings/report-issue',
        data: formData,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      final success = data is Map ? (data['success'] == true) : response.statusCode == 200;

      if (!success) {
        final msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to send issue report.';
        throw Exception(msg);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Issue report sent to developer!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: Duration(seconds: 4),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final respData = e.response?.data;
      final msg = (respData is Map && respData['message'] != null)
          ? respData['message'].toString()
          : (e.message ?? 'Network error while sending report.');
      setState(() {
        _isSending = false;
        _errorMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isSending) Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
          ),
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 24,
            vertical: isMobile ? 20 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: isMobile ? 640 : 660,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Minimalist Header ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bug_report_outlined,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report an Issue / Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sent directly to developer support',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isSending)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey.shade500,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),

                // ── Form Body ───────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.error,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          _sectionLabel('Category', isDark),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPillChip(
                                label: 'Bug Report',
                                icon: Icons.bug_report_outlined,
                                selected: _category == 'bug',
                                activeColor: AppColors.error,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _category = 'bug'),
                              ),
                              _buildPillChip(
                                label: 'Feature',
                                icon: Icons.auto_awesome_outlined,
                                selected: _category == 'feature',
                                activeColor: AppColors.primaryGreen,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _category = 'feature'),
                              ),
                              _buildPillChip(
                                label: 'Support',
                                icon: Icons.help_outline_rounded,
                                selected: _category == 'question',
                                activeColor: Colors.blueAccent,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _category = 'question'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _sectionLabel('Urgency Level', isDark),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPillChip(
                                label: 'Low',
                                icon: Icons.low_priority_rounded,
                                selected: _urgency == 'low',
                                activeColor: Colors.teal,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _urgency = 'low'),
                              ),
                              _buildPillChip(
                                label: 'Medium',
                                icon: Icons.drag_handle_rounded,
                                selected: _urgency == 'medium',
                                activeColor: Colors.orange,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _urgency = 'medium'),
                              ),
                              _buildPillChip(
                                label: 'High',
                                icon: Icons.priority_high_rounded,
                                selected: _urgency == 'high',
                                activeColor: AppColors.error,
                                isDark: isDark,
                                onTap: _isSending
                                    ? null
                                    : () => setState(() => _urgency = 'high'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _titleController,
                            enabled: !_isSending,
                            decoration: InputDecoration(
                              labelText: 'Subject *',
                              hintText: 'Brief summary of the issue or feedback',
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter a subject';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _descriptionController,
                            enabled: !_isSending,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              hintText: 'Describe what happened or steps to reproduce...',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please describe the issue or feedback';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Attachments row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _sectionLabel(
                                'Attachments (${_attachments.length}/$_maxFiles)',
                                isDark,
                              ),
                              TextButton.icon(
                                onPressed: _isSending ? null : _pickAttachments,
                                icon: const Icon(Icons.attach_file_rounded, size: 16),
                                label: const Text('Add Files', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          if (_attachments.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: List.generate(_attachments.length, (index) {
                                final item = _attachments[index];
                                final kb = (item.size / 1024).toStringAsFixed(0);
                                return Chip(
                                  avatar: const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 15,
                                    color: AppColors.primaryGreen,
                                  ),
                                  label: Text(
                                    '${item.name} ($kb KB)',
                                    style: const TextStyle(fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                                  onDeleted: _isSending ? null : () => _removeAttachment(index),
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF1F5F9),
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Footer Actions ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: OutlinedButton(
                          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _handleSend,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            _isSending ? 'Sending...' : 'Send Report',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildPillChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: isDark ? 0.24 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? activeColor
                  : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? activeColor
                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
