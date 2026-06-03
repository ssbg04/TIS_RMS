import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../../core/utils/validators.dart';
import 'requirements_settings_screen.dart';
import 'teacher_management_screen.dart';

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

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Password controllers
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  // Single toggle for all password fields
  bool _obscurePasswords = true;

  int? _lastUserId;
  bool _isProfileLoading = false;
  bool _isPasswordLoading = false;
  ProviderSubscription<String>? _tabListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next == 'Settings' && previous != 'Settings') {
          ref.invalidate(profileProvider);
          _lastUserId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
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
    if (!_profileFormKey.currentState!.validate()) return;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        final dialogFormKey = GlobalKey<FormState>();
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Confirm Changes'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please enter your current password to save profile changes.', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    CustomTextField(
                      hintText: 'Current Password',
                      prefixIcon: Icons.lock_outline,
                      controller: ctrl,
                      isPassword: true,
                      obscureText: obscure,
                      onToggleVisibility: () => setState(() => obscure = !obscure),
                      validator: (v) => AppValidators.validateRequired(v, 'Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      Navigator.pop(ctx, ctrl.text);
                    }
                  },
                  child: const Text('CONFIRM', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );

    if (password == null || password.isEmpty) return;

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
        currentPassword: password,
      );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      showSuccessDialog(context, message: 'Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Update Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (newPass != confirm) {
      showErrorDialog(context, 'Password Mismatch', 'New passwords do not match.');
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
      showSuccessDialog(context, message: 'Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Change Password Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
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
            if (_lastUserId != user.id) {
              Future.microtask(() {
                if (mounted) {
                  _firstNameCtrl.text = user.firstName;
                  _middleNameCtrl.text = user.middleName ?? '';
                  _lastNameCtrl.text = user.lastName;
                  _extCtrl.text = user.extension ?? '';
                  _phoneCtrl.text = user.phone ?? '';
                  _emailCtrl.text = user.email ?? '';
                  setState(() => _lastUserId = user.id);
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
                        child: Form(
                          key: _profileFormKey,
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

                              Builder(builder: (ctx) {
                                const spacing = AppSizes.p16;
                                return Column(children: [
                                  CustomTextField(
                                    hintText: 'First Name', 
                                    prefixIcon: Icons.badge_outlined, 
                                    controller: _firstNameCtrl,
                                    validator: (v) => AppValidators.validateRequired(v, 'First Name'),
                                  ),
                                  const SizedBox(height: spacing),
                                  CustomTextField(
                                    hintText: 'Middle Name', 
                                    prefixIcon: Icons.badge_outlined, 
                                    controller: _middleNameCtrl,
                                  ),
                                  const SizedBox(height: spacing),
                                  CustomTextField(
                                    hintText: 'Last Name', 
                                    prefixIcon: Icons.badge_outlined, 
                                    controller: _lastNameCtrl,
                                    validator: (v) => AppValidators.validateRequired(v, 'Last Name'),
                                  ),
                                  const SizedBox(height: spacing),
                                  CustomTextField(
                                    hintText: 'Ext. (Jr)', 
                                    prefixIcon: Icons.text_format, 
                                    controller: _extCtrl,
                                  ),
                                  const SizedBox(height: spacing),
                                  CustomTextField(
                                    hintText: 'Phone Number (Starts with 09)', 
                                    prefixIcon: Icons.phone_outlined, 
                                    controller: _phoneCtrl,
                                    validator: AppValidators.validatePhone,
                                  ),
                                  const SizedBox(height: spacing),
                                  CustomTextField(
                                    hintText: 'Email Address', 
                                    prefixIcon: Icons.email_outlined, 
                                    controller: _emailCtrl,
                                    validator: AppValidators.validateEmail,
                                  ),
                                ]);
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
                      ),

                      const SizedBox(height: AppSizes.p24),

                      // ── Document Requirements Settings (Super Admin Only) ──
                      if (widget.userRole == 'admin') ...[
                        _buildCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RequirementsSettingsScreen(),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.folder_copy, color: AppColors.primaryGreen),
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
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: AppColors.primaryGreen),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Define which documents are required for enrollment per grade level '
                                          '(e.g., Form 137, Birth Certificate, Good Moral). Students with missing '
                                          'required documents will appear in the Missing Docs dashboard tile.',
                                          style: TextStyle(fontSize: 12, color: AppColors.primaryGreen),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),
                        _buildCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const TeacherManagementScreen(),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.people_alt, color: AppColors.primaryGreen),
                                  SizedBox(width: AppSizes.p8),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Teachers & Academic Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text('Manage teachers, academic years, grade levels, and sections', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  )),
                                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                ]),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Set up academic years, grade levels, and sections. Assign teachers to '
                                          'their sections so they can view and manage their students\' records. '
                                          'Changes here affect enrollment options across the system.',
                                          style: TextStyle(fontSize: 12, color: Colors.blue),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),
                      ],

                      // ── Change Password Card ──────────────────────────────
                      _buildCard(
                        child: Form(
                          key: _passwordFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_outline, color: AppColors.textPrimary),
                                  const SizedBox(width: AppSizes.p8),
                                  const Expanded(child: Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
                                    icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility, size: 18),
                                    label: Text(_obscurePasswords ? 'Show Passwords' : 'Hide Passwords'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text('Enter your current password before setting a new one.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const Divider(height: 28),

                              CustomTextField(
                                hintText: 'Current Password',
                                prefixIcon: Icons.lock_open_outlined,
                                controller: _currentPassCtrl,
                                isPassword: true,
                                obscureText: _obscurePasswords,
                                validator: (v) => AppValidators.validateRequired(v, 'Current Password'),
                              ),
                              const SizedBox(height: AppSizes.p12),
                              CustomTextField(
                                hintText: 'New Password',
                                prefixIcon: Icons.lock_outline,
                                controller: _newPassCtrl,
                                isPassword: true,
                                obscureText: _obscurePasswords,
                                validator: AppValidators.validatePasswordComplexity,
                              ),
                              const SizedBox(height: AppSizes.p12),
                              CustomTextField(
                                hintText: 'Confirm New Password',
                                prefixIcon: Icons.lock_outline,
                                controller: _confirmPassCtrl,
                                isPassword: true,
                                obscureText: _obscurePasswords,
                                validator: (v) => AppValidators.validateRequired(v, 'Confirm Password'),
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