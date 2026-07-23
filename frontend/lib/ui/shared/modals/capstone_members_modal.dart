import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CapstoneMembersModal {
  static void show(BuildContext context) {
    const members = [
      {'name': 'Alibutod, Rhina Mhay C.', 'role': 'Technical Writer'},
      {'name': 'Antonio, Clara Maris B.', 'role': 'UI/UX Designer'},
      {'name': 'De Vera, Ermhar A.', 'role': 'System Analyst'},
      {'name': 'Ellio, James Young G.', 'role': 'Tester'},
      {'name': 'Garcia, Cris Charles V.', 'role': 'Programmer'},
      {'name': 'Pasigan, Chinee R.', 'role': 'Project Manager'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 600;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: isMobile ? MediaQuery.of(ctx).size.width * 0.9 : 800,
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
                        'assets/images/capstone_members.jpg',
                        width: double.infinity,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _buildContent(ctx, members),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Image.asset(
                          'assets/images/capstone_members.jpg',
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: _buildContent(ctx, members),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  static Widget _buildContent(
    BuildContext context,
    List<Map<String, String>> members,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.groups_rounded, color: AppColors.primaryGreen, size: 28),
            SizedBox(width: 12),
            Text(
              'Capstone Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...members.map(
          (member) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: '${member['name']} ',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: '(${member['role']})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
