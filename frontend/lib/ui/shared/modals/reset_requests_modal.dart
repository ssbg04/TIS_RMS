import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../providers/auth_provider.dart';
import '../dialogs/error_dialog.dart';
import '../dialogs/success_dialog.dart';

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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Password Reset Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: requestsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                data: (requests) {
                  if (requests.isEmpty) {
                    return const Center(
                      child: Text('No pending password reset requests.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
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
            ),
          ],
        ),
      ),
    );
  }
}
