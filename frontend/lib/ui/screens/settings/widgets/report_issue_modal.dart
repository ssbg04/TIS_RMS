import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../shared/modals/custom_modal.dart';

class ReportIssueModal extends StatefulWidget {
  const ReportIssueModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
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

  String _category = 'bug'; // 'bug', 'feature', 'question'
  String _urgency = 'medium'; // 'high', 'medium', 'low'
  final List<PlatformFile> _attachments = [];
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    HapticService.light();
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'log', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            if (!_attachments.any((a) => a.path == f.path && a.name == f.name)) {
              _attachments.add(f);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick attachments: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    HapticService.light();
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    HapticService.medium();
    setState(() => _isSending = true);

    const leadEmail = 'crischarlesgarcia345@gmail.com';
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    final categoryLabel = _category.toUpperCase();
    final urgencyLabel = _urgency.toUpperCase();
    final subject = '[TIS RMS] [$categoryLabel] [$urgencyLabel] $title';

    final attachmentNames = _attachments.map((a) => '- ${a.name} (${(a.size / 1024).toStringAsFixed(1)} KB)').join('\n');
    final attachmentNotice = _attachments.isNotEmpty
        ? '\n\nAttachments to include manually if not auto-attached:\n$attachmentNames\n'
        : '';

    final body = '''Category: $categoryLabel
Urgency: $urgencyLabel
Title: $title

Description:
$description
$attachmentNotice
---
System Info:
Platform: ${ApiConstants.clientPlatform} (${ApiConstants.clientDeviceName})
Reported At: ${DateTime.now().toLocal().toString()}
Lead Developer: $leadEmail
''';

    final mailtoUri = Uri(
      scheme: 'mailto',
      path: leadEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    bool launched = false;
    try {
      launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(mailtoUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.of(context).pop();

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Email client opened! Ready to send to $leadEmail.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: 'To: $leadEmail\nSubject: $subject\n\n$body'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not launch email client directly. Issue report copied to clipboard! Send to: $leadEmail',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return CustomModal(
      title: 'Report an Issue / Feedback',
      icon: Icons.bug_report_rounded,
      maxWidth: 580,
      content: SingleChildScrollView(
        padding: EdgeInsets.all(isNarrow ? 16 : AppSizes.p24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Direct to Lead Developer (crischarlesgarcia345@gmail.com). Clicking Send prepares an email ready in your mail client.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Text(
                'CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'Bug Report',
                    icon: Icons.bug_report_outlined,
                    value: 'bug',
                    selected: _category == 'bug',
                    selectedColor: AppColors.error,
                    onSelected: (val) => setState(() => _category = 'bug'),
                  ),
                  _buildChoiceChip(
                    label: 'Feature Request',
                    icon: Icons.auto_awesome_outlined,
                    value: 'feature',
                    selected: _category == 'feature',
                    selectedColor: AppColors.primaryGreen,
                    onSelected: (val) => setState(() => _category = 'feature'),
                  ),
                  _buildChoiceChip(
                    label: 'Question / Support',
                    icon: Icons.help_outline_rounded,
                    value: 'question',
                    selected: _category == 'question',
                    selectedColor: Colors.blueAccent,
                    onSelected: (val) => setState(() => _category = 'question'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Urgency Selector
              Text(
                'URGENCY LEVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'Low',
                    icon: Icons.low_priority_rounded,
                    value: 'low',
                    selected: _urgency == 'low',
                    selectedColor: Colors.teal,
                    onSelected: (val) => setState(() => _urgency = 'low'),
                  ),
                  _buildChoiceChip(
                    label: 'Medium',
                    icon: Icons.drag_handle_rounded,
                    value: 'medium',
                    selected: _urgency == 'medium',
                    selectedColor: Colors.orange,
                    onSelected: (val) => setState(() => _urgency = 'medium'),
                  ),
                  _buildChoiceChip(
                    label: 'High (Urgent)',
                    icon: Icons.priority_high_rounded,
                    value: 'high',
                    selected: _urgency == 'high',
                    selectedColor: AppColors.error,
                    onSelected: (val) => setState(() => _urgency = 'high'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Issue Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title / Subject *',
                  hintText: 'Brief summary of the issue or feedback',
                  prefixIcon: const Icon(Icons.title_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe what happened, steps to reproduce, or details...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

              // Screenshots / Attachments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SCREENSHOTS / ATTACHMENTS (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickAttachments,
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
                    return Chip(
                      avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
                      label: Text(
                        item.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeAttachment(index),
                      backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _handleSend,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSending ? 'Preparing...' : 'Send via Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required String value,
    required bool selected,
    required Color selectedColor,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: selected ? Colors.white : selectedColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: selected ? Colors.white : null, fontSize: 12.5)),
        ],
      ),
      selected: selected,
      selectedColor: selectedColor,
      onSelected: onSelected,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
