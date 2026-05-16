import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/cards/stat_card.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/dashboard_models.dart';
import '../../../domain/entities/user_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _handleRefresh() async {
    ref.invalidate(dashboardDataProvider);
    // Wait for the new data to finish loading
    await ref.read(dashboardDataProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('$error', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _handleRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(user),
                  const SizedBox(height: 32),
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back, ${user?.firstName ?? 'Admin'}. Here is what is happening today.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  _buildStatGrid(data.stats),
                  const SizedBox(height: 32),
                  const Text(
                    'Pending Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPendingTasksList(data.pendingTasks),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP BAR MODULE
  // ==========================================
  Widget _buildTopBar(UserModel? user) {
    final String initials = user != null && user.firstName.isNotEmpty && user.lastName.isNotEmpty 
        ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase() 
        : 'SA';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Dummy Search Bar (Expands on Desktop, fixed width on Mobile)
        Expanded(
          flex: 1,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search students by LRN or Name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Icons
        Row(
          children: [
            // Notification with Red Badge
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 28),
                  onPressed: () {
                    // TODO: Open Notification Modal
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // User Profile Mockup
            CircleAvatar(
              backgroundColor: const Color(0xFF1C8248),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // RESPONSIVE STAT GRID
  // ==========================================
  Widget _buildStatGrid(DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint logic: >= 800px is Windows (4 columns), < 800px is Android (2 columns)
        int crossAxisCount = constraints.maxWidth >= 800 ? 4 : 2;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            // THE FIX: This forces the card to always be exactly 110 pixels tall,
            // completely ignoring the width and preventing vertical squishing!
            mainAxisExtent: 110, 
          ),
          children: [
            StatCard(title: 'Total Students', value: stats.totalStudents.toString(), icon: Icons.school),
            StatCard(title: 'Pending Docs', value: stats.pendingVerifications.toString(), icon: Icons.folder_shared, iconColor: Colors.orange),
            StatCard(title: 'Print Queue', value: stats.printQueueCount.toString(), icon: Icons.print, iconColor: Colors.blue),
            StatCard(title: 'Active Users', value: stats.activeUsers.toString(), icon: Icons.badge), // Super Admin specific stat
          ],
        );
      },
    );
  }

  // ==========================================
  // PENDING TASKS LIST
  // ==========================================
  Widget _buildPendingTasksList(List<PendingTask> tasks) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('No pending tasks at the moment.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.folder_shared, color: Colors.orange),
            ),
            title: Text('Verify ${task.fileName} for ${task.firstName} ${task.lastName}', style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Submitted on ${task.createdAt.split('T').first}'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              // TODO: Navigate to specific task
            },
          );
        },
      ),
    );
  }
}