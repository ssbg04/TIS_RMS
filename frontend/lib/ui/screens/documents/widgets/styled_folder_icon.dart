import 'package:flutter/material.dart';

/// A stylized tabbed folder icon matching modern desktop/mobile aesthetics
/// with JHS and SHS completion badge chips rendered directly inside the folder face.
class StyledFolderIcon extends StatelessWidget {
  final int jhsCompleted;
  final int jhsTotal;
  final int shsCompleted;
  final int shsTotal;
  final bool isMobile;
  final bool isArchived;

  const StyledFolderIcon({
    super.key,
    required this.jhsCompleted,
    required this.jhsTotal,
    required this.shsCompleted,
    required this.shsTotal,
    this.isMobile = false,
    this.isArchived = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = isMobile ? 86.0 : 98.0;
    final height = isMobile ? 58.0 : 66.0;
    final tabWidth = width * 0.44;
    final tabHeight = isMobile ? 12.0 : 14.0;
    final frontHeight = isMobile ? 48.0 : 54.0;

    final tabColor = isArchived
        ? const Color(0xFFC2410C)
        : const Color(0xFFD97706);
    final backColor = isArchived
        ? const Color(0xFFEA580C)
        : const Color(0xFFF59E0B);

    final frontColors = isArchived
        ? [const Color(0xFFFB923C), const Color(0xFFC2410C)]
        : [const Color(0xFFFBBF24), const Color(0xFFD97706)];

    final shadowColor = (isArchived
            ? const Color(0xFF9A3412)
            : const Color(0xFFB45309))
        .withValues(alpha: 0.35);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Back Tab (top-left tab of the folder)
          Positioned(
            top: 0,
            left: 3,
            child: Container(
              width: tabWidth,
              height: tabHeight + 4,
              decoration: BoxDecoration(
                color: tabColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
            ),
          ),

          // 2. Back Body Plate
          Positioned(
            top: tabHeight - 2,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: backColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // 3. Front Flap / Face of Folder
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: frontHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: frontColors,
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 5,
                    offset: const Offset(0, 2.5),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChip('JHS', jhsCompleted, jhsTotal, isJhs: true),
                        const SizedBox(width: 4),
                        _buildChip('SHS', shsCompleted, shsTotal, isJhs: false),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int done, int total, {required bool isJhs}) {
    final isComplete = total > 0 && done >= total;
    final bg = isComplete
        ? const Color(0xFF047857) // Emerald green
        : (isJhs
            ? const Color(0xFF9A3412) // Rust orange
            : const Color(0xFF1E3A8A)); // Navy blue

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '$label $done/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
