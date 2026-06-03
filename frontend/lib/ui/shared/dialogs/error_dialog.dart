import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// A reusable function to show a standardized, animated error dialog.
void showErrorDialog(
  BuildContext context,
  String title,
  String message, {
  String buttonLabel = 'TRY AGAIN',
  VoidCallback? onDismissed,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _ErrorDialog(
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      onDismissed: onDismissed,
    ),
  );
}

class _ErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onDismissed;

  const _ErrorDialog({
    required this.title,
    required this.message,
    required this.buttonLabel,
    this.onDismissed,
  });

  @override
  State<_ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<_ErrorDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5)),
    );
    // Subtle horizontal shake on entry
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(0.015, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(0.015, 0), end: const Offset(-0.015, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.015, 0), end: const Offset(0.01, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(0.01, 0), end: Offset.zero),
          weight: 1),
    ]).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.3, 0.85, curve: Curves.linear)));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: SlideTransition(
          position: _shakeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // — Top accent bar —
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade300,
                          AppColors.error,
                          Colors.red.shade900,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSizes.radiusLarge),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      children: [
                        // — Error icon —
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.error.withValues(alpha: 0.18),
                                AppColors.error.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // — Title —
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // — Message —
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // — Buttons row: Dismiss + Try Again —
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(
                                      color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMedium),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'DISMISS',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMedium),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onDismissed?.call();
                                },
                                child: Text(
                                  widget.buttonLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}