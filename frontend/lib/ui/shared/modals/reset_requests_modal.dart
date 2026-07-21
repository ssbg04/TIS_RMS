import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

import '../../providers/auth_provider.dart';
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

  String _formatDate(String isoString) {
    try {
      final utcTime = DateTime.parse(isoString).toUtc();
      final phTime = utcTime.add(const Duration(hours: 8));
      return DateFormat('MMM d, yyyy, hh:mm a').format(phTime);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _confirmAction(BuildContext context, Map<String, dynamic> req, {required bool isApprove}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Approve Request' : 'Reject Request'),
        content: Text('Are you sure you want to ${isApprove ? 'approve' : 'reject'} the password reset request for @${req['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: isApprove ? AppColors.success : Colors.red),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(authRepositoryProvider);
        if (isApprove) {
          await repo.approveResetRequest(req['id'] as int);
        } else {
          await repo.rejectResetRequest(req['id'] as int);
        }
        ref.invalidate(resetRequestsProvider);
        if (mounted) {
          showSuccessDialog(
            context, 
            title: isApprove ? 'Approved' : 'Rejected', 
            message: isApprove ? 'Password reset approved.' : 'Request rejected.',
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorDialog(context, isApprove ? 'Approval Failed' : 'Rejection Failed', e.toString());
        }
      }
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
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        error: (e, _) => Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Error: $e', style: const TextStyle(color: Colors.red)))),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No pending password reset requests.', style: TextStyle(color: Colors.grey)),
              )
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${req['first_name']} ${req['last_name']} (@${req['username']})',
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Requested: ${_formatDate(req['requested_at'] as String)}',
                         style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.success,
                            backgroundColor: AppColors.success.withValues(alpha: 0.1),
                          ),
                          child: const Text('Approve'),
                          onPressed: () => _confirmAction(context, req, isApprove: true),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                          ),
                          child: const Text('Reject'),
                          onPressed: () => _confirmAction(context, req, isApprove: false),
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
