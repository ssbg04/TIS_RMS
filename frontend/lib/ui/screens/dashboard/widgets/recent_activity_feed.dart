import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart' as pht;
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../documents/widgets/student_profile_modal.dart';
import '../../../shared/modals/view_activity_modal.dart';
import '../recent_activities_screen.dart';
import '../../../../domain/entities/dashboard_models.dart';

/// Simplified Recent Operational Activity Feed (Priority 4).
/// Displays recent document & student actions with human-readable format
/// and direct one-click links to student targets.
class RecentActivityFeed extends ConsumerWidget {
  const RecentActivityFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).value;
    final userRole = user?.role ?? 'teacher';

    final dashboardAsync = ref.watch(dashboardDataProvider);
    final activities = dashboardAsync.asData?.value.recentActivities.activities ?? [];
    final displayedActivities = activities.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Operational document & student audit trail',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecentActivitiesScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Full History',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Activity List ──
          if (displayedActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 36,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity recorded',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  for (int i = 0; i < displayedActivities.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
                      ),
                    _buildActivityItem(
                      context: context,
                      activity: displayedActivities[i],
                      userRole: userRole,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required BuildContext context,
    required RecentActivity activity,
    required String userRole,
    required bool isDark,
  }) {
    final meta = _getActivityMeta(activity);
    final relativeTime = pht.formatRelative(activity.createdAt);
    final isStudentTarget = activity.entityType.toLowerCase() == 'student' && activity.entityId != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isStudentTarget) {
            showStudentProfileModal(
              context,
              studentId: activity.entityId!,
              userRole: userRole,
              hideEnrollmentActions: true,
            );
          } else {
            ViewActivityModal.show(
              context: context,
              title: activity.action.toUpperCase(),
              description: activity.description,
              date: activity.createdAt,
              icon: meta.icon,
              actionColor: meta.color,
            );
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              // Event icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(meta.icon, size: 17, color: meta.color),
              ),
              const SizedBox(width: 10),

              // Title and human-readable narrative
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (activity.performedBy != null || activity.username != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '• by ${activity.performedBy ?? activity.username}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white38 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ActivityMeta _getActivityMeta(RecentActivity activity) {
    final act = activity.action.toUpperCase();
    final type = activity.entityType.toLowerCase();
    final desc = activity.description;

    // Determine icon and color
    IconData icon = Icons.info_outline;
    Color color = AppColors.primaryGreen;

    if (act.contains('UPLOAD') || desc.toLowerCase().contains('upload')) {
      icon = Icons.cloud_upload_outlined;
      color = AppColors.primaryGreen;
    } else if (act.contains('VERIF') || desc.toLowerCase().contains('verif')) {
      icon = Icons.verified_outlined;
      color = const Color(0xFF1565C0);
    } else if (act.contains('DELETE') || desc.toLowerCase().contains('delet')) {
      icon = Icons.delete_outline_rounded;
      color = AppColors.error;
    } else if (act.contains('CREATE') || act.contains('ENROLL')) {
      icon = Icons.add_circle_outline_rounded;
      color = Colors.teal;
    } else if (act.contains('UPDATE') || act.contains('EDIT')) {
      icon = Icons.edit_note_rounded;
      color = Colors.orange.shade800;
    } else if (type == 'student') {
      icon = Icons.person_outline_rounded;
      color = Colors.indigo;
    }

    // Determine clean title and subtitle
    String title = desc;
    String subtitle = '$act • ${type.toUpperCase()}';

    // Parse natural phrasing from description
    if (desc.isNotEmpty) {
      title = desc;
      subtitle = '$act on $type';
    }

    return _ActivityMeta(icon: icon, color: color, title: title, subtitle: subtitle);
  }
}

class _ActivityMeta {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  _ActivityMeta({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
