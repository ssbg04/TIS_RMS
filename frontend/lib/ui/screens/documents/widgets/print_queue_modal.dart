import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/repositories/document_repository.dart'
    show PrintQueueItem, PrintHistoryItem;
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../providers/document_provider.dart';
import '../../../../core/utils/file_icon_helper.dart';

class PrintQueueModal extends ConsumerStatefulWidget {
  const PrintQueueModal({super.key});

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;
        final size = MediaQuery.of(modalContext).size;
        final isSmall = size.width < 600;

        return Dialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 32,
            vertical: isSmall ? 8 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: isSmall ? size.height * 0.96 : size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.print_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Print List',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Staged documents for batch printing and pickup.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
                const Flexible(
                  child: SingleChildScrollView(
                    child: PrintQueueModal(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PrintQueueModal> createState() => _PrintQueueModalState();
}

class _PrintQueueModalState extends ConsumerState<PrintQueueModal> {
  bool _isPrinting = false;
  int _selectedTab = 0; // 0 = Print List, 1 = History
  bool _showPickupNotify = false;
  final TextEditingController _studentEmailController = TextEditingController();
  final TextEditingController _pickupNoteController = TextEditingController();
  final Map<String, TextEditingController> _multiEmailControllers = {};
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _studentEmailController.dispose();
    _pickupNoteController.dispose();
    for (final c in _multiEmailControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handlePrintAll(List<PrintQueueItem> items) async {
    if (items.isEmpty) return;
    var currentItems = List<PrintQueueItem>.from(items);

    final excelItems = currentItems.where((item) {
      final fname = item.fileName.toLowerCase();
      return fname.endsWith('.xlsx') ||
          fname.endsWith('.xls') ||
          fname.endsWith('.csv');
    }).toList();

    if (excelItems.isNotEmpty) {
      if (excelItems.length == currentItems.length) {
        showErrorDialog(
          context,
          'Cannot Print Spreadsheets',
          'The print list only contains spreadsheet files (.xlsx, .xls, .csv). Spreadsheets cannot be printed directly. Please convert them to PDF or print PDF/image documents.',
        );
        return;
      }

      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Spreadsheet Files Skipped'),
            ],
          ),
          content: Text(
            'The print list contains ${excelItems.length} spreadsheet file(s) (.xlsx/.xls/.csv) which cannot be printed directly.\n\nOnly PDF and image files will be printed. Would you like to proceed with printing the remaining files?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
      currentItems = currentItems.where((item) => !excelItems.contains(item)).toList();
    }

    setState(() => _isPrinting = true);

    try {
      final docRepo = ref.read(documentRepositoryProvider);

      // Merge all documents into a single PDF via backend (Short bond size, 0 margins, 0 padding)
      final docIds = currentItems.map((item) => item.documentId).toList();
      final combinedBytes = await docRepo.mergePrintQueuePdf(documentIds: docIds);

      // Send to printer
      final result = await Printing.layoutPdf(
        onLayout: (format) async => Uint8List.fromList(combinedBytes),
        name: 'Batch_Print_${DateTime.now().millisecondsSinceEpoch}',
      );

      // If the user cancelled the print dialog, we might not want to clear the queue
      if (!result) {
        if (!mounted) return;
        setState(() => _isPrinting = false);
        return; // User cancelled print dialog
      }

      // Log history and clear queue in backend
      await ref.read(printQueueMutationProvider.notifier).executePrint();

      bool emailSent = false;
      int emailsSentCount = 0;
      if (_showPickupNotify) {
        final formattedPickup =
            '${_pickupDate.year}-${_pickupDate.month.toString().padLeft(2, '0')}-${_pickupDate.day.toString().padLeft(2, '0')}';
        final message = _pickupNoteController.text.trim().isNotEmpty
            ? _pickupNoteController.text.trim()
            : null;

        // Group items by student
        final Map<String, List<PrintQueueItem>> studentGroups = {};
        for (final it in currentItems) {
          final sName = (it.studentName != null && it.studentName!.trim().isNotEmpty)
              ? it.studentName!.trim()
              : 'Student';
          studentGroups.putIfAbsent(sName, () => []).add(it);
        }

        if (studentGroups.length <= 1 && _studentEmailController.text.trim().isNotEmpty) {
          try {
            final sName = studentGroups.keys.firstOrNull ?? 'Student';
            await docRepo.sendPickupNotification(
              email: _studentEmailController.text.trim(),
              studentName: sName,
              documentNames: currentItems.map((i) => i.fileName).toList(),
              pickupDate: formattedPickup,
              message: message,
            );
            emailSent = true;
            emailsSentCount = 1;
          } catch (mailErr) {
            debugPrint('Failed to send pickup email: $mailErr');
          }
        } else if (studentGroups.length > 1) {
          for (final entry in studentGroups.entries) {
            final targetEmail = _multiEmailControllers[entry.key]?.text.trim() ?? '';
            if (targetEmail.isNotEmpty) {
              try {
                await docRepo.sendPickupNotification(
                  email: targetEmail,
                  studentName: entry.key,
                  documentNames: entry.value.map((i) => i.fileName).toList(),
                  pickupDate: formattedPickup,
                  message: message,
                );
                emailSent = true;
                emailsSentCount++;
              } catch (mailErr) {
                debugPrint('Failed to send pickup email to ${entry.key}: $mailErr');
              }
            }
          }
        }
      }

      if (!mounted) return;
      setState(() => _isPrinting = false);
      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        title: 'Sent to Printer',
        message: emailSent
            ? 'Batch of ${currentItems.length} document${currentItems.length > 1 ? "s" : ""} sent to printer, and pickup email notification sent to $emailsSentCount recipient${emailsSentCount > 1 ? "s" : ""}!'
            : 'Batch of ${currentItems.length} document${currentItems.length > 1 ? "s" : ""} logged and sent to printer successfully!',
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
    final historyAsync = ref.watch(printHistoryProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildTabSelector(),
            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              // ── Queue Content ──
              queueAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen),
                  ),
                ),
                error: (e, _) => _buildErrorState(e.toString()),
                data: (items) => items.isEmpty
                    ? _buildEmptyState()
                    : _buildQueueList(items),
              ),

              // ── Footer ──
              queueAsync.maybeWhen(
                data: (items) => items.isNotEmpty
                    ? _buildFooter(items, isMobile)
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ] else ...[
              // ── History Content ──
              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen),
                  ),
                ),
                error: (e, _) => _buildErrorState(e.toString()),
                data: (items) => items.isEmpty
                    ? _buildEmptyHistoryState()
                    : _buildHistoryList(items),
              ),

              // ── History Footer ──
              historyAsync.maybeWhen(
                data: (items) => items.isNotEmpty
                    ? _buildHistoryFooter(items)
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? AppColors.darkSurfaceCard : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _selectedTab == 0
                      ? [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 4)]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Print List',
                  style: TextStyle(
                    fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                    color: _selectedTab == 0 ? AppColors.primaryGreen : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? AppColors.darkSurfaceCard : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _selectedTab == 1
                      ? [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 4)]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'History',
                  style: TextStyle(
                    fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                    color: _selectedTab == 1 ? AppColors.primaryGreen : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<PrintQueueItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final fileColor = FileIconHelper.getColor(item.fileName, docType: item.documentType);
        final fileIcon = FileIconHelper.getIcon(item.fileName, docType: item.documentType);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              fileIcon,
              color: fileColor,
              size: 20,
            ),
          ),
          title: Text(
            item.documentType != null && item.documentType!.isNotEmpty
                ? '${item.documentType} • ${item.fileName}'
                : item.fileName,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.studentName != null)
                Text(
                  item.studentLrn != null && item.studentLrn!.isNotEmpty
                      ? '${item.studentName} (LRN: ${item.studentLrn})'
                      : item.studentName!,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
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
      case 'Printed':
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPickupNotificationSection(items, isDark),
        Divider(height: AppSizes.p24, color: isDark ? AppColors.darkBorder : null),
        if (isMobile) ...[
          // Mobile layout: Stacked info and buttons
          Text('${items.length} document${items.length > 1 ? 's' : ''}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
          Text('Ready for batch print',
              style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isPrinting ? null : _clearAll,
                  child: Text('CLEAR ALL',
                      style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: _isPrinting ? 'PREPARING...' : 'PRINT',
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                  Text('Ready for batch print',
                      style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _isPrinting ? null : _clearAll,
                    child: Text('CLEAR ALL',
                        style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: AppSizes.p8),
                  if (!isMobile)
                    SizedBox(
                      width: 140,
                      child: PrimaryButton(
                        label: _isPrinting ? 'PREPARING...' : 'PRINT',
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

  Widget _buildPickupNotificationSection(
      List<PrintQueueItem> items, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _showPickupNotify = !_showPickupNotify;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _showPickupNotify
                        ? Icons.mark_email_read_rounded
                        : Icons.mail_outline_rounded,
                    size: 18,
                    color: _showPickupNotify
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notify Student for Pickup (Email)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _showPickupNotify
                            ? AppColors.primaryGreen
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Icon(
                    _showPickupNotify
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_showPickupNotify) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    // Group items by student
                    final Map<String, List<PrintQueueItem>> studentGroups = {};
                    for (final it in items) {
                      final sName = (it.studentName != null && it.studentName!.trim().isNotEmpty)
                          ? it.studentName!.trim()
                          : 'Student';
                      studentGroups.putIfAbsent(sName, () => []).add(it);
                    }

                    if (studentGroups.length > 1) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.group_outlined, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${studentGroups.length} different students in print list. Enter individual emails below so each receives only their own documents:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...studentGroups.entries.map((grp) {
                            final sName = grp.key;
                            final docCount = grp.value.length;
                            final ctrl = _multiEmailControllers.putIfAbsent(
                              sName,
                              () => TextEditingController(),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextFormField(
                                controller: ctrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: '$sName ($docCount document${docCount > 1 ? "s" : ""}) Email',
                                  hintText: 'e.g. guardian@gmail.com',
                                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            );
                          }),
                        ],
                      );
                    }

                    return TextFormField(
                      controller: _studentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Student / Guardian Email',
                        hintText: 'e.g. student@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _pickupDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 60)),
                            );
                            if (picked != null) {
                              setState(() => _pickupDate = picked);
                            }
                          },
                          icon:
                              const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            'Pickup Date: ${_pickupDate.year}-${_pickupDate.month.toString().padLeft(2, '0')}-${_pickupDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _pickupNoteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Office Note / Instructions (Optional)',
                      hintText: 'e.g. Please claim at Room 102 between 1-3 PM.',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<PrintHistoryItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final name = item.fileName ?? item.documentName;
        final fileColor = FileIconHelper.getColor(name, docType: item.documentType);
        final fileIcon = FileIconHelper.getIcon(name, docType: item.documentType);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              fileIcon,
              color: fileColor,
              size: 20,
            ),
          ),
          title: Text(
            item.documentType != null && item.documentType!.isNotEmpty
                ? '${item.documentType} • ${item.fileName ?? item.documentName}'
                : (item.fileName ?? item.documentName),
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.studentLrn != null && item.studentLrn!.isNotEmpty
                    ? '${item.studentName} (LRN: ${item.studentLrn})'
                    : item.studentName,
                style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                'Printed on ${_formatHistoryDate(item.printedAt)}',
                style: TextStyle(
                    fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
            ],
          ),
          trailing: _buildStatusChip('Printed'),
        );
      },
    );
  }

  Widget _buildEmptyHistoryState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off,
                size: 48, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No print history found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Documents you print will appear here in your history.',
                style: TextStyle(
                    fontSize: 12, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryFooter(List<PrintHistoryItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear Print History'),
                content: const Text(
                  'Are you sure you want to clear your print history? This will remove all past print records from your view and cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(printQueueMutationProvider.notifier).clearHistory();
            }
          },
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('Clear History'),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatHistoryDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print_disabled, size: 64, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300),
          const SizedBox(height: AppSizes.p16),
          Text('List is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: AppSizes.p8),
          Text(
            'Open a document\'s menu and select\n"Add to Print List" to batch print.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 13),
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