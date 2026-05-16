import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/auth_provider.dart';
import 'requirements_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final String? userRole;
  const SettingsScreen({super.key, this.userRole});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Profile controllers
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Password controllers
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isInitialized = false;
  bool _isProfileLoading = false;
  bool _isPasswordLoading = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _extCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateProfile() async {
    setState(() => _isProfileLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        extension: _extCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnack('All password fields are required.', isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnack('New passwords do not match.', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('New password must be at least 6 characters.', isError: true);
      return;
    }

    setState(() => _isPasswordLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.changePassword(
        currentPassword: current,
        newPassword: newPass,
        confirmPassword: confirm,
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      _showSnack('Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (user) {
            if (!_isInitialized) {
              Future.microtask(() {
                if (mounted && !_isInitialized) {
                  _firstNameCtrl.text = user.firstName;
                  _middleNameCtrl.text = user.middleName ?? '';
                  _lastNameCtrl.text = user.lastName;
                  _extCtrl.text = user.extension ?? '';
                  _phoneCtrl.text = user.phone ?? '';
                  _emailCtrl.text = user.email ?? '';
                  setState(() => _isInitialized = true);
                }
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text('Account Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: AppSizes.p8),
                      const Text('Manage your profile information and security settings.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSizes.p32),

                      // ── Profile Card ──────────────────────────────────────
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.primaryGreen,
                                child: Icon(Icons.person, size: 30, color: Colors.white),
                              ),
                              const SizedBox(width: AppSizes.p16),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Role: ${user.role.toUpperCase().replaceAll('_', ' ')}',
                                    style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                              ]),
                            ]),
                            const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.p24), child: Divider()),

                            LayoutBuilder(builder: (ctx, constraints) {
                              final wide = constraints.maxWidth > 500;
                              final spacing = AppSizes.p16;
                              if (wide) {
                                return Column(children: [
                                  Row(children: [
                                    Expanded(child: CustomTextField(hintText: 'First Name', prefixIcon: Icons.badge_outlined, controller: _firstNameCtrl)),
                                    SizedBox(width: spacing),
                                    Expanded(child: CustomTextField(hintText: 'Middle Name', prefixIcon: Icons.badge_outlined, controller: _middleNameCtrl)),
                                  ]),
                                  SizedBox(height: spacing),
                                  Row(children: [
                                    Expanded(flex: 3, child: CustomTextField(hintText: 'Last Name', prefixIcon: Icons.badge_outlined, controller: _lastNameCtrl)),
                                    SizedBox(width: spacing),
                                    Expanded(child: CustomTextField(hintText: 'Ext. (Jr)', prefixIcon: Icons.text_format, controller: _extCtrl)),
                                  ]),
                                  SizedBox(height: spacing),
                                  Row(children: [
                                    Expanded(child: CustomTextField(hintText: 'Phone Number', prefixIcon: Icons.phone_outlined, controller: _phoneCtrl)),
                                    SizedBox(width: spacing),
                                    Expanded(child: CustomTextField(hintText: 'Email Address', prefixIcon: Icons.email_outlined, controller: _emailCtrl)),
                                  ]),
                                ]);
                              } else {
                                return Column(children: [
                                  CustomTextField(hintText: 'First Name', prefixIcon: Icons.badge_outlined, controller: _firstNameCtrl),
                                  SizedBox(height: spacing),
                                  CustomTextField(hintText: 'Middle Name', prefixIcon: Icons.badge_outlined, controller: _middleNameCtrl),
                                  SizedBox(height: spacing),
                                  CustomTextField(hintText: 'Last Name', prefixIcon: Icons.badge_outlined, controller: _lastNameCtrl),
                                  SizedBox(height: spacing),
                                  CustomTextField(hintText: 'Ext. (Jr)', prefixIcon: Icons.text_format, controller: _extCtrl),
                                  SizedBox(height: spacing),
                                  CustomTextField(hintText: 'Phone Number', prefixIcon: Icons.phone_outlined, controller: _phoneCtrl),
                                  SizedBox(height: spacing),
                                  CustomTextField(hintText: 'Email Address', prefixIcon: Icons.email_outlined, controller: _emailCtrl),
                                ]);
                              }
                            }),
                            const SizedBox(height: AppSizes.p32),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 200,
                                child: PrimaryButton(label: 'SAVE CHANGES', isLoading: _isProfileLoading, onPressed: _handleUpdateProfile),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSizes.p24),

                      // ── Document Requirements Settings (Super Admin Only) ──
                      if (widget.userRole == 'super_admin') ...[
                        _buildCard(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RequirementsSettingsScreen(),
                                ),
                              );
                            },
                            child: const Row(children: [
                              Icon(Icons.folder_copy_outlined, color: AppColors.primaryGreen),
                              SizedBox(width: AppSizes.p8),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Document Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('Configure required documents for JHS and SHS', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              )),
                              Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            ]),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),
                      ],

                      // ── Change Password Card ──────────────────────────────
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.lock_outline, color: AppColors.textPrimary),
                              SizedBox(width: AppSizes.p8),
                              Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 6),
                            const Text('Enter your current password before setting a new one.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const Divider(height: 28),

                            CustomTextField(
                              hintText: 'Current Password',
                              prefixIcon: Icons.lock_open_outlined,
                              controller: _currentPassCtrl,
                              isPassword: true,
                              obscureText: _obscureCurrent,
                              onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            CustomTextField(
                              hintText: 'New Password',
                              prefixIcon: Icons.lock_outline,
                              controller: _newPassCtrl,
                              isPassword: true,
                              obscureText: _obscureNew,
                              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            CustomTextField(
                              hintText: 'Confirm New Password',
                              prefixIcon: Icons.lock_outline,
                              controller: _confirmPassCtrl,
                              isPassword: true,
                              obscureText: _obscureConfirm,
                              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            const SizedBox(height: AppSizes.p24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 200,
                                child: PrimaryButton(label: 'UPDATE PASSWORD', isLoading: _isPasswordLoading, onPressed: _handleChangePassword),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSizes.p48),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}