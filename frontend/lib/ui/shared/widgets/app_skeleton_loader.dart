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
