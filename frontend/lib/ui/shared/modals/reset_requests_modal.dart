import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(resetRequestsProvider);

    return CustomModal(
      title: 'Password Reset Requests',
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
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                title: Text('${req['first_name']} ${req['last_name']} (@${req['username']})'),
                subtitle: Text('Role: ${(req['role'] as String).toUpperCase().replaceAll('_', ' ')} • Requested: ${(req['requested_at'] as String).split('T').first}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      label: const Text('Approve', style: TextStyle(color: AppColors.success)),
                      onPressed: () async {
                        try {
                          final repo = ref.read(authRepositoryProvider);
                          await repo.approveResetRequest(req['id'] as int);
                          ref.invalidate(resetRequestsProvider);
                          if (!context.mounted) return;
                          showSuccessDialog(context, title: 'Approved', message: 'Password reset approved.');
                        } catch (e) {
                          if (!context.mounted) return;
                          showErrorDialog(context, 'Approval Failed', e.toString());
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        try {
                          final repo = ref.read(authRepositoryProvider);
                          await repo.rejectResetRequest(req['id'] as int);
                          ref.invalidate(resetRequestsProvider);
                          if (!context.mounted) return;
                          showSuccessDialog(context, title: 'Rejected', message: 'Request rejected.');
                        } catch (e) {
                          if (!context.mounted) return;
                          showErrorDialog(context, 'Rejection Failed', e.toString());
                        }
                      },
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
