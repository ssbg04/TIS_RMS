import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Use a relative import to reliably find your main.dart file
import '../lib/main.dart';

void main() {
  testWidgets('App boots up and displays the Splash Screen', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const TisRmsApp());

    // 2. Verify that our branding text is present on the Splash Screen
    expect(find.text('TIS RMS'), findsOneWidget);
    expect(find.text('Record Management System'), findsOneWidget);

    // 3. Verify that the loading spinner is present
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Note: We don't pump the timer here because the test environment 
    // shouldn't wait for the 2.5 second simulated delay. We just want 
    // to ensure the initial widget tree renders without crashing.
  });
}