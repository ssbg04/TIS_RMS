import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../../domain/entities/user_model.dart';
import 'widgets/security_section.dart';

class SecurityScreen extends ConsumerWidget {
  final UserModel user;
  final Future<void> Function(BuildContext, WidgetRef) onDeactivateAccount;

  const SecurityScreen({
    super.key,
    required this.user,
    required this.onDeactivateAccount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buildCard({required Widget child}) {
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

    Widget buildDangerCard({required Widget child}) {
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
            color: AppColors.error.withValues(alpha: isDark ? 0.45 : 0.35),
            width: 1.5,
          ),
        ),
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticService.light();
            Navigator.of(context).pop();
          },
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p24,
            vertical: AppSizes.p32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: buildCard(
                child: SecuritySection(
                  user: user,
                  onDeactivateAccount: onDeactivateAccount,
                  buildCard: buildCard,
                  buildDangerCard: buildDangerCard,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
