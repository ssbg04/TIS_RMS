import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/system_settings_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/info_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/modals/custom_modal.dart';
import '../../../shared/widgets/app_skeleton_loader.dart';

class AcademicGraduationSection extends ConsumerWidget {
  const AcademicGraduationSection({super.key});

  Future<void> _handleRunAutoGraduation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isNarrow =
            MediaQuery.of(ctx).size.width < 600 ||
            Theme.of(ctx).platform == TargetPlatform.android;
        return AlertDialog(
          title: const Text('Confirm Auto-Graduation'),
          content: const Text(
            'This will check the active academic year schedule and automatically graduate eligible Grade 10 and Grade 12 students if the schedule end date has been reached.\n\nDo you want to proceed?',
          ),
          actions: [
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('PROCEED'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('CANCEL'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('PROCEED'),
                  ),
                ],
              ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final res = await ref
          .read(setupMutationProvider.notifier)
          .checkAutoGraduation();
      if (!context.mounted) return;
      final executed = res['executed'] == true;
      showInfoDialog(
        context,
        title: executed
            ? 'Auto-Graduation Completed'
            : 'Auto-Graduation Skipped',
        message:
            res['message']?.toString() ??
            res['reason']?.toString() ??
            'Check completed.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        'Check Failed',
        'Failed to run auto-graduation check: $e',
      );
    }
  }

  Widget _buildFunctionalCard({
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAcademicGraduationSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: const Row(
            children: [
              AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLoader(width: 120, height: 11),
                    SizedBox(height: 6),
                    AppSkeletonLoader(width: 160, height: 16),
                  ],
                ),
              ),
              AppSkeletonLoader(width: 54, height: 22, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            AppSkeletonLoader(width: 130, height: 14),
            SizedBox(width: 16),
            AppSkeletonLoader(width: 130, height: 14),
          ],
        ),
        const SizedBox(height: 14),
        const AppSkeletonLoader(
          width: double.infinity,
          height: 42,
          borderRadius: 8,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final sysSettingsAsync = ref.watch(systemSettingsProvider);
    final settingsMap = sysSettingsAsync.asData?.value ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        academicYearsAsync.when(
          loading: () => Column(
            children: [
              _buildFunctionalCard(
                isDark: isDark,
                icon: Icons.calendar_month_rounded,
                title: 'Active Academic Year & Schedule',
                subtitle: 'Current school year and date boundaries',
                child: _buildAcademicGraduationSkeleton(isDark),
              ),
              const SizedBox(height: 16),
              _buildFunctionalCard(
                isDark: isDark,
                icon: Icons.school_rounded,
                title: 'Auto-Graduation',
                subtitle: 'Sequential graduation for Grade 10 and Grade 12',
                child: const AppSkeletonLoader(
                  width: double.infinity,
                  height: 44,
                  borderRadius: 8,
                ),
              ),
            ],
          ),
          error: (err, _) => Text(
            'Error loading academic years: $err',
            style: const TextStyle(color: Colors.red),
          ),
          data: (years) {
            final activeYear = years.cast<AcademicYearModel?>().firstWhere(
              (y) => y?.status == 'active',
              orElse: () => null,
            );
            if (years.isEmpty) {
              return _buildFunctionalCard(
                isDark: isDark,
                icon: Icons.calendar_month_rounded,
                title: 'Active Academic Year & Schedule',
                subtitle: 'Current school year and date boundaries',
                trailing: IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh Academic Year',
                  onPressed: () => ref.invalidate(academicYearsListProvider),
                ),
                child: const Text(
                  'No academic years found. Configure an academic year in Academic & Class Management first.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Active Academic Year & Schedule ──
                _buildFunctionalCard(
                  isDark: isDark,
                  icon: Icons.calendar_month_rounded,
                  title: 'Active Academic Year & Schedule',
                  subtitle: 'Current school year and schedule dates',
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh Academic Year',
                    onPressed: () => ref.invalidate(academicYearsListProvider),
                  ),
                  child: activeYear == null
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'No active academic year found. An administrator must activate a school year in Academic & Class Management.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceCard
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    color: AppColors.primaryGreen,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Active Academic Year',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          activeYear.yearRange,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 20,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 15,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Start: ${activeYear.startDate ?? "Not set"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.event_available_outlined,
                                      size: 15,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'End: ${activeYear.endDate ?? "Not set"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    _EditScheduleDatesDialog(year: activeYear),
                              ),
                              icon: const Icon(Icons.date_range),
                              label: const Text('Edit Schedule Dates'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                if (activeYear != null) ...[
                  const SizedBox(height: 16),
                  // ── Section 2: Auto-Graduation ──
                  _buildFunctionalCard(
                    isDark: isDark,
                    icon: Icons.school_rounded,
                    title: 'Auto-Graduation',
                    subtitle:
                        'Promote or graduate eligible students automatically',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue.withValues(alpha: 0.08)
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-graduation runs sequentially (Grade 10 then Grade 12) once end date is reached. Requires both dates set.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () =>
                              _handleRunAutoGraduation(context, ref),
                          icon: const Icon(Icons.school),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Check / Run Auto-Graduation Now'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // ── Section 3: Auto-Archiving Grace Period ──
        _buildFunctionalCard(
          isDark: isDark,
          icon: Icons.archive_outlined,
          title: 'Auto-Archiving Grace Period',
          subtitle: 'Cutoff schedule for archiving inactive enrollments',
          child: (sysSettingsAsync.isLoading && !sysSettingsAsync.hasValue)
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLoader(width: 180, height: 14),
                    SizedBox(height: 10),
                    AppSkeletonLoader(
                      width: double.infinity,
                      height: 42,
                      borderRadius: 8,
                    ),
                  ],
                )
              : _GracePeriodSettingsSection(settingsMap: settingsMap),
        ),
      ],
    );
  }
}

class _EditScheduleDatesDialog extends ConsumerStatefulWidget {
  final AcademicYearModel year;
  const _EditScheduleDatesDialog({required this.year});

  @override
  ConsumerState<_EditScheduleDatesDialog> createState() =>
      _EditScheduleDatesDialogState();
}

class _EditScheduleDatesDialogState
    extends ConsumerState<_EditScheduleDatesDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.year.startDate != null
        ? DateTime.tryParse(widget.year.startDate!)
        : null;
    _endDate = widget.year.endDate != null
        ? DateTime.tryParse(widget.year.endDate!)
        : null;
  }

