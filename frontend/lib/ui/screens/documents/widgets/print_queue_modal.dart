import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/repositories/document_repository.dart'
    show PrintQueueItem;
import '../../../shared/buttons/primary_button.dart';
import '../../../providers/document_provider.dart';

class PrintQueueModal extends ConsumerStatefulWidget {
  const PrintQueueModal({super.key});

  @override
  ConsumerState<PrintQueueModal> createState() => _PrintQueueModalState();
}

class _PrintQueueModalState extends ConsumerState<PrintQueueModal> {
  bool _isPrinting = false;

  Future<void> _handlePrintAll(List<PrintQueueItem> items) async {
    if (items.isEmpty) return;
    setState(() => _isPrinting = true);

    // Simulate sending batch to printer (replace with real print service when available)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isPrinting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Batch sent to printer successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _removeItem(int queueId) async {
    try {
      await ref
          .read(printQueueMutationProvider.notifier)
          .removeFromQueue(queueId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to remove: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _clearAll() async {
    try {
      await ref.read(printQueueMutationProvider.notifier).clearQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to clear queue: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(printQueueProvider);

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print,
                        color: AppColors.primaryGreen, size: 22),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Print Queue',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text('Documents staged for batch printing',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: AppSizes.p32),

              // ── Queue Content ──
              Expanded(
                child: queueAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGreen)),
                  error: (e, _) => _buildErrorState(e.toString()),
                  data: (items) => items.isEmpty
                      ? _buildEmptyState()
                      : _buildQueueList(items),
                ),
              ),

              // ── Footer ──
              queueAsync.maybeWhen(
                data: (items) => items.isNotEmpty
                    ? _buildFooter(items)
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList(List<PrintQueueItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final isPdf = item.fileName.toLowerCase().endsWith('.pdf');
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isPdf ? Colors.red : Colors.blue)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image,
              color: isPdf ? Colors.redAccent : Colors.blueAccent,
              size: 20,
            ),
          ),
          title: Text(
            item.fileName,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.studentName != null)
                Text(item.studentName!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              if (item.documentType != null)
                Text(item.documentType!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusChip(item.status),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 20),
                tooltip: 'Remove from Queue',
                onPressed: () => _removeItem(item.queueId),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Verified':
        color = AppColors.success;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildFooter(List<PrintQueueItem> items) {
    return Column(
      children: [
        const Divider(height: AppSizes.p32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${items.length} document${items.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const Text('Ready for batch print',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _isPrinting ? null : _clearAll,
                  child: const Text('CLEAR ALL',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppSizes.p8),
                SizedBox(
                  width: 130,
                  child: PrimaryButton(
                    label: 'PRINT ALL',
                    isLoading: _isPrinting,
                    onPressed: () => _handlePrintAll(items),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print_disabled, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: AppSizes.p16),
          const Text('Queue is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSizes.p8),
          const Text(
            'Open a document\'s menu and select\n"Add to Print Queue" to batch print.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Failed to load print queue',
              style: TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(printQueueProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}