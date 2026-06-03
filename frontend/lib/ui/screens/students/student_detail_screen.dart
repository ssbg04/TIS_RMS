import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/repositories/document_repository.dart' show MissingRequirements;
import '../../providers/student_provider.dart';
import '../../providers/document_provider.dart';

class StudentDetailScreen extends ConsumerWidget {
  final int studentId;
  final String userRole;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final missingReqsAsync = ref.watch(missingRequirementsProvider(studentId));

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Student Profile', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: studentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSizes.p16),
              Text('Error: $e', style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        data: (student) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Info Card
              _buildInfoCard(student),
              const SizedBox(height: AppSizes.p24),

              // Enrollments
              if (student.enrollments != null && student.enrollments!.isNotEmpty) ...[
                const Text('Enrollments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSizes.p12),
                ...(() {
                  final sorted = List.from(student.enrollments!);
                  // Ensure they are sorted descending by gradeLevel
                  sorted.sort((a, b) => (b.gradeLevel ?? 0).compareTo(a.gradeLevel ?? 0));
                  return sorted.map<Widget>((e) => _buildEnrollmentCard(e)).toList();
                })(),
                const SizedBox(height: AppSizes.p24),
              ],

              // Document Requirements Status
              const Text('Document Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSizes.p12),
              missingReqsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading requirements: $e', style: const TextStyle(color: AppColors.error)),
                data: (missing) => _buildRequirementsStatus(missing),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(dynamic student) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  '${student.firstName?[0] ?? ''}${student.lastName?[0] ?? ''}',
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.middleName != null ? student.middleName! + ' ' : ''}${student.lastName}${student.extension?.isNotEmpty == true ? ', ${student.extension}' : ''}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'LRN: ${student.lrn}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(student.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  student.status ?? 'Enrolled',
                  style: TextStyle(
                    color: _getStatusColor(student.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Wrap(
            spacing: AppSizes.p24,
            runSpacing: AppSizes.p12,
            children: [
              _buildInfoItem('Sex', student.sex),
              _buildInfoItem('Birth Date', _formatDate(student.birthDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEnrollmentCard(dynamic enrollment) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p8),
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school, color: Colors.blue),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grade ${enrollment.gradeLevel}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${enrollment.sectionName ?? 'N/A'} - ${enrollment.yearRange ?? 'N/A'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                if (enrollment.trackStrand != null)
                  Text(
                    'Track: ${enrollment.trackStrand}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsStatus(MissingRequirements data) {
    // Group requirements by category
    final jhsMissing   = data.missing.where((r) => r.category == 'JHS').toList();
    final shsMissing   = data.missing.where((r) => r.category == 'SHS').toList();
    final jhsVerified  = data.verified.where((r) => r.category == 'JHS').toList();
    final shsVerified  = data.verified.where((r) => r.category == 'SHS').toList();

    final jhsTotal     = jhsMissing.length + jhsVerified.length;
    final shsTotal     = shsMissing.length + shsVerified.length;

    final hasJhs = jhsTotal > 0;
    final hasShs = shsTotal > 0;

    if (!hasJhs && !hasShs) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.p24),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('No document requirements for this student.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasJhs) ...[
          _buildLevelSection(
            label: 'JHS',
            color: Colors.teal,
            isCurrent: data.category == 'JHS',
            missing: jhsMissing,
            verified: jhsVerified,
            total: jhsTotal,
          ),
          if (hasShs) const SizedBox(height: AppSizes.p16),
        ],
        if (hasShs)
          _buildLevelSection(
            label: 'SHS',
            color: Colors.purple,
            isCurrent: data.category == 'SHS',
            missing: shsMissing,
            verified: shsVerified,
            total: shsTotal,
          ),
      ],
    );
  }

  Widget _buildLevelSection({
    required String label,
    required Color color,
    required bool isCurrent,
    required List<dynamic> missing,
    required List<dynamic> verified,
    required int total,
  }) {
    final completed = verified.length;
    final missingCount = missing.length;
    final isDone = missingCount == 0 && total > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: isDone ? AppColors.success.withValues(alpha: 0.4) : color.withValues(alpha: 0.25),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusMedium),
                topRight: Radius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Current Level',
                        style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                // Compact summary
                if (isDone)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Complete', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                  ])
                else
                  Text(
                    '$completed/$total done',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),

          // ── Summary chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.p16, AppSizes.p12, AppSizes.p16, 0),
            child: Wrap(
              spacing: AppSizes.p8,
              runSpacing: AppSizes.p8,
              children: [
                _buildStatusChip('Total', '$total', color),
                _buildStatusChip('Completed', '$completed', AppColors.success),
                _buildStatusChip('Missing', '$missingCount',
                    missingCount > 0 ? AppColors.error : AppColors.success),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.p16),
            child: Divider(height: 24),
          ),

          // ── Missing list ──
          if (missing.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              child: Text('Not Yet Submitted',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade700, fontSize: 13)),
            ),
            const SizedBox(height: AppSizes.p8),
            ...missing.map((req) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              child: _buildRequirementItem(
                req.name,
                'Missing',
                Colors.orange.shade700,
                Icons.pending_actions,
                isMandatory: req.isMandatory ?? false,
              ),
            )),
            const SizedBox(height: AppSizes.p12),
          ],

          // ── Verified list ──
          if (verified.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              child: const Text('Completed',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success, fontSize: 13)),
            ),
            const SizedBox(height: AppSizes.p8),
            ...verified.map((req) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              child: _buildRequirementItem(
                req.name,
                'Completed',
                AppColors.success,
                Icons.check_circle,
                isMandatory: req.isMandatory ?? false,
              ),
            )),
          ],

          if (missing.isEmpty && verified.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSizes.p16),
              child: Text('No requirements configured for this level.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),

          const SizedBox(height: AppSizes.p16),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String name, String status, Color color, IconData icon, {bool isMandatory = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                children: [
                  TextSpan(text: name),
                  TextSpan(
                    text: isMandatory ? ' (Mandatory)' : ' (Optional)',
                    style: TextStyle(
                      color: isMandatory ? Colors.red : Colors.grey,
                      fontWeight: isMandatory ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Enrolled':
        return AppColors.success;
      case 'Graduated':
        return Colors.blue;
      case 'Transferred':
        return Colors.orange;
      case 'Dropped':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return '${date.month}/${date.day}/${date.year}';
    }
    return date.toString();
  }
}