  String? _formatYmd(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(setupMutationProvider.notifier)
          .updateAcademicYear(
            id: widget.year.id,
            yearRange: widget.year.yearRange,
            status: widget.year.status,
            startDate: _formatYmd(_startDate),
            endDate: _formatYmd(_endDate),
          );
      ref.invalidate(academicYearsListProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message:
            'Schedule dates updated for Academic Year ${widget.year.yearRange}!',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Save Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow =
        MediaQuery.of(context).size.width < 500 ||
        Theme.of(context).platform == TargetPlatform.android;

    return CustomModal(
      title: 'Edit Schedule Dates',
      icon: Icons.calendar_today,
      maxWidth: 460,
      content: Padding(
        padding: EdgeInsets.all(isNarrow ? 14 : AppSizes.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Academic Year: ${widget.year.yearRange} (${widget.year.status.toUpperCase()})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300,
                      ),
                      color: isDark
                          ? AppColors.darkSurface2
                          : Colors.grey.shade50,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _startDate != null
                                        ? _formatYmd(_startDate)!
                                        : 'Select Start',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_startDate != null)
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _startDate = null),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300,
                      ),
                      color: isDark
                          ? AppColors.darkSurface2
                          : Colors.grey.shade50,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _endDate ?? _startDate ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _endDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Date',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _endDate != null
                                        ? _formatYmd(_endDate)!
                                        : 'Select End',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_endDate != null)
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _endDate = null),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Save Dates'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancel'),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Cancel'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Save Dates'),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GracePeriodSettingsSection extends ConsumerStatefulWidget {
  final Map<String, String> settingsMap;

  const _GracePeriodSettingsSection({required this.settingsMap});

  @override
  ConsumerState<_GracePeriodSettingsSection> createState() =>
      _GracePeriodSettingsSectionState();
}

