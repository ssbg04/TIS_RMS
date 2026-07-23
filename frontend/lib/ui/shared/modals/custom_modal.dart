import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CustomModal extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget>? headerActions;
  final double maxWidth;
  final VoidCallback? onClose;

  const CustomModal({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.headerActions,
    this.maxWidth = 620,
    this.onClose,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget content,
    List<Widget>? headerActions,
    double maxWidth = 620,
    VoidCallback? onClose,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => CustomModal(
        title: title,
        icon: icon,
        content: content,
        headerActions: headerActions,
        maxWidth: maxWidth,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          color: AppColors.pageBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal header ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (headerActions != null) ...headerActions!,
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ── Modal body ──
              Flexible(child: content),
            ],
          ),
        ),
      ),
    );
  }
}
