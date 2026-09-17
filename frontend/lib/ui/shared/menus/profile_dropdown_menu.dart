import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../dialogs/logout_dialog.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/auth_provider.dart';

class ProfileDropdownMenu extends ConsumerStatefulWidget {
  final UserModel? user;
  final VoidCallback? onRefresh;

  const ProfileDropdownMenu({super.key, required this.user, this.onRefresh});

  @override
  ConsumerState<ProfileDropdownMenu> createState() =>
      _ProfileDropdownMenuState();
}

class _ProfileDropdownMenuState extends ConsumerState<ProfileDropdownMenu> {
  bool _isMenuOpen = false;

  Future<void> _showMenu(
    BuildContext context,
    String initials,
    String fullName,
    String role,
    String email,
    String phone,
  ) async {
    if (_isMenuOpen) return;
    _isMenuOpen = true;

    // Trigger background refresh without blocking menu opening
    ref.read(authProvider.notifier).refreshUser();

    final currentUser = ref.read(authProvider).value ?? widget.user;
    final dispName = currentUser != null
        ? '${currentUser.firstName} ${currentUser.lastName}'
        : fullName;
    final dispRole = currentUser?.role.toUpperCase() ?? role;
    final dispEmail = currentUser?.email ?? email;
    final dispPhone = currentUser?.phone ?? phone;

    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;

    if (button == null || overlay == null) {
      _isMenuOpen = false;
      return;
    }

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

    final activeTabNotifier = ref.read(activeTabProvider.notifier);

    try {
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dispEmail,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              dispPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

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
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
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

      if (selectedValue == null || !mounted) return;

      if (selectedValue == 'settings') {
        activeTabNotifier.setTab('Settings');
      } else if (selectedValue == 'logout' && context.mounted) {
        showLogoutConfirmationDialog(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isMenuOpen = false);
      } else {
        _isMenuOpen = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value ?? widget.user;

    final String initials =
        user != null && user.firstName.isNotEmpty && user.lastName.isNotEmpty
            ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
            : 'SA';

    final String fullName = user != null
        ? '${user.firstName} ${user.lastName}'
        : 'Super Admin';
    final String role = user?.role.toUpperCase() ?? 'ADMIN';

    final String email = user?.email ?? 'admin@tis-rms.edu.ph';
    final String phone = user?.phone ?? '+63 900 000 0000';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showMenu(context, initials, fullName, role, email, phone),
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
