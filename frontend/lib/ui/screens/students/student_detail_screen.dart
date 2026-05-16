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
        title: const Text('Student Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                ...student.enrollments!.map<Widget>((e) => _buildEnrollmentCard(e)).toList(),
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
                      '${student.firstName} ${student.middleName != null ? student.middleName + ' ' : ''}${student.lastName} ${student.extension ?? ''}',
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
          Row(
            children: [
              _buildInfoItem('Sex', student.sex),
              const SizedBox(width: AppSizes.p24),
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

  Widget _buildRequirementsStatus(MissingRequirements missing) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Row(
            children: [
              _buildStatusChip(
                'Total Required',
                '${missing.totalRequired}',
                AppColors.primaryGreen,
              ),
              const SizedBox(width: AppSizes.p8),
              _buildStatusChip(
                'Verified',
                '${missing.totalVerified}',
                AppColors.success,
              ),
              const SizedBox(width: AppSizes.p8),
              _buildStatusChip(
                'Missing',
                '${missing.totalRequired - missing.totalVerified}',
                missing.totalRequired - missing.totalVerified > 0
                    ? AppColors.error
                    : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p16),

          // Missing Documents
          if (missing.missing.isNotEmpty) ...[
            const Text('Missing Documents', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
            const SizedBox(height: AppSizes.p8),
            ...missing.missing.map((req) => _buildRequirementItem(req.name, 'Missing', AppColors.error)),
            const SizedBox(height: AppSizes.p12),
          ],

          // Pending Documents
          if (missing.pending.isNotEmpty) ...[
            const Text('Pending Documents', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
            const SizedBox(height: AppSizes.p8),
            ...missing.pending.map((req) => _buildRequirementItem(
              req.name,
              'Pending',
              Colors.orange,
            )),
            const SizedBox(height: AppSizes.p12),
          ],

          // Verified Documents
          if (missing.verified.isNotEmpty) ...[
            const Text('Verified Documents', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
            const SizedBox(height: AppSizes.p8),
            ...missing.verified.map((req) => _buildRequirementItem(req.name, 'Verified', AppColors.success)),
          ],

          if (missing.missing.isEmpty && missing.pending.isEmpty && missing.verified.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.p24),
                child: Text('No document requirements for this student', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
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

  Widget _buildRequirementItem(String name, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            status == 'Verified' ? Icons.check_circle : Icons.warning,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
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
      case 'Transferred Out':
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