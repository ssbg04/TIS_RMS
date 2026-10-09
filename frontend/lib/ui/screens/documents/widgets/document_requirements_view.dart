import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/document_requirement_model.dart';
import '../../../../domain/entities/student_model.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/student_provider.dart';
import 'requirements_settings_modal.dart';
import 'student_profile_modal.dart';
import 'upload_ocr_modal.dart';

class DocumentRequirementsView extends ConsumerStatefulWidget {
  final String userRole;
  final ValueChanged<String>? onFilterByDocumentType;
  final VoidCallback? onSwitchToDocumentsTab;

  const DocumentRequirementsView({
    super.key,
    required this.userRole,
    this.onFilterByDocumentType,
    this.onSwitchToDocumentsTab,
  });

  @override
  ConsumerState<DocumentRequirementsView> createState() =>
      _DocumentRequirementsViewState();
}

class _DocumentRequirementsViewState
    extends ConsumerState<DocumentRequirementsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(requirementsSettingsProvider);
    final enrolledStudentsAsync = ref.watch(enrolledStudentsForRequirementsProvider);

    return settingsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load document requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(requirementsSettingsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (settings) {
        // Collect all actively enrolled students to calculate missing statistics.
        // Archived, graduated, transferred, or dropped students are strictly excluded.
        final allEnrolled = enrolledStudentsAsync.asData?.value ?? [];
        final students = allEnrolled
            .where((s) => s.status.toLowerCase() == 'enrolled')
            .toList();

        // Filter requirements by local search
        final filteredJhs = settings.jhs.where((r) {
          if (_searchQuery.isEmpty) return true;
          return r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (r.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();

        final filteredShs = settings.shs.where((r) {
          if (_searchQuery.isEmpty) return true;
          return r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (r.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();

        // Calculate compliance stats
        int totalMissingDocsCount = 0;
        final Set<int> studentsWithMissingDocs = {};

        for (final s in students) {
          if (s.missingDocumentsCount > 0 || s.missingDocuments.isNotEmpty) {
            totalMissingDocsCount += s.missingDocumentsCount > 0
                ? s.missingDocumentsCount
                : s.missingDocuments.length;
            studentsWithMissingDocs.add(s.id);
          }
        }

        return RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () async {
            ref.invalidate(requirementsSettingsProvider);
            ref.invalidate(enrolledStudentsForRequirementsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Operational Banner / Summary
                _buildSummaryBanner(
                  isDark: isDark,
                  totalJhs: settings.jhs.where((r) => r.isEnabled).length,
                  totalShs: settings.shs.where((r) => r.isEnabled).length,
                  studentsNeedingAttention: studentsWithMissingDocs.length,
                  totalMissingDocs: totalMissingDocsCount,
                ),
                const SizedBox(height: 16),

                // Controls Bar: Search & Manage Button
                _buildControlsBar(isDark),
                const SizedBox(height: 16),

                // Category 1: Junior High School (JHS) Requirements
                _buildCategoryGroup(
                  title: 'Junior High School (JHS)',
                  subtitle: 'Grades 7 to 10 requirements checklist & compliance',
                  icon: Icons.school_rounded,
                  badgeColor: AppColors.primaryGreen,
                  requirements: filteredJhs,
                  students: students,
                  isDark: isDark,
                  isJhs: true,
                ),
                const SizedBox(height: 20),

                // Category 2: Senior High School (SHS) Requirements
                _buildCategoryGroup(
                  title: 'Senior High School (SHS)',
                  subtitle: 'Grades 11 to 12 requirements checklist & compliance',
                  icon: Icons.history_edu_rounded,
                  badgeColor: const Color(0xFF1565C0),
                  requirements: filteredShs,
                  students: students,
                  isDark: isDark,
                  isJhs: false,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUMMARY BANNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryBanner({
    required bool isDark,
    required int totalJhs,
    required int totalShs,
    required int studentsNeedingAttention,
    required int totalMissingDocs,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.rule_folder_rounded,
                  size: 22,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Requirements & Compliance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Department of Education official document standards & tracking',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          // Metric chips
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildMetricPill(
                label: 'JHS Active',
                value: '$totalJhs items',
                icon: Icons.check_circle_outline,
                color: AppColors.primaryGreen,
                isDark: isDark,
              ),
              _buildMetricPill(
                label: 'SHS Active',
                value: '$totalShs items',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF1565C0),
                isDark: isDark,
              ),
              if (studentsNeedingAttention > 0)
                _buildMetricPill(
                  label: 'Needs Attention',
                  value: '$studentsNeedingAttention students',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                  isDark: isDark,
                )
              else
                _buildMetricPill(
                  label: 'Status',
                  value: 'All Complete',
                  icon: Icons.verified_rounded,
                  color: AppColors.primaryGreen,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLS BAR: SEARCH & CONFIGURE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildControlsBar(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search requirements (e.g. SF9, PSA, SF10)...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (widget.userRole != 'teacher') ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const RequirementsSettingsModal(),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text(
                'Configure',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CATEGORY GROUP (JHS / SHS)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required List<DocumentRequirementModel> requirements,
    required List<StudentModel> students,
    required bool isDark,
    required bool isJhs,
  }) {
    if (requirements.isEmpty && _searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: badgeColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${requirements.length} Requirements',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Requirements Items
          if (requirements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No requirements found.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requirements.length,
              separatorBuilder: (ctx, i) => Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
              ),
              itemBuilder: (context, index) {
                final req = requirements[index];
                return _buildRequirementRow(
                  req: req,
                  students: students,
                  isDark: isDark,
                  isJhs: isJhs,
                );
              },
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REQUIREMENT ROW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRequirementRow({
    required DocumentRequirementModel req,
    required List<StudentModel> students,
    required bool isDark,
    required bool isJhs,
  }) {
    // Filter relevant students based on JHS (grades 7-10) vs SHS (grades 11-12)
    final categoryStudents = students.where((s) {
      final grade = s.latestGradeLevel;
      if (grade == null) return true;
      if (isJhs) return grade <= 10;
      return grade >= 11;
    }).toList();

    // Find students missing this specific document requirement
    final missingStudents = categoryStudents.where((s) {
      final cleanReqName = req.name.toLowerCase().trim();
      final hasMissing = s.missingDocuments.any((doc) {
        final cleanDoc = doc.toLowerCase().trim();
        return cleanDoc == cleanReqName ||
            cleanDoc.contains(cleanReqName) ||
            cleanReqName.contains(cleanDoc);
      });
      return hasMissing;
    }).toList();

    final isEnabled = req.isEnabled;
    final missingCount = missingStudents.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isEnabled ? AppColors.primaryGreen : Colors.grey)
                  .withValues(alpha: isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEnabled ? Icons.assignment_turned_in_outlined : Icons.remove_circle_outline,
              size: 20,
              color: isEnabled ? AppColors.primaryGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        req.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Standard status badge (✓ Active or ○ Inactive)
                    _buildActiveBadge(isEnabled, isDark),
                  ],
                ),
                const SizedBox(height: 3),
                if (req.description != null && req.description!.isNotEmpty)
                  Text(
                    req.description!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                // Compliance Status Badge (✓ Complete or ⚠ Missing)
                if (isEnabled)
                  _buildCompliancePill(
                    missingCount: missingCount,
                    totalStudents: categoryStudents.length,
                    isDark: isDark,
                  )
                else
                  Text(
                    'Requirement currently optional or inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action Buttons
          if (isEnabled) ...[
            if (missingCount > 0)
              IconButton(
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                color: Colors.orange.shade800,
                tooltip: 'View $missingCount missing students',
                onPressed: () => _showMissingStudentsSheet(
                  context,
                  reqName: req.name,
                  missingStudents: missingStudents,
                  isDark: isDark,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.filter_list_rounded, size: 20),
              color: AppColors.primaryGreen,
              tooltip: 'Filter in All Documents',
              onPressed: () {
                widget.onFilterByDocumentType?.call(req.name);
                widget.onSwitchToDocumentsTab?.call();
              },
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS BADGES ACCORDING TO DESIGN SYSTEM
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveBadge(bool isEnabled, bool isDark) {
    if (isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.45 : 0.30),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 10, color: AppColors.primaryGreen),
            SizedBox(width: 2),
            Text(
              'Required',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radio_button_unchecked, size: 9, color: Colors.grey.shade600),
            const SizedBox(width: 2),
            Text(
              'Inactive',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCompliancePill({
    required int missingCount,
    required int totalStudents,
    required bool isDark,
  }) {
    if (missingCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.40 : 0.25),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 12, color: AppColors.primaryGreen),
            SizedBox(width: 4),
            Text(
              '✓ Complete • All students compliant',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      );
    } else {
      final color = Colors.orange.shade800;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.45 : 0.30),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '⚠ $missingCount students missing',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MISSING STUDENTS BOTTOM SHEET / MODAL
  // ══════════════════════════════════════════════════════════════════════════
  void _showMissingStudentsSheet(
    BuildContext context, {
    required String reqName,
    required List<StudentModel> missingStudents,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Missing: $reqName',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${missingStudents.length} students have not submitted this requirement',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Student List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: missingStudents.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
                  ),
                  itemBuilder: (context, i) {
                    final student = missingStudents[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Text(
                        student.listDisplayName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'LRN: ${student.lrn} • ${student.gradeSection}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                            tooltip: 'Upload $reqName',
                            color: AppColors.primaryGreen,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              UploadOcrModal.show(
                                context,
                                prefilledStudentId: student.id,
                                prefilledLrn: student.lrn,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_outline_rounded, size: 20),
                            tooltip: 'View Profile',
                            color: isDark ? Colors.white70 : Colors.black87,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              showStudentProfileModal(
                                context,
                                studentId: student.id,
                                userRole: widget.userRole,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
