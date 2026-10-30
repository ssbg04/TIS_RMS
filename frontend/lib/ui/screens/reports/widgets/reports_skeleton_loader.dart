import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/app_skeleton_loader.dart';

Widget _buildSkeletonCard({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  double? height,
  double? width,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    height: height,
    width: width,
    padding: padding,
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
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

// ════════════════════════════════════════════════════════════════
// DOCUMENT COMPLIANCE SKELETON LOADER
// ════════════════════════════════════════════════════════════════
class ReportsComplianceSkeletonLoader extends StatelessWidget {
  const ReportsComplianceSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android ||
        (!kIsWeb && Platform.isAndroid);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWindowsApp = Theme.of(context).platform == TargetPlatform.windows
            ? constraints.maxWidth >= 720
            : (!isAndroid && constraints.maxWidth >= 850);
        final isDesktop = !isAndroid && MediaQuery.of(context).size.width > 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSkeleton(context, isDesktop),
            const SizedBox(height: 10),
            _buildMetricsGridSkeleton(context, isWindowsApp),
            const SizedBox(height: 12),
            _buildBentoBlock1Skeleton(context, isWindowsApp),
            const SizedBox(height: 14),
            _buildBentoBlock2Skeleton(context, isWindowsApp),
            const SizedBox(height: 14),
            _buildTableSkeleton(context),
          ],
        );
      },
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return const Row(
        children: [
          AppSkeletonLoader(width: 40, height: 40, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLoader(width: 260, height: 20, borderRadius: 4),
                SizedBox(height: 6),
                AppSkeletonLoader(width: 380, height: 13, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 16),
          AppSkeletonLoader(width: 130, height: 38, borderRadius: 8),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLoader(width: 180, height: 17, borderRadius: 4),
                  SizedBox(height: 5),
                  AppSkeletonLoader(width: 220, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AppSkeletonLoader(height: 40, borderRadius: 8)),
            SizedBox(width: 10),
            Expanded(child: AppSkeletonLoader(height: 40, borderRadius: 8)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGridSkeleton(BuildContext context, bool isWindowsApp) {
    if (isWindowsApp) {
      return SizedBox(
        height: 156,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero compliance card skeleton
            Expanded(
              flex: 3,
              child: _buildSkeletonCard(
                context: context,
                padding: const EdgeInsets.all(18),
                child: const Row(
                  children: [
                    AppSkeletonLoader(width: 84, height: 84, borderRadius: 42),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSkeletonLoader(width: 100, height: 13, borderRadius: 4),
                          SizedBox(height: 8),
                          AppSkeletonLoader(width: 70, height: 28, borderRadius: 6),
                          SizedBox(height: 8),
                          AppSkeletonLoader(width: 120, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 3 primary KPI cards
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _buildSkeletonCard(
                  context: context,
                  padding: const EdgeInsets.all(16),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppSkeletonLoader(width: 90, height: 13, borderRadius: 4),
                          AppSkeletonLoader(width: 32, height: 32, borderRadius: 8),
                        ],
                      ),
                      AppSkeletonLoader(width: 60, height: 26, borderRadius: 6),
                      AppSkeletonLoader(width: 110, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Mobile 2x2 grid
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: List.generate(
        4,
        (index) => _buildSkeletonCard(
          context: context,
          padding: const EdgeInsets.all(12),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: AppSkeletonLoader(height: 12, borderRadius: 4)),
                  SizedBox(width: 8),
                  AppSkeletonLoader(width: 24, height: 24, borderRadius: 6),
                ],
              ),
              AppSkeletonLoader(width: 50, height: 20, borderRadius: 4),
              AppSkeletonLoader(width: 90, height: 10, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoBlock1Skeleton(BuildContext context, bool isWindowsApp) {
    final card1 = _buildSkeletonCard(
      context: context,
      height: 310,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLoader(width: 170, height: 16, borderRadius: 4),
                  SizedBox(height: 5),
                  AppSkeletonLoader(width: 210, height: 11, borderRadius: 4),
                ],
              ),
              AppSkeletonLoader(width: 70, height: 26, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final h in [0.65, 0.85, 0.50, 0.90, 0.70, 0.80])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FractionallySizedBox(
                        heightFactor: h,
                        alignment: Alignment.bottomCenter,
                        child: const AppSkeletonLoader(height: double.infinity, borderRadius: 6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < 6; i++)
                const AppSkeletonLoader(width: 32, height: 10, borderRadius: 3),
            ],
          ),
        ],
      ),
    );

    final card2 = _buildSkeletonCard(
      context: context,
      height: 310,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLoader(width: 180, height: 16, borderRadius: 4),
                  SizedBox(height: 5),
                  AppSkeletonLoader(width: 230, height: 11, borderRadius: 4),
                ],
              ),
              AppSkeletonLoader(width: 60, height: 24, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final w in [0.75, 0.55, 0.90, 0.40, 0.65])
                  Row(
                    children: [
                      const AppSkeletonLoader(width: 75, height: 11, borderRadius: 4),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: w,
                          child: const AppSkeletonLoader(height: 14, borderRadius: 4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const AppSkeletonLoader(width: 28, height: 11, borderRadius: 4),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isWindowsApp) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: card1),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: card2),
        ],
      );
    }
    return Column(
      children: [
        card1,
        const SizedBox(height: 16),
        card2,
      ],
    );
  }

  Widget _buildBentoBlock2Skeleton(BuildContext context, bool isWindowsApp) {
    final card1 = _buildSkeletonCard(
      context: context,
      height: 330,
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonLoader(width: 160, height: 16, borderRadius: 4),
          SizedBox(height: 5),
          AppSkeletonLoader(width: 200, height: 11, borderRadius: 4),
          SizedBox(height: 20),
          Expanded(
            child: Center(
              child: AppSkeletonLoader(width: 140, height: 140, borderRadius: 70),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AppSkeletonLoader(width: 70, height: 14, borderRadius: 4),
              AppSkeletonLoader(width: 70, height: 14, borderRadius: 4),
              AppSkeletonLoader(width: 70, height: 14, borderRadius: 4),
            ],
          ),
        ],
      ),
    );

    final card2 = _buildSkeletonCard(
      context: context,
      height: 330,
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLoader(width: 180, height: 16, borderRadius: 4),
                  SizedBox(height: 5),
                  AppSkeletonLoader(width: 220, height: 11, borderRadius: 4),
                ],
              ),
              AppSkeletonLoader(width: 90, height: 26, borderRadius: 6),
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppSkeletonLoader(height: double.infinity, borderRadius: 8),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 50, height: 10, borderRadius: 3),
              AppSkeletonLoader(width: 50, height: 10, borderRadius: 3),
              AppSkeletonLoader(width: 50, height: 10, borderRadius: 3),
              AppSkeletonLoader(width: 50, height: 10, borderRadius: 3),
            ],
          ),
        ],
      ),
    );

    if (isWindowsApp) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: card1),
          const SizedBox(width: 14),
          Expanded(flex: 6, child: card2),
        ],
      );
    }
    return Column(
      children: [
        card1,
        const SizedBox(height: 12),
        card2,
      ],
    );
  }

  Widget _buildTableSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSkeletonCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header of table card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonLoader(width: 210, height: 18, borderRadius: 4),
                        SizedBox(height: 6),
                        AppSkeletonLoader(width: 280, height: 12, borderRadius: 4),
                      ],
                    ),
                    AppSkeletonLoader(width: 70, height: 26, borderRadius: 13),
                  ],
                ),
                const SizedBox(height: 14),
                const AppSkeletonLoader(height: 42, borderRadius: 10),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
          // Table columns bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.primaryGreen.withValues(alpha: 0.04),
            child: const Row(
              children: [
                Expanded(flex: 2, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
                SizedBox(width: 16),
                Expanded(flex: 3, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
                SizedBox(width: 16),
                Expanded(flex: 2, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: AppSkeletonLoader(height: 12, borderRadius: 3)),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
          // 6 table row skeletons
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppSkeletonLoader(height: 12, width: i % 2 == 0 ? 90 : 70, borderRadius: 3),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: AppSkeletonLoader(height: 12, width: i % 2 == 0 ? 140 : 110, borderRadius: 3),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(flex: 1, child: AppSkeletonLoader(height: 12, width: 30, borderRadius: 3)),
                  const SizedBox(width: 16),
                  const Expanded(flex: 1, child: AppSkeletonLoader(height: 18, width: 50, borderRadius: 9)),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: AppSkeletonLoader(height: 12, width: 65, borderRadius: 3)),
                  const SizedBox(width: 16),
                  const Expanded(flex: 1, child: AppSkeletonLoader(height: 18, width: 45, borderRadius: 9)),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
          ],
          // Footer pagination
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonLoader(width: 140, height: 12, borderRadius: 3),
                AppSkeletonLoader(width: 90, height: 28, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TRANSPARENCY BOARD SKELETON LOADER
// ════════════════════════════════════════════════════════════════
class TransparencyBoardSkeletonLoader extends StatelessWidget {
  const TransparencyBoardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTransparencyToolbarSkeleton(context),
        const SizedBox(height: 12),
        _buildEnrollmentCardSkeleton(context),
        const SizedBox(height: 10),
        _buildDropoutCardSkeleton(context),
        const SizedBox(height: 10),
        _buildEquity4PsCardSkeleton(context),
      ],
    );
  }

  Widget _buildTransparencyToolbarSkeleton(BuildContext context) {
    return _buildSkeletonCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: const Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSkeletonLoader(width: 100, height: 32, borderRadius: 8),
              SizedBox(width: 8),
              AppSkeletonLoader(width: 90, height: 32, borderRadius: 8),
              SizedBox(width: 8),
              AppSkeletonLoader(width: 110, height: 32, borderRadius: 8),
            ],
          ),
          AppSkeletonLoader(width: 120, height: 34, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _buildEnrollmentCardSkeleton(BuildContext context) {
    return _buildSkeletonCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonLoader(width: 180, height: 16, borderRadius: 4),
                      SizedBox(height: 5),
                      AppSkeletonLoader(width: 120, height: 11, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              AppSkeletonLoader(width: 110, height: 30, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: AppSkeletonLoader(height: 64, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: AppSkeletonLoader(height: 64, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: AppSkeletonLoader(height: 64, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 20),
          const AppSkeletonLoader(height: 200, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildDropoutCardSkeleton(BuildContext context) {
    return _buildSkeletonCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonLoader(width: 200, height: 16, borderRadius: 4),
                      SizedBox(height: 5),
                      AppSkeletonLoader(width: 140, height: 11, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              AppSkeletonLoader(width: 110, height: 30, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: AppSkeletonLoader(height: 60, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: AppSkeletonLoader(height: 60, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 20),
          const AppSkeletonLoader(height: 180, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildEquity4PsCardSkeleton(BuildContext context) {
    return _buildSkeletonCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonLoader(width: 190, height: 16, borderRadius: 4),
                      SizedBox(height: 5),
                      AppSkeletonLoader(width: 130, height: 11, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              AppSkeletonLoader(width: 110, height: 30, borderRadius: 6),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: AppSkeletonLoader(height: 60, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: AppSkeletonLoader(height: 60, borderRadius: 10)),
            ],
          ),
          SizedBox(height: 20),
          AppSkeletonLoader(height: 180, borderRadius: 10),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHART INNER SKELETON LOADER
// ════════════════════════════════════════════════════════════════
class ReportsChartSkeletonLoader extends StatelessWidget {
  final double height;
  const ReportsChartSkeletonLoader({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final h in [0.45, 0.70, 0.55, 0.85, 0.60, 0.75])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FractionallySizedBox(
                          heightFactor: h,
                          alignment: Alignment.bottomCenter,
                          child: const AppSkeletonLoader(
                            height: double.infinity,
                            borderRadius: 6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < 6; i++)
                  const AppSkeletonLoader(width: 36, height: 10, borderRadius: 3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
