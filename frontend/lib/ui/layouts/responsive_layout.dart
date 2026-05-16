import 'package:flutter/material.dart';
import 'android_bottom_nav_layout.dart';
import 'windows_sidebar_layout.dart';

class ResponsiveLayout extends StatelessWidget {
  final String userRole; // Keep passing this from your Auth State

  const ResponsiveLayout({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint: If width is less than 800px, serve Mobile/Android UI
        if (constraints.maxWidth < 800) {
          return AndroidBottomNavLayout(userRole: userRole);
        } 
        // Breakpoint: If width is 800px or larger, serve Desktop/Windows UI
        else {
          return WindowsSidebarLayout(userRole: userRole);
        }
      },
    );
  }
}