import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../../core/utils/validators.dart';
import 'requirements_settings_screen.dart';
import '../../shared/widgets/app_error_state.dart';
import 'package:dio/dio.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../providers/setup_provider.dart';
import '../../shared/dialogs/info_dialog.dart';
import '../../shared/modals/custom_modal.dart';
import 'teacher_management_screen.dart';
import '../../../domain/entities/setup_models.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/preferences_provider.dart';
import 'widgets/change_password_modal.dart';
import '../../../core/services/haptic_service.dart';
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = '';
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      String char = newValue.text[i];
      if (capitalizeNext && char.trim().isNotEmpty) {
        newText += char.toUpperCase();
        capitalizeNext = false;
      } else {
        newText += char;
      }
      
      if (char == ' ' || char == '-') {
        capitalizeNext = true;
      }
    }

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

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

  int? _lastUserId;
  bool _isProfileLoading = false;
  ProviderSubscription<String>? _tabListener;

  // Collapsible sections state
  bool _isProfileExpanded = false;
  bool _isAcademicYearExpanded = false;
  bool _isAutoEnrollExpanded = false;
  bool _isAppearanceExpanded = false;

  void _collapseAllSections() {
    _isProfileExpanded = false;
    _isAcademicYearExpanded = false;
    _isAutoEnrollExpanded = false;
    _isAppearanceExpanded = false;
  }

  void _refreshAllSettingsData() {
    ref.invalidate(academicYearsListProvider);
    ref.invalidate(sectionsListProvider);
    ref.invalidate(gradeLevelsListProvider);
    ref.invalidate(systemSettingsProvider);
    ref.invalidate(profileProvider);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAllSettingsData();
      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (previous == 'Settings' && next != 'Settings') {
          setState(() {
            _collapseAllSections();
          });
        }
        if (next == 'Settings') {
          _refreshAllSettingsData();
          if (previous != 'Settings') {
            setState(() {
              _collapseAllSections();
            });
            _firstNameCtrl.clear();
            _middleNameCtrl.clear();
            _lastNameCtrl.clear();
            _extCtrl.clear();
            _phoneCtrl.clear();
            _emailCtrl.clear();
            _profileFormKey.currentState?.reset();
            _lastUserId = null;
          }
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
    super.dispose();
  }

  bool _hasProfileChanges() {
    final user = ref.read(profileProvider).asData?.value;
    if (user == null) return false;
    
    return _firstNameCtrl.text.trim() != user.firstName ||
           _middleNameCtrl.text.trim() != (user.middleName ?? '') ||
           _lastNameCtrl.text.trim() != user.lastName ||
           _extCtrl.text.trim() != (user.extension ?? '') ||
           _phoneCtrl.text.trim() != (user.phone ?? '') ||
           _emailCtrl.text.trim() != (user.email ?? '');
  }

  void _revertProfileChanges() {
    final user = ref.read(profileProvider).asData?.value;
    if (user != null) {
      _firstNameCtrl.text = user.firstName;
      _middleNameCtrl.text = user.middleName ?? '';
      _lastNameCtrl.text = user.lastName;
      _extCtrl.text = user.extension ?? '';
      _phoneCtrl.text = user.phone ?? '';
      _emailCtrl.text = user.email ?? '';
    }
  }

  Future<bool> _promptToConfirmSave() async {
    final ctrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Changes'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type "CONFIRM" to save your profile changes.'),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'CONFIRM',
                  controller: ctrl,
                  validator: (v) {
                    if (v == null || v.trim().toUpperCase() != 'CONFIRM') {
                      return 'Please type CONFIRM';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _handleUpdateProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      _revertProfileChanges();
      return;
    }

    final isConfirmed = await _promptToConfirmSave();
    if (!isConfirmed) {
      _revertProfileChanges();
      return;
    }

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
      showSuccessDialog(context, message: 'Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Update Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
      _revertProfileChanges();
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }



  Future<void> _handleActivateAcademicYear(AcademicYearModel selectedYear) async {
    try {
      await ref.read(setupMutationProvider.notifier).updateAcademicYear(
            id: selectedYear.id,
            yearRange: selectedYear.yearRange,
            status: 'active',
            startDate: selectedYear.startDate,
            endDate: selectedYear.endDate,
          );
      ref.invalidate(academicYearsListProvider);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Academic Year ${selectedYear.yearRange} is now Active!',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Activation Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
      ref.invalidate(academicYearsListProvider);
    }
  }

  Future<void> _handleRunAutoGraduation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isNarrow =
            MediaQuery.of(ctx).size.width < 600 ||
            Theme.of(ctx).platform == TargetPlatform.android;
        return AlertDialog(
          title: const Text('Confirm Auto-Graduation'),
          content: const Text(
            'This will check the active academic year schedule and automatically graduate eligible Grade 10 and Grade 12 students if the schedule end date has been reached.\n\nDo you want to proceed?',
          ),
          actions: [
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('PROCEED'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('CANCEL'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('PROCEED'),
                  ),
                ],
              ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final res =
          await ref.read(setupMutationProvider.notifier).checkAutoGraduation();
      if (!context.mounted) return;
      final executed = res['executed'] == true;
      showInfoDialog(
        context,
        title:
            executed ? 'Auto-Graduation Completed' : 'Auto-Graduation Skipped',
        message:
            res['message']?.toString() ??
            res['reason']?.toString() ??
            'Check completed.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        'Check Failed',
        'Failed to run auto-graduation check: $e',
      );
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isNarrow =
            MediaQuery.of(ctx).size.width < 600 ||
            Theme.of(ctx).platform == TargetPlatform.android;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'To permanently delete your account, a verification link will be sent to your registered email address.\n\n'
            'The link will expire in 15 minutes. Once confirmed via email, your account cannot be recovered.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('SEND VERIFICATION EMAIL'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('CANCEL'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('SEND VERIFICATION EMAIL'),
                  ),
                ],
              ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final msg =
          await ref.read(authProvider.notifier).requestAccountDeletion();
      if (!context.mounted) return;
      showSuccessDialog(
        context,
        title: 'Verification Email Sent',
        message: msg,
        notes:
            'Please check your registered email inbox to permanently delete your account.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        'Request Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTabProvider, (previous, next) {
      if (next == 'Settings') {
        _refreshAllSettingsData();
      }
    });
    final profileAsync = ref.watch(profileProvider);

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        if (_hasProfileChanges()) {
          _handleUpdateProfile();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => AppErrorState.fromError(
            error: err,
            onRetry: () => ref.invalidate(profileProvider),
          ),
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

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSizes.p24, AppSizes.p32, AppSizes.p24, AppSizes.p32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Account Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),
                      Text(
                        'Manage your profile information and security settings.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p32),

                      // ── Profile Card (Collapsible) ──────────────────────────
                      _buildCollapsibleCard(
                        title: 'Profile Details',
                        isExpanded: _isProfileExpanded,
                        onToggle: () => setState(() => _isProfileExpanded = !_isProfileExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primaryGreen,
                                  child: Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${user.firstName} ${user.lastName}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Role: ${user.role.toUpperCase().replaceAll('_', ' ')}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? AppColors.darkTextSecondary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isProfileLoading)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p20),
                            Form(
                              key: _profileFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextField(
                                hintText: 'First Name',
                                prefixIcon: Icons.badge_outlined,
                                controller: _firstNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                                validator: (v) =>
                                    AppValidators.validateRequired(v, 'First Name'),
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Middle Name (Optional)',
                                prefixIcon: Icons.badge_outlined,
                                controller: _middleNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Last Name',
                                prefixIcon: Icons.badge_outlined,
                                controller: _lastNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                                validator: (v) =>
                                    AppValidators.validateRequired(v, 'Last Name'),
                              ),
                              const SizedBox(height: AppSizes.p16),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  const commonExts = ['Jr.', 'Sr.', 'II', 'III', 'IV'];
                                  if (textEditingValue.text.isEmpty) {
                                    return commonExts;
                                  }
                                  return commonExts.where(
                                    (ext) => ext
                                        .toLowerCase()
                                        .contains(textEditingValue.text.toLowerCase()),
                                  );
                                },
                                onSelected: (String selection) {
                                  _extCtrl.text = selection;
                                },
                                fieldViewBuilder: (
                                  context,
                                  controller,
                                  focusNode,
                                  onEditingComplete,
                                ) {
                                  controller.addListener(() {
                                    if (_extCtrl.text != controller.text) {
                                      _extCtrl.text = controller.text;
                                    }
                                  });
                                  if (controller.text.isEmpty &&
                                      _extCtrl.text.isNotEmpty) {
                                    controller.text = _extCtrl.text;
                                  }
                                  return CustomTextField(
                                    hintText: 'Suffix (Optional)',
                                    prefixIcon: Icons.text_format,
                                    controller: controller,
                                    focusNode: focusNode,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [UpperCaseTextFormatter()],
                                  );
                                },
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Phone Number (Starts with 09)',
                                prefixIcon: Icons.phone_outlined,
                                controller: _phoneCtrl,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                keyboardType: TextInputType.phone,
                                validator: AppValidators.validatePhone,
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Email Address',
                                prefixIcon: Icons.email_outlined,
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                validator: AppValidators.validateEmail,
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _emailCtrl,
                                builder: (context, value, child) {
                                  final text = value.text;
                                  if (!text.contains('@')) return const SizedBox.shrink();
                                  
                                  final parts = text.split('@');
                                  final domainPart = parts.length > 1 ? parts[1].toLowerCase() : '';
                                  
                                  final commonDomains = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'];
                                  final suggestions = commonDomains.where((d) => d.startsWith(domainPart) && d != domainPart).toList();
                                  
                                  if (suggestions.isEmpty) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Wrap(
                                      spacing: 8.0,
                                      children: suggestions.map((domain) => ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(domain, style: const TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          final newText = '${parts[0]}@$domain';
                                          _emailCtrl.text = newText;
                                          _emailCtrl.selection = TextSelection.collapsed(offset: newText.length);
                                        },
                                      )).toList(),
                                    ),
                                  );
                                }
                              ),
                              if (_hasProfileChanges()) ...[
                                const SizedBox(height: AppSizes.p16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _revertProfileChanges();
                                        });
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isProfileLoading ? null : _handleUpdateProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Save Profile'),
                                    ),
                                  ],
                                 ),
                               ],
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),

                      const SizedBox(height: AppSizes.p24),

                      // ── Document Requirements Settings (Super Admin Only) ──
                      if (widget.userRole == 'admin') ...[
                        _buildCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLarge,
                            ),
                            onTap: () => RequirementsModal.open(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.folder_copy,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Document Requirements',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Configure required documents for JHS and SHS',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppColors.primaryGreen,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Define which documents are required for enrollment per grade level '
                                          '(e.g., Form 137, Birth Certificate, Good Moral). Students with missing '
                                          'required documents will appear in the Missing Docs dashboard tile.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primaryGreen,
                                          ),
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
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLarge,
                            ),
                            onTap: () => TeacherManagementModal.open(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.people_alt,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Teachers & Academic Setup',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Manage teachers, academic years, grade levels, and sections',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Set up academic years, grade levels, and sections. Assign teachers to '
                                          'their sections so they can view and manage their students\' records. '
                                          'Changes here affect enrollment options across the system.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
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

                        // ── Active Academic Year Schedule & Auto-Graduation (Super Admin Only) ──
                        Consumer(
                          builder: (context, ref, _) {
                            final academicYearsAsync = ref.watch(academicYearsListProvider);
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return _buildCollapsibleCard(
                              title: 'Academic Year & Auto-Graduation',
                              isExpanded: _isAcademicYearExpanded,
                              onToggle: () => setState(() => _isAcademicYearExpanded = !_isAcademicYearExpanded),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.school_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 24,
                                      ),
                                      const SizedBox(width: AppSizes.p12),
                                      Expanded(
                                        child: Text(
                                          'Manage active academic year and auto-graduation schedule',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 20),
                                        tooltip: 'Refresh Academic Year',
                                        onPressed: () => ref.invalidate(academicYearsListProvider),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSizes.p16),
                                  academicYearsAsync.when(
                                    data: (years) {
                                      final isDark = Theme.of(context).brightness == Brightness.dark;
                                      final activeYear = years.cast<AcademicYearModel?>().firstWhere(
                                        (y) => y?.status == 'active',
                                        orElse: () => null,
                                      );
                                      if (years.isEmpty) {
                                        return const Text(
                                          'No academic years found. Configure an academic year in Teachers & Academic Setup first.',
                                          style: TextStyle(color: AppColors.warning, fontSize: 13),
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          DropdownButtonFormField<int>(
                                            key: ValueKey('ay_dropdown_${activeYear?.id}'),
                                            initialValue: activeYear?.id,
                                            decoration: InputDecoration(
                                              labelText: 'Academic Year',
                                              prefixIcon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                                              helperText: 'Select an academic year to activate it system-wide.',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            ),
                                            items: years.map((y) {
                                              final isActive = y.status == 'active';
                                              return DropdownMenuItem<int>(
                                                value: y.id,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      y.yearRange,
                                                      style: TextStyle(
                                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? AppColors.primaryGreen.withValues(alpha: 0.15)
                                                            : Colors.grey.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        isActive ? 'Active' : 'Inactive',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isActive ? AppColors.primaryGreen : Colors.grey,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (selectedId) async {
                                              if (selectedId == null || selectedId == activeYear?.id) return;
                                              final selectedYear = years.firstWhere((y) => y.id == selectedId);
                                              await _handleActivateAcademicYear(selectedYear);
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          if (activeYear == null) ...[
                                            const Text(
                                              'No active academic year found. Select an academic year from the dropdown above to activate it.',
                                              style: TextStyle(color: AppColors.warning, fontSize: 13),
                                            ),
                                          ] else ...[
                                            Wrap(
                                              spacing: 20,
                                              runSpacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primaryGreen),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Start: ${activeYear.startDate ?? "Not set"}',
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.event_available_outlined, size: 15, color: AppColors.primaryGreen),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'End: ${activeYear.endDate ?? "Not set"}',
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.blue.withValues(alpha: 0.08)
                                                    : Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.blue.withValues(alpha: 0.2)
                                                      : Colors.blue.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Auto-graduation runs sequentially (Grade 10 then Grade 12) once end date is reached. Requires both dates set.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? Colors.blue.shade300 : Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Builder(
                                              builder: (ctx) {
                                                final isNarrow =
                                                    MediaQuery.of(ctx).size.width < 650 ||
                                                        Theme.of(ctx).platform ==
                                                            TargetPlatform.android;
                                                if (isNarrow) {
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.stretch,
                                                    children: [
                                                      OutlinedButton.icon(
                                                        onPressed: () => showDialog(
                                                          context: context,
                                                          builder: (_) =>
                                                              _EditScheduleDatesDialog(
                                                            year: activeYear,
                                                          ),
                                                        ),
                                                        icon: const Icon(
                                                          Icons.date_range,
                                                        ),
                                                        label: const Text(
                                                          'Edit Schedule Dates',
                                                        ),
                                                        style:
                                                            OutlinedButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                          side: const BorderSide(
                                                            color: AppColors
                                                                .primaryGreen,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      FilledButton.icon(
                                                        onPressed: () =>
                                                            _handleRunAutoGraduation(
                                                          context,
                                                          ref,
                                                        ),
                                                        icon: const Icon(
                                                          Icons.school,
                                                        ),
                                                        label: const Text(
                                                          'Check / Run Auto-Graduation Now',
                                                        ),
                                                        style:
                                                            FilledButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors
                                                                  .primaryGreen,
                                                          foregroundColor:
                                                              isDark ? Colors.white : Colors.black,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }
                                                return Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => showDialog(
                                                          context: context,
                                                          builder: (_) =>
                                                              _EditScheduleDatesDialog(
                                                            year: activeYear,
                                                          ),
                                                        ),
                                                        icon: const Icon(
                                                          Icons.date_range,
                                                        ),
                                                        label: const Text(
                                                          'Edit Schedule Dates',
                                                        ),
                                                        style:
                                                            OutlinedButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                          side: const BorderSide(
                                                            color: AppColors
                                                                .primaryGreen,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: FilledButton.icon(
                                                        onPressed: () =>
                                                            _handleRunAutoGraduation(
                                                          context,
                                                          ref,
                                                        ),
                                                        icon: const Icon(
                                                          Icons.school,
                                                        ),
                                                        label: const Text(
                                                          'Check / Run Auto-Graduation Now',
                                                        ),
                                                        style:
                                                            FilledButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors
                                                                  .primaryGreen,
                                                          foregroundColor:
                                                              isDark ? Colors.white : Colors.black,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                    loading: () => const Center(child: CircularProgressIndicator()),
                                    error: (err, _) => Text('Error loading academic years: $err', style: const TextStyle(color: Colors.red)),
                                  ),
                                 ],
                               ),
                             );
                          },
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // ── Student Enrollment Auto-Update (Admin Only) ──
                        Consumer(
                          builder: (context, ref, _) {
                            final sysSettingsAsync = ref.watch(systemSettingsProvider);
                            final settingsMap = sysSettingsAsync.asData?.value ?? {};
                            final isAutoEnrollEnabled =
                                (settingsMap['auto_update_enrollment_from_sf'] ?? 'true') == 'true';
                            final frequency = settingsMap['auto_update_enrollment_from_sf_frequency'] ?? 'immediate';
                            final timeVal = settingsMap['auto_update_enrollment_from_sf_time'] ?? '00:00';
                            final isDark = Theme.of(context).brightness == Brightness.dark;

                            return _buildCollapsibleCard(
                              title: 'Student Enrollment Auto-Update',
                              isExpanded: _isAutoEnrollExpanded,
                              onToggle: () => setState(() => _isAutoEnrollExpanded = !_isAutoEnrollExpanded),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_outlined,
                                        color: AppColors.primaryGreen,
                                        size: 24,
                                      ),
                                      const SizedBox(width: AppSizes.p12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Auto-Update Enrollment',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Automatically extract Academic Year, Grade Level, and Section from SF10/SF9 documents',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: isAutoEnrollEnabled,
                                        activeThumbColor: AppColors.primaryGreen,
                                        onChanged: (val) {
                                          ref
                                              .read(systemSettingsProvider.notifier)
                                              .updateSetting(
                                                'auto_update_enrollment_from_sf',
                                                val ? 'true' : 'false',
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSizes.p16),
                                  if (!isAutoEnrollEnabled)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        'Auto-update from SF10/SF9 is currently disabled. Toggle the switch above to enable automatic extraction and updates.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  if (isAutoEnrollEnabled) ...[
                                    Text(
                                      'Update Frequency',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: AppSizes.p8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Immediate',
                                          value: 'immediate',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Daily',
                                          value: 'daily',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Weekly',
                                          value: 'weekly',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Monthly',
                                          value: 'monthly',
                                          currentValue: frequency,
                                        ),
                                      ],
                                    ),
                                    if (frequency != 'immediate') ...[
                                      const SizedBox(height: AppSizes.p16),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Execution Time:',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 12),
                                          DropdownButton<String>(
                                            value: _validTimeValue(timeVal),
                                            underline: const SizedBox(),
                                            items: _buildTimeDropdownItems(),
                                            onChanged: (newTime) {
                                              if (newTime != null) {
                                                ref.read(systemSettingsProvider.notifier).updateSetting(
                                                  'auto_update_enrollment_from_sf_time',
                                                  newTime,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSizes.p24),
                      ],

                      // ── Appearance & Feedback Card (Collapsible) ───────────
                      _buildCollapsibleCard(
                        title: 'Appearance & Feedback',
                        isExpanded: _isAppearanceExpanded,
                        onToggle: () => setState(() => _isAppearanceExpanded = !_isAppearanceExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.palette_outlined,
                                  color: AppColors.primaryGreen,
                                  size: 22,
                                ),
                                const SizedBox(width: AppSizes.p12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Theme Mode',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Choose your preferred theme mode.',
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
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),
                            Consumer(
                              builder: (context, ref, child) {
                                final themeNotifier =
                                    ref.watch(themeModeProvider.notifier);
                                final currentKey = themeNotifier.currentKey;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildThemeOptionChip(
                                      label: 'System',
                                      icon: Icons.brightness_auto_rounded,
                                      value: 'system',
                                      currentValue: currentKey,
                                      onSelect: () => themeNotifier
                                          .setThemeMode('system'),
                                    ),
                                    _buildThemeOptionChip(
                                      label: 'Light',
                                      icon: Icons.light_mode_rounded,
                                      value: 'light',
                                      currentValue: currentKey,
                                      onSelect: () => themeNotifier
                                          .setThemeMode('light'),
                                    ),
                                    _buildThemeOptionChip(
                                      label: 'Dark',
                                      icon: Icons.dark_mode_rounded,
                                      value: 'dark',
                                      currentValue: currentKey,
                                      onSelect: () => themeNotifier
                                          .setThemeMode('dark'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Divider(height: 32),
                            // Sound Effects Toggle
                            Consumer(
                              builder: (context, ref, _) {
                                final isSoundEnabled = ref.watch(soundEnabledProvider);
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.volume_up_outlined,
                                      color: AppColors.primaryGreen,
                                      size: 22,
                                    ),
                                    const SizedBox(width: AppSizes.p12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Sound Effects',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Play audio feedback on user actions and alerts',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: isSoundEnabled,
                                      activeThumbColor: AppColors.primaryGreen,
                                      onChanged: (val) {
                                        ref
                                            .read(soundEnabledProvider.notifier)
                                            .setSoundEnabled(val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (kIsWeb || !Platform.isWindows) ...[
                              const SizedBox(height: AppSizes.p16),
                              // Vibration & Haptics Toggle
                              Consumer(
                                builder: (context, ref, _) {
                                  final isVibrationEnabled = ref.watch(vibrationEnabledProvider);
                                  final isDark = Theme.of(context).brightness == Brightness.dark;
                                  return Row(
                                    children: [
                                      const Icon(
                                        Icons.vibration_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 22,
                                      ),
                                      const SizedBox(width: AppSizes.p12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Vibration & Haptics',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Enable haptic feedback on touch interactions (mobile)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: isVibrationEnabled,
                                        activeThumbColor: AppColors.primaryGreen,
                                        onChanged: (val) {
                                          ref
                                              .read(vibrationEnabledProvider.notifier)
                                              .setVibrationEnabled(val);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p24),

                      // ── Change Password Card ──────────────────────────────
                      _buildCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLarge,
                          ),
                          onTap: () => ChangePasswordModal.show(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: AppSizes.p8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Change Password',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Set a new password for your account',
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
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (user.username.toLowerCase() != 'developer') ...[
                        const SizedBox(height: AppSizes.p24),
                        // ── Danger Zone / Delete Account Card ──────────────────────
                        _buildDangerCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_forever_outlined,
                                      color: AppColors.error,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Danger Zone: Delete Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Permanently delete your account. A verification link will be sent to your registered email to confirm this action.',
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
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text(
                                    'Delete Account',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () => _handleDeleteAccount(context, ref),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSizes.p48),
                    ],
                  ),
                ),
              ),
            ),
                ),
                // Top Blur Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.transparent],
                          stops: [0.6, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        AppColors.darkPageBackground.withValues(alpha: 0.85),
                                        AppColors.darkPageBackground.withValues(alpha: 0.15),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.85),
                                        Colors.white.withValues(alpha: 0.15),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom Blur Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                          stops: [0.0, 0.4],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        AppColors.darkPageBackground.withValues(alpha: 0.0),
                                        AppColors.darkPageBackground.withValues(alpha: 0.85),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.85),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildCard({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }

  Widget _buildDangerCard({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: AppColors.error.withValues(alpha: isDark ? 0.40 : 0.28),
        ),
      ),
      child: child,
    );
  }

  Widget _buildCollapsibleCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticService.light();
                onToggle();
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.p24, 0, AppSizes.p24, AppSizes.p24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: AppSizes.p16),
                  child,
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyChip({
    required WidgetRef ref,
    required String label,
    required String value,
    required String currentValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.pageBackground,
      onSelected: (_) {
        ref.read(systemSettingsProvider.notifier).updateSetting(
          'auto_update_enrollment_from_sf_frequency',
          value,
        );
      },
    );
  }

  Widget _buildThemeOptionChip({
    required String label,
    required IconData icon,
    required String value,
    required String currentValue,
    required VoidCallback onSelect,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == currentValue;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : AppColors.primaryGreen,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.pageBackground,
      onSelected: (_) => onSelect(),
    );
  }

  String _validTimeValue(String? val) {
    const validTimes = [
      '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
      '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
      '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
    ];
    if (val != null && validTimes.contains(val)) return val;
    return '00:00';
  }

  List<DropdownMenuItem<String>> _buildTimeDropdownItems() {
    const times = [
      '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
      '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
      '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
    ];
    return times.map((t) {
      final parts = t.split(':');
      final hour = int.parse(parts[0]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final displayTime = '${displayHour.toString().padLeft(2, '0')}:00 $suffix';
      return DropdownMenuItem<String>(
        value: t,
        child: Text(displayTime, style: const TextStyle(fontSize: 14)),
      );
    }).toList();
  }
}

class _TransferProgressDialog extends StatefulWidget {
  final String title;
  final String initialStatus;
  final Future<void> Function(
    void Function(int count, int total) onProgress,
    CancelToken cancelToken,
  ) action;

  const _TransferProgressDialog({
    required this.title,
    required this.initialStatus,
    required this.action,
  });

  @override
  State<_TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<_TransferProgressDialog> {
  final CancelToken _cancelToken = CancelToken();
  double? _progress;
  String _statusText = '';
  String _etaText = 'Calculating ETA...';
  String _rateText = '';
  DateTime? _startTime;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    _statusText = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAction();
      }
    });
  }

  void _onProgress(int count, int total) {
    if (!mounted) return;

    final now = DateTime.now();
    _startTime ??= now;
    _lastTime ??= now;

    double? p;
    String status;
    String eta = 'Calculating...';
    String rateStr = '';

    if (total > 0) {
      p = count / total;
      final mbCount = (count / (1024 * 1024)).toStringAsFixed(1);
      final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
      final pct = (p * 100).toStringAsFixed(0);
      status = '$pct% ($mbCount MB / $mbTotal MB)';

      final elapsedSec = now.difference(_startTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0.5 && count > 0) {
        final rateBytesPerSec = count / elapsedSec;
        final rateMbPerSec = (rateBytesPerSec / (1024 * 1024)).toStringAsFixed(2);
        rateStr = '$rateMbPerSec MB/s';

        final remainingBytes = total - count;
        if (rateBytesPerSec > 0) {
          final remainingSec = remainingBytes / rateBytesPerSec;
          final mins = (remainingSec / 60).floor();
          final secs = (remainingSec % 60).round();
          if (mins > 0) {
            eta = '${mins}m ${secs}s remaining';
          } else {
            eta = '${secs}s remaining';
          }
        }
      }
    } else {
      final mbCount = (count / (1024 * 1024)).toStringAsFixed(1);
      status = '$mbCount MB transferred';
    }

    setState(() {
      _progress = p;
      _statusText = status;
      _etaText = eta;
      _rateText = rateStr;
    });
  }

  Future<void> _startAction() async {
    try {
      await widget.action(_onProgress, _cancelToken);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (_cancelToken.isCancelled) {
        Navigator.of(context).pop('cancelled');
      } else {
        Navigator.of(context).pop(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sync_rounded, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  backgroundColor: AppColors.inputBackground,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _rateText.isNotEmpty ? _rateText : 'Starting transfer...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _etaText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please do not close the window while the transfer is in progress.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              _cancelToken.cancel('User cancelled transfer');
            },
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            label: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditScheduleDatesDialog extends ConsumerStatefulWidget {
  final AcademicYearModel year;
  const _EditScheduleDatesDialog({required this.year});

  @override
  ConsumerState<_EditScheduleDatesDialog> createState() =>
      _EditScheduleDatesDialogState();
}

class _EditScheduleDatesDialogState
    extends ConsumerState<_EditScheduleDatesDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.year.startDate != null
        ? DateTime.tryParse(widget.year.startDate!)
        : null;
    _endDate = widget.year.endDate != null
        ? DateTime.tryParse(widget.year.endDate!)
        : null;
  }

  String? _formatYmd(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(setupMutationProvider.notifier).updateAcademicYear(
            id: widget.year.id,
            yearRange: widget.year.yearRange,
            status: widget.year.status,
            startDate: _formatYmd(_startDate),
            endDate: _formatYmd(_endDate),
          );
      ref.invalidate(academicYearsListProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        message:
            'Schedule dates updated for Academic Year ${widget.year.yearRange}!',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Save Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 500 ||
        Theme.of(context).platform == TargetPlatform.android;

    return CustomModal(
      title: 'Edit Schedule Dates',
      icon: Icons.calendar_today,
      maxWidth: 460,
      content: Padding(
        padding: EdgeInsets.all(isNarrow ? 14 : AppSizes.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, size: 20, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Academic Year: ${widget.year.yearRange} (${widget.year.status.toUpperCase()})',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final initialDates = <DateTime>[];
                  if (_startDate != null) initialDates.add(_startDate!);
                  if (_endDate != null) initialDates.add(_endDate!);

                  final results = await showCalendarDatePicker2Dialog(
                    context: context,
                    config: CalendarDatePicker2WithActionButtonsConfig(
                      calendarType: CalendarDatePicker2Type.range,
                      firstDate: DateTime(1990),
                      lastDate: DateTime(2100),
                      selectedDayHighlightColor: AppColors.primaryGreen,
                      okButton: const Text(
                        'APPLY',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      cancelButton: const Text(
                        'CANCEL',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    dialogSize: const Size(325, 400),
                    value: initialDates,
                    borderRadius: BorderRadius.circular(16),
                  );

                  if (results != null && results.isNotEmpty) {
                    setState(() {
                      _startDate = results.first;
                      _endDate =
                          results.length > 1 ? results.last : results.first;
                    });
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_outlined,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (_startDate != null && _endDate != null)
                              ? '${_formatYmd(_startDate)}  to  ${_formatYmd(_endDate)}'
                              : _startDate != null
                                  ? 'Start: ${_formatYmd(_startDate)} (Select End Date)'
                                  : 'Select Schedule Dates (Optional)',
                          style: TextStyle(
                            fontSize: 13,
                            color: (_startDate != null || _endDate != null)
                                ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary)
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted),
                            fontWeight: (_startDate != null || _endDate != null)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_startDate != null || _endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Clear dates',
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Dates'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

