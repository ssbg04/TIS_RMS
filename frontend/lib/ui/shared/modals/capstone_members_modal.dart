import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CapstoneMembersModal {
  static void show(BuildContext context) {
    const members = [
      'Alibutod, Rhina Mhay C.',
      'Antonio, Clara Maris B.',
      'De Vera, Ermhar A.',
      'Ellio, James Young G.',
      'Garcia, Cris Charles V.',
      'Pasigan, Chinee R.',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 600;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: isMobile ? MediaQuery.of(ctx).size.width * 0.9 : 700,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: isMobile
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/capstone_members.jpeg',
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _buildContent(ctx, members),
                      ),
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Image.asset(
                            'assets/images/capstone_members.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: _buildContent(ctx, members),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  static Widget _buildContent(BuildContext context, List<String> members) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.groups_rounded, color: AppColors.primaryGreen, size: 28),
            SizedBox(width: 12),
            Text('Capstone Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        ...members.map((name) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 15))),
            ],
          ),
        )),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
