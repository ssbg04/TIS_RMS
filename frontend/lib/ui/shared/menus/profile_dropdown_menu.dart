import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../dialogs/logout_dialog.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/auth_provider.dart';

class ProfileDropdownMenu extends ConsumerWidget {
  final UserModel? user;
  final VoidCallback? onRefresh;

  const ProfileDropdownMenu({super.key, required this.user, this.onRefresh});

  void _showMenu(
    BuildContext context,
    WidgetRef ref,
    String initials,
    String fullName,
    String role,
    String email,
    String phone,
  ) async {
    // 1. Await background refresh so the menu opens with the latest data
    await ref.read(authProvider.notifier).refreshUser();

    // Get the latest data after refresh
    final updatedUser = ref.read(authProvider).value;
    final dispName = updatedUser != null
        ? '${updatedUser.firstName} ${updatedUser.lastName}'
        : fullName;
    final dispRole = updatedUser?.role.toUpperCase() ?? role;
    final dispEmail = updatedUser?.email ?? email;
    final dispPhone = updatedUser?.phone ?? phone;

    // 2. Find render box positions
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          Offset(0, button.size.height + 8),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(const Offset(0, 8)),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    // Cache notifiers before awaiting to avoid 'ref' invalidation errors if unmounted
    final activeTabNotifier = ref.read(activeTabProvider.notifier);
    // Capture the navigator BEFORE the async gap so it remains valid after the
    // popup menu closes (context may be stale after await).
    final navigator = Navigator.of(context, rootNavigator: true);

    final String? selectedValue = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        // 1. Header Profile Info (Disabled)
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dispName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dispRole,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                // --- SUBTLY READABLE CONTACT INFO ---
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dispEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dispPhone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // -------------------------------------
                const SizedBox(height: 12),
                const Divider(),
              ],
            ),
          ),
        ),

        // 2. Settings Option
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: const [
              Icon(Icons.settings_outlined, color: Colors.black87, size: 20),
              SizedBox(width: 12),
              Text('Settings', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        // 3. Logout Option
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selectedValue == null) return;

    if (selectedValue == 'settings') {
      activeTabNotifier.setTab('Settings');
    } else if (selectedValue == 'logout') {
      // Use the pre-captured navigator's context so the dialog always has a
      // valid, mounted context — even after the popup menu has been disposed.
      showLogoutConfirmationDialog(navigator.context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extract initials
    final authState = ref.watch(authProvider);
    final user = authState.value;

    final String initials =
        user != null && user!.firstName.isNotEmpty && user!.lastName.isNotEmpty
        ? '${user!.firstName[0]}${user!.lastName[0]}'.toUpperCase()
        : 'SA';

    final String fullName = user != null
        ? '${user!.firstName} ${user!.lastName}'
        : 'Super Admin';
    final String role = user?.role.toUpperCase() ?? 'ADMIN';

    // Data fallbacks
    final String email = user?.email ?? 'admin@tis-rms.edu.ph';
    final String phone = user?.phone ?? '+63 900 000 0000';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            _showMenu(context, ref, initials, fullName, role, email, phone),
        child: CircleAvatar(
          backgroundColor: AppColors.primaryGreen,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
