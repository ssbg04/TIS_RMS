import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as date_utils;

import '../../providers/auth_provider.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/error_dialog.dart';
import '../dialogs/success_dialog.dart';
import 'custom_modal.dart';

class ResetRequestsModal extends ConsumerStatefulWidget {
  const ResetRequestsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ResetRequestsModal(),
    );
  }

  @override
  ConsumerState<ResetRequestsModal> createState() => _ResetRequestsModalState();
}

class _ResetRequestsModalState extends ConsumerState<ResetRequestsModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(resetRequestsProvider);
    });
  }

  Future<void> _confirmAction(
    Map<String, dynamic> req, {
    required bool isApprove,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: isApprove ? 'Approve Reset Request' : 'Reject Reset Request',
      message:
          'Are you sure you want to ${isApprove ? 'approve' : 'reject'} the password reset request for @${req['username']}?',
      confirmLabel: isApprove ? 'Approve' : 'Reject',
      isDanger: !isApprove,
      confirmColor: isApprove ? AppColors.success : AppColors.error,
      icon: isApprove ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
      iconColor: isApprove ? AppColors.success : AppColors.error,
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(authRepositoryProvider);
      if (isApprove) {
        await repo.approveResetRequest(req['id'] as int);
      } else {
        await repo.rejectResetRequest(req['id'] as int);
      }
      ref.invalidate(resetRequestsProvider);
      if (!mounted) return;
      showSuccessDialog(
        context,
        title: isApprove ? 'Approved' : 'Rejected',
        message: isApprove
            ? 'Password reset approved.'
            : 'Request rejected.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        isApprove ? 'Approval Failed' : 'Rejection Failed',
        e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(resetRequestsProvider);

    return CustomModal(
      title: 'Reset Requests',
      icon: Icons.lock_clock,
      maxWidth: 500,
      content: requestsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No pending password reset requests.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${req['first_name']} ${req['last_name']} (@${req['username']})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested: ${date_utils.formatModalDate(req['requested_at'] as String)}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.success,
                            backgroundColor: AppColors.success.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          child: const Text('Approve'),
                          onPressed: () =>
                              _confirmAction(req, isApprove: true),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                          ),
                          child: const Text('Reject'),
                          onPressed: () =>
                              _confirmAction(req, isApprove: false),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
