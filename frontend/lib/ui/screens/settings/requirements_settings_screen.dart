import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/document_provider.dart';
import '../../../domain/entities/document_requirement_model.dart';

class RequirementsSettingsScreen extends ConsumerStatefulWidget {
  const RequirementsSettingsScreen({super.key});

  @override
  ConsumerState<RequirementsSettingsScreen> createState() => _RequirementsSettingsScreenState();
}

class _RequirementsSettingsScreenState extends ConsumerState<RequirementsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(requirementsSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSizes.p24),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  tabs: const [
                    Tab(text: 'JHS Requirements'),
                    Tab(text: 'SHS Requirements'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              Expanded(
                child: settingsAsync.when(
                  data: (settings) => TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequirementsList(settings.jhs),
                      _buildRequirementsList(settings.shs),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: AppSizes.p16),
                        Text('Error: $e', style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: AppSizes.p16),
                        PrimaryButton(
                          label: 'Retry',
                          onPressed: () => ref.invalidate(requirementsSettingsProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showAddRequirementModal(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Document Type', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSizes.p8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document Requirements',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'Configure required documents for JHS and SHS students',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsList(List<DocumentRequirementModel> requirements) {
    if (requirements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.p16),
            const Text('No requirements configured', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'Click the button below to add document requirements',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: requirements.length,
      itemBuilder: (context, index) {
        final req = requirements[index];
        return _buildRequirementCard(req);
      },
    );
  }

  Widget _buildRequirementCard(DocumentRequirementModel req) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p8),
        childrenPadding: const EdgeInsets.all(AppSizes.p16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: req.isMandatory
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            req.isMandatory ? Icons.warning_amber : Icons.check_circle_outline,
            color: req.isMandatory ? AppColors.error : AppColors.primaryGreen,
          ),
        ),
        title: Text(
          req.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: req.category == 'JHS'
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: req.category == 'JHS' ? Colors.blue : Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: req.isMandatory
                        ? AppColors.error.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req.isMandatory ? 'Mandatory' : 'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      color: req.isMandatory ? AppColors.error : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: req.isEnabled
                        ? AppColors.success.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req.isEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: req.isEnabled ? AppColors.success : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (req.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Due: ${_formatDate(req.dueDate!)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        children: [
          if (req.description != null && req.description!.isNotEmpty) ...[
            Text(req.description!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSizes.p12),
          ],
          _buildDetailRow('Accepted File Types', req.acceptedFileTypes),
          _buildDetailRow('School Levels', req.schoolLevels),
          const SizedBox(height: AppSizes.p16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showEditRequirementModal(context, req),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: AppSizes.p8),
              TextButton.icon(
                onPressed: () => _confirmDelete(req),
                icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                label: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showAddRequirementModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RequirementFormModal(
        category: _tabController.index == 0 ? 'JHS' : 'SHS',
      ),
    );
  }

  void _showEditRequirementModal(BuildContext context, DocumentRequirementModel req) {
    showDialog(
      context: context,
      builder: (context) => RequirementFormModal(
        requirement: req,
        category: req.category,
      ),
    );
  }

  void _confirmDelete(DocumentRequirementModel req) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Requirement', style: TextStyle(color: AppColors.error)),
        content: Text('Are you sure you want to delete "${req.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(requirementMutationProvider.notifier).deleteRequirement(req.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Requirement deleted'), backgroundColor: AppColors.success),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

class RequirementFormModal extends ConsumerStatefulWidget {
  final DocumentRequirementModel? requirement;
  final String category;

  const RequirementFormModal({
    super.key,
    this.requirement,
    required this.category,
  });

  @override
  ConsumerState<RequirementFormModal> createState() => _RequirementFormModalState();
}

class _RequirementFormModalState extends ConsumerState<RequirementFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dueDateController;

  late String _category;
  late bool _isMandatory;
  late bool _isEnabled;
  late String _acceptedFileTypes;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final req = widget.requirement;
    _nameController = TextEditingController(text: req?.name ?? '');
    _descController = TextEditingController(text: req?.description ?? '');
    _dueDateController = TextEditingController(
      text: req?.dueDate != null ? '${req!.dueDate!.month}/${req.dueDate!.day}/${req.dueDate!.year}' : '',
    );
    _category = req?.category ?? widget.category;
    _isMandatory = req?.isMandatory ?? true;
    _isEnabled = req?.isEnabled ?? true;
    _acceptedFileTypes = req?.acceptedFileTypes ?? 'pdf,jpg,jpeg,png';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.requirement != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Document Type' : 'Add Document Type'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  hintText: 'Document Name',
                  controller: _nameController,
                  prefixIcon: Icons.description,
                  validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSizes.p12),
                CustomTextField(
                  hintText: 'Description',
                  controller: _descController,
                  prefixIcon: Icons.notes,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.p12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(),
                  ),
                  items: ['JHS', 'SHS'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: AppSizes.p12),
                CustomTextField(
                  hintText: 'Due Date (MM/DD/YYYY)',
                  controller: _dueDateController,
                  prefixIcon: Icons.calendar_today,
                ),
                const SizedBox(height: AppSizes.p12),
                DropdownButtonFormField<String>(
                  value: _acceptedFileTypes,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.attach_file),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pdf', child: Text('PDF only')),
                    DropdownMenuItem(value: 'pdf,jpg,jpeg,png', child: Text('PDF, JPG, PNG')),
                    DropdownMenuItem(value: 'pdf,doc,docx', child: Text('PDF, Word')),
                    DropdownMenuItem(value: 'pdf,jpg,jpeg,png,doc,docx', child: Text('All')),
                  ],
                  onChanged: (v) => setState(() => _acceptedFileTypes = v!),
                ),
                const SizedBox(height: AppSizes.p16),
                SwitchListTile(
                  title: const Text('Mandatory'),
                  value: _isMandatory,
                  onChanged: (v) => setState(() => _isMandatory = v),
                  activeColor: AppColors.error,
                ),
                SwitchListTile(
                  title: const Text('Enabled'),
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        PrimaryButton(
          label: isEditing ? 'UPDATE' : 'CREATE',
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      DateTime? dueDate;
      if (_dueDateController.text.trim().isNotEmpty) {
        final parts = _dueDateController.text.trim().split('/');
        if (parts.length == 3) {
          dueDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }

      final requirement = DocumentRequirementModel(
        id: widget.requirement?.id ?? 0,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        category: _category,
        isMandatory: _isMandatory,
        isEnabled: _isEnabled,
        dueDate: dueDate,
        acceptedFileTypes: _acceptedFileTypes,
        schoolLevels: 'JHS,SHS',
      );

      if (widget.requirement != null) {
        await ref.read(requirementMutationProvider.notifier).updateRequirement(requirement);
      } else {
        await ref.read(requirementMutationProvider.notifier).createRequirement(requirement);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.requirement != null ? 'Requirement updated' : 'Requirement created'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}