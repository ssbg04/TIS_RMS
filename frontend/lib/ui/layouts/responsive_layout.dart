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
        final width = constraints.maxWidth;
        // Breakpoint 1: Phone viewports (< 700px) -> Mobile UI with Bottom Nav & Drawer
        if (width < 700) {
          return AndroidBottomNavLayout(userRole: userRole);
        }
        // Breakpoint 2: Tablet viewports (700px <= width < 1050px) -> Adaptive Navigation Rail
        else if (width < 1050) {
          return WindowsSidebarLayout(
            userRole: userRole,
            initialMinimized: true,
          );
        }
        // Breakpoint 3: Desktop viewports (>= 1050px) -> Permanent Expanded Sidebar
        else {
          return WindowsSidebarLayout(
            userRole: userRole,
            initialMinimized: false,
          );
        }
      },
    );
  }
}
