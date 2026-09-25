import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/theme_extension.dart';

class CapstoneMembersScreen extends StatefulWidget {
  const CapstoneMembersScreen({super.key});

  @override
  State<CapstoneMembersScreen> createState() => _CapstoneMembersScreenState();
}

class _CapstoneMembersScreenState extends State<CapstoneMembersScreen> {
  static const List<String> _groupImages = [
    'assets/images/group/1.webp',
    'assets/images/group/2.webp',
    'assets/images/group/3.webp',
    'assets/images/group/4.webp',
    'assets/images/group/5.webp',
    'assets/images/group/6.webp',
    'assets/images/group/7.webp',
    'assets/images/group/8.webp',
    'assets/images/group/9.webp',
    'assets/images/group/10.webp',
    'assets/images/group/11.webp',
    'assets/images/group/12.webp',
    'assets/images/group/13.webp',
  ];

  static const List<_MemberInfo> _members = [
    _MemberInfo(
      name: 'Alibutod, Rhina Mhay C.',
      role: 'Technical Writer',
      email: 'alibutodrhinamhay@gmail.com',
      avatarAsset: 'assets/images/solo/rhinamae.webp',
    ),
    _MemberInfo(
      name: 'Antonio, Clara Maris B.',
      role: 'UI/UX Designer',
      email: 'antonioclaramaris.21@gmail.com',
      avatarAsset: 'assets/images/solo/claramaris.webp',
    ),
    _MemberInfo(
      name: 'De Vera, Ermhar A.',
      role: 'System Analyst',
      email: 'ermhardevera11@gmail.com',
      avatarAsset: 'assets/images/solo/ermhar.webp',
    ),
    _MemberInfo(
      name: 'Ellio, James Young G.',
      role: 'Tester',
      email: 'elliojames01@gmail.com',
      avatarAsset: 'assets/images/solo/jamesyoung.webp',
    ),
    _MemberInfo(
      name: 'Garcia, Cris Charles V.',
      role: 'Programmer',
      email: 'crischarlesgarcia345@gmail.com',
      avatarAsset: 'assets/images/solo/crischarles.webp',
    ),
    _MemberInfo(
      name: 'Pasigan, Chinee R.',
      role: 'Project Manager',
      email: 'chineepasigan@gmail.com',
      avatarAsset: 'assets/images/solo/chinee.webp',
    ),
  ];

  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _goToNext();
    });
  }

  void _goToNext() {
    if (!_pageController.hasClients) return;
    final nextIndex = (_currentIndex + 1) % _groupImages.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goToPrevious() {
    if (!_pageController.hasClients) return;
    final prevIndex = (_currentIndex - 1 + _groupImages.length) % _groupImages.length;
    _pageController.animateToPage(
      prevIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Capstone 1-2'),
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'PLSP (Pamantasan ng Lungsod ng San Pablo)',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Capstone 1-2 Project Team',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Group Pictures Slide Preview (Single image with 2s cooldown) ──
                MouseRegion(
                  onEnter: (_) => _cooldownTimer?.cancel(),
                  onExit: (_) => _startCooldownTimer(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _groupImages.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                              _startCooldownTimer();
                            },
                            itemBuilder: (context, index) {
                              return Image.asset(
                                _groupImages[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Previous Button
                          Positioned(
                            left: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                                  tooltip: 'Previous photo',
                                  onPressed: () {
                                    _goToPrevious();
                                    _startCooldownTimer();
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Next Button
                          Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                                  tooltip: 'Next photo',
                                  onPressed: () {
                                    _goToNext();
                                    _startCooldownTimer();
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Indicator Pill (Current Index / Total)
                          Positioned(
                            bottom: 12,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_currentIndex + 1} / ${_groupImages.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
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

                const SizedBox(height: 32),
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.primaryGreen, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'Capstone Members',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Members List ──
                ..._members.map(
                  (member) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Solo Avatar Picture
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                member.avatarAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: AppColors.primaryGreen),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name, Role & Email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  member.role,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                                if (member.email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.email_outlined,
                                        size: 14,
                                        color: isDark ? AppColors.darkTextMuted : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      SelectableText(
                                        member.email,
                                        style: TextStyle(
                                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                          fontSize: 13,
                                        ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberInfo {
  final String name;
  final String role;
  final String email;
  final String avatarAsset;

  const _MemberInfo({
    required this.name,
    required this.role,
    required this.email,
    required this.avatarAsset,
  });
}
