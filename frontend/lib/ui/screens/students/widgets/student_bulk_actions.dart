import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../students_screen.dart';

class StudentBulkActions {
  static void bulkEnroll(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.read(studentSelectedIdsProvider);
    if (selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => BulkEnrollDialog(
        studentIds: selectedIds,
        onSuccess: () {
          ref.read(studentSelectedIdsProvider.notifier).state = [];
          ref.read(studentMultiSelectProvider.notifier).state = false;
          showSuccessDialog(
            context,
            message: 'Students successfully enrolled.',
          );
        },
      ),
    );
  }

  static Future<void> bulkGraduate(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(studentSelectedIdsProvider);
    if (selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Graduate'),
        content: Text(
          'Are you sure you want to change the status of ${selectedIds.length} selected student(s) to "Graduated"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('GRADUATE'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(studentMutationProvider.notifier)
            .bulkGraduate(selectedIds);
        if (context.mounted) {
          ref.read(studentSelectedIdsProvider.notifier).state = [];
          ref.read(studentMultiSelectProvider.notifier).state = false;
          showSuccessDialog(
            context,
            message: 'Students successfully graduated.',
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          showErrorDialog(context, 'Error', errMsg);
        }
      }
    }
  }

  static Future<void> bulkChangeStatus(
    BuildContext context,
    WidgetRef ref,
    String newStatus,
  ) async {
    final selectedIds = ref.read(studentSelectedIdsProvider);
    if (selectedIds.isEmpty) return;

    final allStudents = ref.read(studentPageProvider).value?.students ?? [];
    final selectedStudents = allStudents
        .where((s) => selectedIds.contains(s.id))
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulk $newStatus'),
        content: Text(
          'Are you sure you want to change the status of ${selectedIds.length} selected student(s) to "$newStatus"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'Dropped'
                  ? Colors.red
                  : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(newStatus.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(studentMutationProvider.notifier)
            .bulkChangeStatus(selectedStudents, newStatus);
        if (context.mounted) {
          ref.read(studentSelectedIdsProvider.notifier).state = [];
          ref.read(studentMultiSelectProvider.notifier).state = false;
          showSuccessDialog(
            context,
            message: 'Students successfully updated to $newStatus.',
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          showErrorDialog(context, 'Error', errMsg);
        }
      }
    }
  }
}
