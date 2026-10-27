import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/dashboard_card_config.dart';

class DashboardCustomizeBanner extends StatelessWidget {
  final List<DashboardCardConfig> hiddenCards;
  final VoidCallback onReset;
  final VoidCallback onDone;
  final ValueChanged<String> onRestoreCard;

  const DashboardCustomizeBanner({
    super.key,
    required this.hiddenCards,
    required this.onReset,
    required this.onDone,
    required this.onRestoreCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 700 ||
        Theme.of(context).platform == TargetPlatform.android;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize Dashboard',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Reorder cards, hide, or restore cards.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hiddenCards.isNotEmpty) _buildHiddenCardsButton(context),
                    _buildResetButton(context, isDark),
                    _buildDoneButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard Customization Mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Drag handles or use arrow buttons to reorder. Toggle card width between 50% and 100%, or hide unwanted cards.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (hiddenCards.isNotEmpty) ...[
                  _buildHiddenCardsButton(context),
                  const SizedBox(width: 8),
                ],
                _buildResetButton(context, isDark),
                const SizedBox(width: 8),
                _buildDoneButton(),
              ],
            ),
    );
  }

  Widget _buildHiddenCardsButton(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Restore hidden cards',
      onSelected: onRestoreCard,
      itemBuilder: (context) => hiddenCards
          .map(
            (card) => PopupMenuItem<String>(
              value: card.id,
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text('Restore ${card.title}'),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 15,
              color: Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              'Hidden (${hiddenCards.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.shade300;

    return OutlinedButton.icon(
      icon: Icon(
        Icons.restart_alt_rounded,
        size: 16,
        color: textColor,
      ),
      label: Text(
        'Reset',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Dashboard Layout?'),
            content: const Text(
              'This will restore all cards to their default sequence, set their width to 100%, and unhide any hidden cards.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onReset();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDoneButton() {
    return FilledButton.icon(
      icon: const Icon(Icons.check_rounded, size: 16),
      label: const Text('Done'),
      onPressed: onDone,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
