import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../providers/archives_provider.dart';
import '../../../domain/entities/archive_model.dart';

class ArchivesScreen extends ConsumerStatefulWidget {
  final String userRole;

  const ArchivesScreen({super.key, required this.userRole});

  @override
  ConsumerState<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends ConsumerState<ArchivesScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(archiveQueryProvider.notifier).setSearch(query);
    });
  }

  void _handleRestore(ArchiveModel archive) async {
    try {
      await ref.read(archiveMutationProvider.notifier).restoreArchive(archive.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${archive.name} restored to active records.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _handlePermanentDelete(ArchiveModel archive) {
    // RBAC Check just in case
    if (widget.userRole != 'super_admin' && widget.userRole != 'admin') return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Permanent Purge', style: TextStyle(color: AppColors.error)),
        content: Text('Are you sure you want to permanently delete ${archive.name}? This action cannot be undone and will purge all connected documents.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(archiveMutationProvider.notifier).purgeArchive(archive.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${archive.name} permanently deleted.'), backgroundColor: AppColors.error),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to purge: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('PURGE RECORD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archiveState = ref.watch(archivePageProvider);
    final query = ref.watch(archiveQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderControls(context, query),
              const SizedBox(height: AppSizes.p24),
              
              // ==========================================
              // RETENTION RULES BANNER
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.p16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: Text(
                        'Retention Engine Rules: Graduated (5 Yrs) • Transferred Out (5 Yrs) • Dropped (3 Yrs). Records marked in red have exceeded their retention period and are ready for permanent purging.',
                        style: TextStyle(color: Color(0xFF0D47A1), fontSize: 13), // Material Blue 900
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p24),

              // ==========================================
              // RESPONSIVE DATA VIEW
              // ==========================================
              Expanded(
                child: archiveState.when(
                  data: (pageData) {
                    if (pageData.archives.isEmpty) {
                      return const Center(child: Text('No archived records found.'));
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 800) {
                          return _buildDesktopTable(pageData.archives);
                        } else {
                          return _buildMobileCardList(pageData.archives);
                        }
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
                ),
              ),
              
              if (archiveState.hasValue && archiveState.value!.totalPages > 1)
                _buildPaginationControls(archiveState.value!.totalPages, query.page),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER CONTROLS
  // ==========================================
  Widget _buildHeaderControls(BuildContext context, ArchiveQueryParams query) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth > 800;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Archives',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSizes.p16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    hintText: 'Search archived records...',
                    prefixIcon: Icons.search,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: AppSizes.p16),
                if (isDesktop) ...[
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: query.status,
                          isExpanded: true,
                          items: ['All Statuses', 'Graduated', 'Transferred Out', 'Dropped']
                              .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(archiveQueryProvider.notifier).setStatus(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // DESKTOP TABLE
  // ==========================================
  Widget _buildDesktopTable(List<ArchiveModel> archives) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryGreen.withOpacity(0.05)),
            columns: const [
              DataColumn(label: Text('LRN', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Final Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Date Archived', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Retention Expiry', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: archives.map((archive) {
              return DataRow(cells: [
                DataCell(Text(archive.lrn, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text(archive.name)),
                DataCell(_buildStatusChip(archive.status)),
                DataCell(Text(archive.archivedDate, style: const TextStyle(color: AppColors.textSecondary))),
                DataCell(Text(
                  archive.expiryDate,
                  style: TextStyle(color: archive.isExpired ? AppColors.error : AppColors.primaryGreen, fontWeight: archive.isExpired ? FontWeight.bold : FontWeight.normal),
                )),
                DataCell(_buildActionButtons(archive)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE CARD LIST
  // ==========================================
  Widget _buildMobileCardList(List<ArchiveModel> archives) {
    return ListView.separated(
      itemCount: archives.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final archive = archives[index];

        return Container(
          padding: const EdgeInsets.all(AppSizes.p16),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: archive.isExpired ? Border.all(color: AppColors.error.withOpacity(0.3)) : null,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(archive.lrn, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  _buildStatusChip(archive.status),
                ],
              ),
              const SizedBox(height: AppSizes.p8),
              Text(archive.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.p12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archived: ${archive.archivedDate}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(
                        'Expires: ${archive.expiryDate}', 
                        style: TextStyle(color: archive.isExpired ? AppColors.error : AppColors.primaryGreen, fontSize: 12, fontWeight: archive.isExpired ? FontWeight.bold : FontWeight.normal),
                      ),
                    ],
                  ),
                  _buildActionButtons(archive),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // PAGINATION CONTROLS
  // ==========================================
  Widget _buildPaginationControls(int totalPages, int currentPage) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.p16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => ref.read(archiveQueryProvider.notifier).setPage(currentPage - 1)
                : null,
          ),
          Text('Page $currentPage of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => ref.read(archiveQueryProvider.notifier).setPage(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER COMPONENTS
  // ==========================================
  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildActionButtons(ArchiveModel archive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.restore, color: AppColors.primaryGreen),
          tooltip: 'Restore to Active',
          onPressed: () => _handleRestore(archive),
        ),
        if (widget.userRole == 'super_admin' || widget.userRole == 'admin') // RBAC Protection
          IconButton(
            icon: Icon(Icons.delete_forever, color: archive.isExpired ? AppColors.error : Colors.grey.shade400),
            tooltip: 'Permanently Purge',
            onPressed: () => _handlePermanentDelete(archive),
          ),
      ],
    );
  }
}