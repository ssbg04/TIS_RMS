import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/repositories/document_repository.dart'
    show PrintQueueItem;
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
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

    try {
      await ref.read(printQueueMutationProvider.notifier).executePrint();

      if (!mounted) return;
      setState(() => _isPrinting = false);
      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        title: 'Sent to Printer',
        message: 'Batch of ${items.length} document${items.length > 1 ? "s" : ""} logged and sent to printer successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      showErrorDialog(
        context,
        'Print Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _removeItem(int queueId) async {
    try {
      await ref
          .read(printQueueMutationProvider.notifier)
          .removeFromQueue(queueId);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Remove Failed',
        e.toString().replaceFirst('Exception: ', ''),
        buttonLabel: 'OK',
      );
    }
  }

  Future<void> _clearAll() async {
    try {
      await ref.read(printQueueMutationProvider.notifier).clearQueue();
      if (!mounted) return;
      showSuccessDialog(
        context,
        title: 'List Cleared',
        message: 'The print list has been cleared.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Clear Failed',
        e.toString().replaceFirst('Exception: ', ''),
        buttonLabel: 'OK',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(printQueueProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.85 : 620),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : AppSizes.p24),
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
                        Text('Print List',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text('Staged documents. Note: This is only a list of documents to be printed or requested.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic)),
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
                    ? _buildFooter(items, isMobile)
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
      separatorBuilder: (context, index) =>
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
                tooltip: 'Remove from List',
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
      case 'Completed':
        color = AppColors.success;
        break;
      case 'Archived':
        color = Colors.blue;
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


  Widget _buildFooter(List<PrintQueueItem> items, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSizes.p32),
        if (isMobile) ...[
          // Mobile layout: Stacked info and buttons
          Text('${items.length} document${items.length > 1 ? 's' : ''}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Text('Ready for batch print',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isPrinting ? null : _clearAll,
                  child: const Text('CLEAR ALL',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'PRINT',
                  isLoading: _isPrinting,
                  onPressed: () => _handlePrintAll(items),
                ),
              ),
            ],
          ),
        ] else ...[
          // Desktop layout: Horizontal row
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
                      label: 'PRINT',
                      isLoading: _isPrinting,
                      onPressed: () => _handlePrintAll(items),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
          const Text('List is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSizes.p8),
          const Text(
            'Open a document\'s menu and select\n"Add to Print List" to batch print.',
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
          const Text('Failed to load print list',
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