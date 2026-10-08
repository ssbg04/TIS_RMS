import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App boots up and displays the Splash Screen', (
    WidgetTester tester,
  ) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: TisRmsApp()));

    // 2. Verify that our branding text is present on the Splash Screen
    expect(find.textContaining('Talisay Integrated School'), findsWidgets);

    // Clean up active timers/animations in test harness
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
