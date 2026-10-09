import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../shared/widgets/abstract_background.dart';
import '../../shared/widgets/app_button_loader.dart';
import '../login/login_screen.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/notification_service.dart';

class SetupWizardScreen extends StatefulWidget {
  final bool isFirstTime;
  final Widget? nextScreen;
  final VoidCallback? onComplete;

  const SetupWizardScreen({
    super.key,
    this.isFirstTime = true,
    this.nextScreen,
    this.onComplete,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _isRequestingAll = false;

  bool _storageGranted = false;
  bool _notificationGranted = false;
  bool _installPackagesGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _storageGranted = true;
          _notificationGranted = true;
          _installPackagesGranted = true;
          _loading = false;
        });
      }
      return;
    }

    bool storage = false;
    bool notification = false;
    bool installPackages = false;

    try {
      // 1. Storage
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        storage = await Permission.manageExternalStorage.isGranted;
      } else {
        storage = await Permission.storage.isGranted;
      }

      // 2. Notification
      notification = await Permission.notification.isGranted;

      // 3. Install Unknown Apps
      installPackages = await Permission.requestInstallPackages.isGranted;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _storageGranted = storage;
        _notificationGranted = notification;
        _installPackagesGranted = installPackages;
        _loading = false;
      });
    }
  }

  Future<void> _requestStorage() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      PermissionStatus status;
      if (androidInfo.version.sdkInt >= 30) {
        status = await Permission.manageExternalStorage.request();
      } else {
        status = await Permission.storage.request();
      }

      if (status.isPermanentlyDenied) {
        _promptOpenSettings('Storage Access');
      }
    } catch (_) {}
    await _checkAllPermissions();
  }

  Future<void> _requestNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final status = await Permission.notification.request();
      await NotificationService().requestPermission();
      await FcmService.requestPermission();
      if (status.isPermanentlyDenied) {
        _promptOpenSettings('Notifications');
      }
    } catch (_) {}
    await _checkAllPermissions();
  }

  Future<void> _requestInstallPackages() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final status = await Permission.requestInstallPackages.request();
      if (status.isPermanentlyDenied) {
        _promptOpenSettings('Install Unknown Apps');
      }
    } catch (_) {}
    await _checkAllPermissions();
  }

  Future<void> _requestAll() async {
    if (_isRequestingAll) return;
    setState(() => _isRequestingAll = true);

    if (!_storageGranted) {
      await _requestStorage();
    }
    if (!_notificationGranted) {
      await _requestNotification();
    }
    if (!_installPackagesGranted) {
      await _requestInstallPackages();
    }

    if (mounted) {
      setState(() => _isRequestingAll = false);
    }
  }

  void _promptOpenSettings(String permissionName) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$permissionName Required'),
        content: Text(
          '$permissionName was permanently denied or requires manual approval in device settings. Please enable it in Application Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishSetup({bool isSkipping = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_wizard_completed', true);

    if (!mounted) return;

    if (isSkipping && (!_storageGranted || !_notificationGranted || !_installPackagesGranted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some features (auto-updates or downloads) may require manual permission later.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreen!),
      );
      return;
    }

    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    if (widget.isFirstTime) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  int get _grantedCount {
    int count = 0;
    if (_storageGranted) count++;
    if (_notificationGranted) count++;
    if (_installPackagesGranted) count++;
    return count;
  }

  bool get _allGranted => _storageGranted && _notificationGranted && _installPackagesGranted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      body: AbstractBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      children: [
                        if (!widget.isFirstTime)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Header Crest & Title ───────────────
                                Center(
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.school_rounded,
                                        size: 40,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'SETUP WIZARD',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.isFirstTime
                                      ? 'Welcome to TIS RMS'
                                      : 'Device Permissions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Grant the following permissions to enable downloads, real-time sync notifications, and automatic updates on your device.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Progress Card ───────────────────────
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Permissions Progress',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            '$_grantedCount of 3 Granted',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _allGranted
                                                  ? AppColors.primaryGreen
                                                  : AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _grantedCount / 3,
                                          minHeight: 6,
                                          backgroundColor: isDark
                                              ? AppColors.darkSurface2
                                              : AppColors.borderLight,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _allGranted
                                                ? AppColors.primaryGreen
                                                : AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ── Permission Cards ────────────────────
                                _buildPermissionTile(
                                  context: context,
                                  icon: Icons.folder_open_rounded,
                                  iconBgColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                                  iconColor: const Color(0xFF2E7D32),
                                  title: 'Storage Access',
                                  subtitle:
                                      'Allows downloading student records, Form 137/SF10 documents, report cards, and archives to your device storage.',
                                  isGranted: _storageGranted,
                                  onRequest: _requestStorage,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                _buildPermissionTile(
                                  context: context,
                                  icon: Icons.notifications_active_rounded,
                                  iconBgColor: const Color(0xFF1976D2).withValues(alpha: 0.12),
                                  iconColor: const Color(0xFF1976D2),
                                  title: 'Push Notifications',
                                  subtitle:
                                      'Notifies you in real-time about newly uploaded documents, verification requests, and system alerts even when the app is in the background.',
                                  isGranted: _notificationGranted,
                                  onRequest: _requestNotification,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                _buildPermissionTile(
                                  context: context,
                                  icon: Icons.system_update_alt_rounded,
                                  iconBgColor: const Color(0xFFE65100).withValues(alpha: 0.12),
                                  iconColor: const Color(0xFFE65100),
                                  title: 'Install Unknown Apps',
                                  subtitle:
                                      'Allows in-app auto-updates when newer TIS RMS APK versions are released so you never have to manually reinstall.',
                                  isGranted: _installPackagesGranted,
                                  onRequest: _requestInstallPackages,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 24),

                                // ── Master Action Button ─────────────────
                                if (!_allGranted) ...[
                                  ElevatedButton(
                                    onPressed: _isRequestingAll ? null : _requestAll,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isRequestingAll
                                        ? const AppButtonLoader()
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.shield_rounded, size: 18),
                                              SizedBox(width: 8),
                                              Text(
                                                'Grant All Permissions',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => _finishSetup(isSkipping: true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: secondaryTextColor,
                                    ),
                                    child: Text(
                                      widget.isFirstTime
                                          ? 'Skip for now & Continue'
                                          : 'Done',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ] else ...[
                                  ElevatedButton(
                                    onPressed: () => _finishSetup(isSkipping: false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.isFirstTime
                                              ? 'All Set — Continue to TIS RMS'
                                              : 'Save & Return',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_rounded, size: 18),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'You can review or change permissions anytime in Android Settings > Apps > TIS RMS.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
    required Color cardColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? AppColors.primaryGreen.withValues(alpha: 0.35)
              : borderColor,
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? AppColors.primaryGreen.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle_rounded : Icons.pending_outlined,
                            size: 13,
                            color: isGranted ? AppColors.primaryGreen : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGranted ? 'Granted' : 'Required',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isGranted ? AppColors.primaryGreen : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: secondaryTextColor,
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.lock_open_rounded, size: 14),
                      label: const Text('Grant Permission'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
