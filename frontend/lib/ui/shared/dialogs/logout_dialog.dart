import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login/login_screen.dart'; 

/// A reusable function to show the logout confirmation and handle the logout process.
Future<void> showLogoutConfirmationDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, child) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Confirm Logout'),
            ],
          ),
          content: const Text('Are you sure you want to log out of your account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Close dialog
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Capture navigator before the dialog is unmounted
                final navigator = Navigator.of(context, rootNavigator: true);

                // 1. Close the dialog immediately for responsiveness
                navigator.pop();

                // 2. Remove ALL saved credentials for security
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('rememberMe');
                await prefs.remove('saved_username');
                await prefs.remove('saved_password');

                // 3. Navigate FIRST to LoginScreen and destroy routing history.
                //    This unmounts all active screens BEFORE providers are invalidated,
                //    preventing "ref used after unmount" / ProviderException errors
                //    when logging out from non-dashboard tabs.
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );

                // 4. Wait for the route transition animation to finish.
                //    This guarantees the old screens are fully unmounted before their
                //    providers are invalidated, preventing "used after unmount" or 
                //    "multiple tickers" exceptions during the transition.
                await Future.delayed(const Duration(milliseconds: 500));

                // 5. Invalidate all persistent providers safely in the background.
                await ref.read(authProvider.notifier).logout();
              },
              child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}