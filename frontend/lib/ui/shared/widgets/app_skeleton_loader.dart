import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/theme_extension.dart';

class AppSkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = AppSizes.radiusMedium,
  });

  @override
  State<AppSkeletonLoader> createState() => _AppSkeletonLoaderState();
}

class _AppSkeletonLoaderState extends State<AppSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSizes.durationNormal * 3,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final baseColor = isDark ? AppColors.darkSurface2 : Colors.grey.shade300;
    final highlightColor = isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(baseColor, highlightColor, 0.5),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class CardSkeletonLoader extends StatelessWidget {
  final int count;
  const CardSkeletonLoader({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      children: List.generate(
        count,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: AppSizes.p12),
          padding: const EdgeInsets.all(AppSizes.p16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
          ),
          child: const Row(
            children: [
              AppSkeletonLoader(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLoader(width: 140, height: 14),
                    SizedBox(height: AppSizes.p8),
                    AppSkeletonLoader(width: 200, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListSkeletonLoader extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ListSkeletonLoader({
    super.key,
    this.count = 6,
    this.itemHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.p16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Container(
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: const Row(
          children: [
            AppSkeletonLoader(width: 32, height: 32, borderRadius: 8),
            SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: AppSkeletonLoader(height: 14, borderRadius: 4),
            ),
            SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: AppSkeletonLoader(height: 12, borderRadius: 4),
            ),
            SizedBox(width: 20),
            AppSkeletonLoader(width: 60, height: 22, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

class FolderSkeletonLoader extends StatelessWidget {
  final int count;

  const FolderSkeletonLoader({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600
            ? 1
            : constraints.maxWidth < 900
                ? 2
                : constraints.maxWidth < 1300
                    ? 3
                    : 4;

        return GridView.builder(
          padding: const EdgeInsets.all(AppSizes.p16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.1,
          ),
          itemCount: count,
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppSkeletonLoader(width: 48, height: 48, borderRadius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppSkeletonLoader(width: 130, height: 15, borderRadius: 4),
                      SizedBox(height: 8),
                      AppSkeletonLoader(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                AppSkeletonLoader(width: 28, height: 28, borderRadius: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DocumentListSkeletonLoader extends StatelessWidget {
  final int count;
  final bool isFolder;

  const DocumentListSkeletonLoader({
    super.key,
    this.count = 8,
    this.isFolder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 12 : 16,
        right: isMobile ? 12 : 16,
        top: isMobile ? 8 : 16,
        bottom: isMobile ? 6 : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: isMobile
            ? Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              )
            : null,
        boxShadow: isMobile
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
          ),
          itemBuilder: (ctx, i) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              child: Row(
                children: [
                  AppSkeletonLoader(
                    width: 40,
                    height: 40,
                    borderRadius: isFolder ? 10 : 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSkeletonLoader(
                          width: i % 3 == 0
                              ? 180
                              : i % 3 == 1
                                  ? 130
                                  : 220,
                          height: 13,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AppSkeletonLoader(
                              width: isFolder ? 70 : 90,
                              height: 10,
                              borderRadius: 4,
                            ),
                            if (!isFolder) ...[
                              const SizedBox(width: 8),
                              const AppSkeletonLoader(
                                width: 50,
                                height: 10,
                                borderRadius: 4,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isFolder)
                    const AppSkeletonLoader(
                      width: 18,
                      height: 18,
                      borderRadius: 9,
                    )
                  else
                    const AppSkeletonLoader(
                      width: 65,
                      height: 22,
                      borderRadius: 6,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class DashboardSkeletonLoader extends StatelessWidget {
  const DashboardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 16 : 20,
        isMobile ? 16 : 24,
        isMobile ? 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLoader(width: 180, height: 24, borderRadius: 6),
                  SizedBox(height: 8),
                  AppSkeletonLoader(width: 240, height: 13, borderRadius: 4),
                ],
              ),
              if (!isMobile)
                const Row(
                  children: [
                    AppSkeletonLoader(width: 110, height: 36, borderRadius: 8),
                    SizedBox(width: 10),
                    AppSkeletonLoader(width: 36, height: 36, borderRadius: 8),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI cards grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 600
                  ? 2
                  : (constraints.maxWidth < 1050 ? 2 : 4);
              const spacing = 12.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(4, (_) {
                  return Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.borderLight,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSkeletonLoader(
                              width: 85,
                              height: 12,
                              borderRadius: 4,
                            ),
                            AppSkeletonLoader(
                              width: 34,
                              height: 34,
                              borderRadius: 10,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        AppSkeletonLoader(
                          width: 64,
                          height: 26,
                          borderRadius: 6,
                        ),
                        SizedBox(height: 8),
                        AppSkeletonLoader(
                          width: 110,
                          height: 11,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 20),

          // Charts / Activity cards
          if (isMobile) ...[
            _buildSectionPlaceholder(isDark, height: 220),
            const SizedBox(height: 16),
            _buildListCardPlaceholder(isDark, rows: 4),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildSectionPlaceholder(isDark, height: 300),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _buildListCardPlaceholder(isDark, rows: 5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionPlaceholder(bool isDark, {required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 160, height: 16, borderRadius: 4),
              AppSkeletonLoader(width: 80, height: 26, borderRadius: 8),
            ],
          ),
          SizedBox(height: 18),
          Expanded(
            child: AppSkeletonLoader(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCardPlaceholder(bool isDark, {required int rows}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeletonLoader(width: 150, height: 16, borderRadius: 4),
          const SizedBox(height: 16),
          ...List.generate(rows, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
              child: const Row(
                children: [
                  AppSkeletonLoader(width: 34, height: 34, borderRadius: 17),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonLoader(
                          width: 140,
                          height: 13,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 6),
                        AppSkeletonLoader(
                          width: 90,
                          height: 10,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  AppSkeletonLoader(width: 48, height: 12, borderRadius: 4),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class UsersSkeletonLoader extends StatelessWidget {
  const UsersSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top header row
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLoader(width: 170, height: 24, borderRadius: 6),
                SizedBox(height: 6),
                AppSkeletonLoader(width: 220, height: 13, borderRadius: 4),
              ],
            ),
            AppSkeletonLoader(width: 110, height: 38, borderRadius: 10),
          ],
        ),
        const SizedBox(height: 16),

        // Summary KPI strip
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth < 600 ? 2 : 4;
            const spacing = 10.0;
            final cardW =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(4, (_) {
                return Container(
                  width: cardW,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.borderLight,
                    ),
                  ),
                  child: const Row(
                    children: [
                      AppSkeletonLoader(
                        width: 34,
                        height: 34,
                        borderRadius: 9,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonLoader(
                              width: 55,
                              height: 10,
                              borderRadius: 4,
                            ),
                            SizedBox(height: 6),
                            AppSkeletonLoader(
                              width: 36,
                              height: 18,
                              borderRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 16),

        // Search & filter bar
        Row(
          children: [
            const Expanded(
              child: AppSkeletonLoader(height: 42, borderRadius: 10),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 12),
              const AppSkeletonLoader(width: 120, height: 42, borderRadius: 10),
              const SizedBox(width: 10),
              const AppSkeletonLoader(width: 120, height: 42, borderRadius: 10),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // User rows card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: isMobile ? 6 : 8,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
              ),
              itemBuilder: (_, index) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const AppSkeletonLoader(
                      width: 38,
                      height: 38,
                      borderRadius: 19,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonLoader(
                            width: index.isEven ? 150 : 120,
                            height: 13,
                            borderRadius: 4,
                          ),
                          const SizedBox(height: 6),
                          const AppSkeletonLoader(
                            width: 180,
                            height: 10,
                            borderRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 16),
                      const AppSkeletonLoader(
                        width: 72,
                        height: 22,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 16),
                      const AppSkeletonLoader(
                        width: 68,
                        height: 22,
                        borderRadius: 12,
                      ),
                    ],
                    const SizedBox(width: 12),
                    const AppSkeletonLoader(
                      width: 28,
                      height: 28,
                      borderRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
