import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../providers/document_provider.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../../domain/entities/document_requirement_model.dart';

class RequirementsSettingsModal extends ConsumerStatefulWidget {
  const RequirementsSettingsModal({super.key});

  @override
  ConsumerState<RequirementsSettingsModal> createState() => _RequirementsSettingsModalState();
}

class _RequirementsSettingsModalState extends ConsumerState<RequirementsSettingsModal> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(documentRequirementsSettingsProvider);

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, color: AppColors.primaryGreen, size: 28),
                      SizedBox(width: AppSizes.p12),
                      Text(
                        'Document Requirements Settings',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: AppSizes.p32),

              // Content
              Expanded(
                child: settingsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
                  data: (settings) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategorySection('Junior High School (JHS)', settings.jhs),
                        const SizedBox(height: AppSizes.p24),
                        _buildCategorySection('Senior High School (SHS)', settings.shs),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              const Divider(height: AppSizes.p32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addNewRequirement,
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Requirement'),
                  ),
                  PrimaryButton(
                    label: 'DONE',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<DocumentRequirementModel> requirements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.p16),
        if (requirements.isEmpty)
          const Text('No requirements configured.', style: TextStyle(color: AppColors.textSecondary))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requirements.length,
            itemBuilder: (context, index) {
              final req = requirements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSizes.p8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                child: ListTile(
                  title: Text(req.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${req.description ?? "No description"} | Mandatory: ${req.isMandatory ? "Yes" : "No"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: req.isEnabled ?? true,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (val) {
                          _toggleRequirement(req, val);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _deleteRequirement(req.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _addNewRequirement() {
    // Show dialog to add a new requirement
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add requirement form coming soon')));
  }

  void _toggleRequirement(DocumentRequirementModel req, bool isEnabled) async {
    try {
      final updatedReq = DocumentRequirementModel(
        id: req.id,
        name: req.name,
        description: req.description,
        category: req.category,
        isMandatory: req.isMandatory,
        isEnabled: isEnabled,
        dueDate: req.dueDate,
        acceptedFileTypes: req.acceptedFileTypes,
        schoolLevels: req.schoolLevels,
      );
      await ref.read(documentRequirementsMutationProvider.notifier).updateRequirement(updatedReq);
      ref.invalidate(documentRequirementsSettingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _deleteRequirement(int id) async {
    try {
      await ref.read(documentRequirementsMutationProvider.notifier).deleteRequirement(id);
      ref.invalidate(documentRequirementsSettingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