class _GracePeriodSettingsSectionState
    extends ConsumerState<_GracePeriodSettingsSection> {
  DateTime? _selectedCutoffDate;
  DateTime? _initialCutoffDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initCutoffDate();
  }

  @override
  void didUpdateWidget(covariant _GracePeriodSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsMap['auto_archive_datetime'] !=
            widget.settingsMap['auto_archive_datetime'] ||
        oldWidget.settingsMap['enrollment_grace_period_days'] !=
            widget.settingsMap['enrollment_grace_period_days']) {
      _initCutoffDate();
    }
  }

  void _initCutoffDate() {
    final dtStr = widget.settingsMap['auto_archive_datetime'];
    if (dtStr != null && dtStr.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(dtStr);
      if (parsed != null) {
        _selectedCutoffDate = parsed;
        _initialCutoffDate = parsed;
        return;
      }
    }

    // Fallback: start_date of active year + grace period days
    final graceDays =
        int.tryParse(
          widget.settingsMap['enrollment_grace_period_days'] ?? '30',
        ) ??
        30;
    final years = ref.read(academicYearsListProvider).asData?.value ?? [];
    final active = years.cast<AcademicYearModel?>().firstWhere(
      (y) => y?.status == 'active',
      orElse: () => null,
    );
    final activeStartDate = active?.startDate;
    if (activeStartDate != null) {
      final start = DateTime.tryParse(activeStartDate);
      if (start != null) {
        _selectedCutoffDate = start.add(Duration(days: graceDays));
        _initialCutoffDate = _selectedCutoffDate;
        return;
      }
    }
    _selectedCutoffDate = DateTime.now().add(Duration(days: graceDays));
    _initialCutoffDate = _selectedCutoffDate;
  }

  String _formatDisplayDate(DateTime? dt) {
    if (dt == null) return 'No cutoff date selected';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _pickCutoffDate(BuildContext context) async {
    final initial = _selectedCutoffDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedCutoffDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _saveCutoffDate(AcademicYearModel? activeYear) async {
    if (_selectedCutoffDate == null) return;
    setState(() => _isSaving = true);

    try {
      final isoString = _selectedCutoffDate!.toIso8601String();
      int calculatedDays = 30;

      final activeStartDate = activeYear?.startDate;
      if (activeStartDate != null) {
        final start = DateTime.tryParse(activeStartDate);
        if (start != null) {
          calculatedDays = _selectedCutoffDate!.difference(start).inDays;
        }
      } else {
        calculatedDays = _selectedCutoffDate!.difference(DateTime.now()).inDays;
      }

      final safeDays = calculatedDays > 0 ? calculatedDays.toString() : '0';

      await ref
          .read(systemSettingsProvider.notifier)
          .updateSetting('auto_archive_datetime', isoString);
      await ref
          .read(systemSettingsProvider.notifier)
          .updateSetting('enrollment_grace_period_days', safeDays);

      if (mounted) {
        setState(() {
          _initialCutoffDate = _selectedCutoffDate;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Archiving cutoff date saved: ${_formatDisplayDate(_selectedCutoffDate)} ($safeDays days grace period)',
            ),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save cutoff date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled =
        (widget.settingsMap['auto_archive_enabled'] ?? 'true') != 'false';

    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final activeYear = academicYearsAsync.asData?.value
        .cast<AcademicYearModel?>()
        .firstWhere((y) => y?.status == 'active', orElse: () => null);

    int diffDays = 0;
    final activeStartDate = activeYear?.startDate;
    if (_selectedCutoffDate != null) {
      if (activeStartDate != null) {
        final start = DateTime.tryParse(activeStartDate);
        if (start != null) {
          diffDays = _selectedCutoffDate!.difference(start).inDays;
        }
      } else {
        diffDays = _selectedCutoffDate!.difference(DateTime.now()).inDays;
      }
    }

    final bool isCutoffChanged =
        _selectedCutoffDate != null &&
        (_initialCutoffDate == null ||
            _selectedCutoffDate!.year != _initialCutoffDate!.year ||
            _selectedCutoffDate!.month != _initialCutoffDate!.month ||
            _selectedCutoffDate!.day != _initialCutoffDate!.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row with Toggle
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.archive_outlined,
              color: AppColors.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic Archiving Grace Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set a cutoff date for auto-archiving. Students with status "Enrolled" who have no enrollment in the active academic year will be marked Inactive and archived once this cutoff date is reached.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) {
                ref
                    .read(systemSettingsProvider.notifier)
                    .updateSetting('auto_archive_enabled', val.toString());
              },
            ),
          ],
        ),
        const SizedBox(height: AppSizes.p12),

        if (!isEnabled) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.withValues(alpha: isDark ? 0.3 : 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Automatic archiving is currently turned OFF. Enrolled students will not be automatically archived.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Cutoff Date Picker Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _pickCutoffDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cutoff Date (Grace Period Deadline)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDisplayDate(_selectedCutoffDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickCutoffDate(context),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 15),
                      label: const Text(
                        'Change Date',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Calculated Days Helper Preview
          Builder(
            builder: (_) {
              Color bgColor;
              Color borderColor;
              Color textColor;
              IconData iconData;
              String helperText;

              if (activeStartDate != null) {
                if (diffDays > 0) {
                  bgColor = AppColors.primaryGreen.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  );
                  borderColor = AppColors.primaryGreen.withValues(alpha: 0.3);
                  textColor = isDark
                      ? Colors.green.shade300
                      : AppColors.primaryGreen;
                  iconData = Icons.schedule_rounded;
                  helperText =
                      'Grace Period: $diffDays days after active school year start ($activeStartDate)';
                } else if (diffDays == 0) {
                  bgColor = Colors.amber.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  );
                  borderColor = Colors.amber.withValues(alpha: 0.4);
                  textColor = isDark
                      ? Colors.amber.shade300
                      : Colors.amber.shade900;
                  iconData = Icons.warning_amber_rounded;
                  helperText =
                      'Cutoff matches first day of classes ($activeStartDate) — 0 days grace period.';
                } else {
                  bgColor = Colors.red.withValues(alpha: isDark ? 0.15 : 0.08);
                  borderColor = Colors.red.withValues(alpha: 0.4);
                  textColor = isDark
                      ? Colors.red.shade300
                      : Colors.red.shade800;
                  iconData = Icons.error_outline_rounded;
                  helperText =
                      'Cutoff is ${diffDays.abs()} days before school year start ($activeStartDate). Please select a date after opening.';
                }
              } else {
                bgColor = isDark
                    ? AppColors.darkSurfaceCard
                    : Colors.grey.shade100;
                borderColor = isDark
                    ? AppColors.darkBorder
                    : Colors.grey.shade300;
                textColor = isDark
                    ? AppColors.darkTextSecondary
                    : Colors.grey.shade700;
                iconData = Icons.info_outline_rounded;
                helperText =
                    'Calculated: $diffDays days from today (No active school year start date configured).';
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(iconData, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        helperText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (isCutoffChanged) ...[
            const SizedBox(height: 12),

            // Save Button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveCutoffDate(activeYear),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Cutoff Date',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
