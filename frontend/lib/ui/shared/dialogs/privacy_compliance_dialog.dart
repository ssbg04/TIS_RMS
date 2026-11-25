import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// Displays the Talisay Integrated School RMS Privacy Notice,
/// ISO standards alignment, and Philippine legal compliance details.
class PrivacyComplianceDialog extends StatelessWidget {
  const PrivacyComplianceDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (!context.mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (_) => const PrivacyComplianceDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isHighContrast = theme.dividerColor != Colors.transparent &&
        theme.cardTheme.shape is RoundedRectangleBorder &&
        ((theme.cardTheme.shape as RoundedRectangleBorder).side !=
            BorderSide.none);

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 560;

    final dialogBg = theme.cardTheme.color ??
        (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite);
    final sectionBg = isHighContrast
        ? colorScheme.surface
        : (isDark ? AppColors.darkSurface2 : AppColors.pageBackground);
    final borderColor = isHighContrast
        ? colorScheme.outline
        : (isDark ? AppColors.darkBorder : AppColors.borderLight);
    final textPrimary = colorScheme.onSurface;
    final textSecondary = colorScheme.onSurfaceVariant;
    final accentColor = colorScheme.primary;

    return Dialog(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        side: BorderSide(
          color: borderColor,
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
        vertical: isMobile ? AppSizes.p16 : AppSizes.p24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: screenSize.height * 0.86,
        ),
        child: DefaultTabController(
          length: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? AppSizes.p16 : AppSizes.p24,
                  isMobile ? AppSizes.p16 : AppSizes.p20,
                  AppSizes.p12,
                  AppSizes.p12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        border: isHighContrast
                            ? Border.all(color: accentColor, width: 1.2)
                            : null,
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: accentColor,
                        size: AppSizes.iconMedium,
                      ),
                    ),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Notice & Compliance',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Talisay Integrated School · Records Management System',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderColor),
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: TabBar(
                  isScrollable: isMobile,
                  tabAlignment:
                      isMobile ? TabAlignment.start : TabAlignment.fill,
                  labelColor: accentColor,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: accentColor,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.privacy_tip_outlined, size: 18),
                      text: 'Data Privacy',
                    ),
                    Tab(
                      icon: Icon(Icons.workspace_premium_outlined, size: 18),
                      text: 'ISO Standards',
                    ),
                    Tab(
                      icon: Icon(Icons.gavel_outlined, size: 18),
                      text: 'Philippine Laws',
                    ),
                  ],
                ),
              ),

              // Tab Body
              Flexible(
                child: TabBarView(
                  children: [
                    _buildPrivacyTab(
                      context,
                      isMobile: isMobile,
                      sectionBg: sectionBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      accentColor: accentColor,
                      isHighContrast: isHighContrast,
                    ),
                    _buildIsoTab(
                      context,
                      isMobile: isMobile,
                      sectionBg: sectionBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      accentColor: accentColor,
                      isHighContrast: isHighContrast,
                    ),
                    _buildLawsTab(
                      context,
                      isMobile: isMobile,
                      sectionBg: sectionBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      accentColor: accentColor,
                      isHighContrast: isHighContrast,
                    ),
                  ],
                ),
              ),

              // Footer Actions
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? AppSizes.p16 : AppSizes.p24,
                  vertical: AppSizes.p12,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'R.A. 10173 · ISO/IEC 25010 & 27001',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.p12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p20,
                          vertical: AppSizes.p12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyTab(
    BuildContext context, {
    required bool isMobile,
    required Color sectionBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    required bool isHighContrast,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionBanner(
            badge: 'R.A. 10173',
            title: 'Data Privacy Act of 2012',
            subtitle:
                'Talisay Integrated School processes learner and staff records in strict accordance with the Philippine Data Privacy Act and NPC guidelines.',
            accentColor: accentColor,
            backgroundColor: sectionBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isHighContrast: isHighContrast,
          ),
          const SizedBox(height: AppSizes.p12),
          _InfoSectionCard(
            icon: Icons.folder_shared_outlined,
            title: 'Data Collected',
            accentColor: accentColor,
            backgroundColor: sectionBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isHighContrast: isHighContrast,
            bullets: const [
              'Student Learner Reference Number (LRN) and personal profile details (full name, birth date, sex, and 4Ps beneficiary status).',
              'Scholastic records and standardized DepEd school forms (SF9, SF10, PSA birth certificate, and Good Moral certificates).',
              'Authorized user account credentials, device/session metadata, and authentication logs.',
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          _InfoSectionCard(
            icon: Icons.school_outlined,
            title: 'Purpose of Processing',
            accentColor: accentColor,
            backgroundColor: sectionBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isHighContrast: isHighContrast,
            bullets: const [
              'DepEd school records management and academic enrollment tracking for Talisay Integrated School.',
              'OCR-assisted document encoding and verification to reduce manual entry errors.',
              'Long-term archival compliance, retrieval, and official academic reporting.',
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          _InfoSectionCard(
            icon: Icons.security_outlined,
            title: 'Security Safeguards',
            accentColor: accentColor,
            backgroundColor: sectionBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isHighContrast: isHighContrast,
            bullets: const [
              'Bcrypt password hashing and JWT authentication with remote session revocation.',
              'Optional Two-Factor Authentication (TOTP authenticator app & Email OTP).',
              'Login rate limiting with 15-minute account lockout alerts to mitigate brute-force attempts.',
              'Role-based access control (Admin / Teacher) and full activity audit logging.',
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          _InfoSectionCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Data Retention & Subject Rights',
            accentColor: accentColor,
            backgroundColor: sectionBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isHighContrast: isHighContrast,
            bullets: const [
              'Learners, parents/guardians, and staff retain rights to access, review, and request correction of inaccurate records.',
              'Records retention, archival, and authorized deletion are governed by designated school administrators in line with DepEd and National Archives schedules.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIsoTab(
    BuildContext context, {
    required bool isMobile,
    required Color sectionBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    required bool isHighContrast,
  }) {
    const standards = [
      (
        code: 'ISO/IEC 25010',
        title: 'Systems & Software Quality Model (SQuaRE)',
        description:
            'Guided across all eight quality characteristics: Functional Suitability, Performance Efficiency, Compatibility, Usability, Reliability, Security, Maintainability, and Portability.',
        icon: Icons.verified_outlined,
      ),
      (
        code: 'ISO/IEC 27001',
        title: 'Information Security Management Systems (ISMS)',
        description:
            'Risk-based access control, cryptographic credential protection, session management, rate limiting, and tamper-evident audit logging.',
        icon: Icons.shield_outlined,
      ),
      (
        code: 'ISO 15489-1',
        title: 'Information & Documentation — Records Management',
        description:
            'Structured capture, classification, metadata indexing, secure storage, and lifecycle governance of official school records and forms.',
        icon: Icons.inventory_2_outlined,
      ),
      (
        code: 'ISO 9241-210 / 11',
        title: 'Human-System Interaction & WCAG AA Accessibility',
        description:
            'Human-centered interface design supporting light, dark, and high-contrast themes, keyboard navigation, and accessible contrast ratios.',
        icon: Icons.accessibility_new_outlined,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < standards.length; i++) ...[
            _StandardCard(
              code: standards[i].code,
              title: standards[i].title,
              description: standards[i].description,
              icon: standards[i].icon,
              accentColor: accentColor,
              backgroundColor: sectionBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isHighContrast: isHighContrast,
            ),
            if (i < standards.length - 1) const SizedBox(height: AppSizes.p12),
          ],
        ],
      ),
    );
  }

  Widget _buildLawsTab(
    BuildContext context, {
    required bool isMobile,
    required Color sectionBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    required bool isHighContrast,
  }) {
    const laws = [
      (
        code: 'R.A. 10173',
        title: 'Data Privacy Act of 2012 (DPA) & NPC Guidelines',
        description:
            'Mandates transparency, legitimate purpose, and proportionality in collecting, storing, and processing personal and sensitive personal information of students and school personnel.',
        icon: Icons.policy_outlined,
      ),
      (
        code: 'DepEd Order No. 58, s. 2017 & No. 4, s. 2014',
        title: 'Standardized School Forms (SF1, SF9, SF10)',
        description:
            'Governs adoption and management of standardized learner school forms, permanent academic records, and LRN-based enrollment documentation.',
        icon: Icons.assignment_outlined,
      ),
      (
        code: 'R.A. 9470',
        title: 'National Archives of the Philippines Act of 2007',
        description:
            'Establishes archival preservation, retention scheduling, and controlled disposition rules for public school records.',
        icon: Icons.archive_outlined,
      ),
      (
        code: 'R.A. 10175',
        title: 'Cybercrime Prevention Act of 2012',
        description:
            'Prohibits unauthorized system access, data interference, and identity misuse; reinforced through RBAC, session controls, and audit trails.',
        icon: Icons.lock_person_outlined,
      ),
      (
        code: 'R.A. 8792',
        title: 'Electronic Commerce Act of 2000',
        description:
            'Provides legal recognition and integrity requirements for electronic documents, digital records, and electronic transactions.',
        icon: Icons.description_outlined,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < laws.length; i++) ...[
            _StandardCard(
              code: laws[i].code,
              title: laws[i].title,
              description: laws[i].description,
              icon: laws[i].icon,
              accentColor: accentColor,
              backgroundColor: sectionBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isHighContrast: isHighContrast,
            ),
            if (i < laws.length - 1) const SizedBox(height: AppSizes.p12),
          ],
        ],
      ),
    );
  }
}

class _SectionBanner extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isHighContrast;

  const _SectionBanner({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: isHighContrast ? borderColor : accentColor.withValues(alpha: 0.35),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bullets;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isHighContrast;

  const _InfoSectionCard({
    required this.icon,
    required this.title,
    required this.bullets,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: borderColor,
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: AppSizes.p8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p8),
          for (final item in bullets) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StandardCard extends StatelessWidget {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isHighContrast;

  const _StandardCard({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: borderColor,
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: isHighContrast
                  ? Border.all(color: accentColor, width: 1.0)
                  : null,
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
