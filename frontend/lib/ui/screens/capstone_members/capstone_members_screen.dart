import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class CapstoneMembersScreen extends StatelessWidget {
  const CapstoneMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const members = [
      {'name': 'Alibutod, Rhina Mhay C.', 'role': 'Technical Writer', 'email': 'rhina@example.com'},
      {'name': 'Antonio, Clara Maris B.', 'role': 'UI/UX Designer', 'email': 'clara@example.com'},
      {'name': 'De Vera, Ermhar A.', 'role': 'System Analyst', 'email': 'ermhar@example.com'},
      {'name': 'Ellio, James Young G.', 'role': 'Tester', 'email': 'james@example.com'},
      {'name': 'Garcia, Cris Charles V.', 'role': 'Programmer', 'email': 'cris@example.com'},
      {'name': 'Pasigan, Chinee R.', 'role': 'Project Manager', 'email': 'chinee@example.com'},
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Capstone 1-2'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
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
                const Text(
                  'Capstone 1-2 Project Team',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/capstone_members.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: AppColors.primaryGreen, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Capstone Members',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...members.map(
                  (member) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                        child: const Icon(Icons.person, color: AppColors.primaryGreen),
                      ),
                      title: Text(
                        member['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            member['role']!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                member['email']!,
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ],
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
