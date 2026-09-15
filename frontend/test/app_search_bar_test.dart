import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/ui/shared/inputs/app_search_bar.dart';
import 'package:frontend/ui/providers/search_history_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_search_history': '["test item 1", "test item 2"]',
    });
  });

  test('SearchHistoryNotifier loads, adds, removes, and clears history', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(searchHistoryProvider), isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    final history = container.read(searchHistoryProvider);
    expect(history, containsAll(['test item 1', 'test item 2']));

    await container.read(searchHistoryProvider.notifier).addSearch('new item');
    expect(container.read(searchHistoryProvider).first, equals('new item'));

    await container.read(searchHistoryProvider.notifier).removeSearch('test item 1');
    expect(container.read(searchHistoryProvider), isNot(contains('test item 1')));

    await container.read(searchHistoryProvider.notifier).clearHistory();
    expect(container.read(searchHistoryProvider), isEmpty);
  });

  testWidgets('AppSearchBar displays history overlay on focus and supports clear all', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(searchHistoryProvider);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchBar(
                hint: 'Search test...',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Tap search bar to focus
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Verify history overlay is displayed
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('test item 1'), findsOneWidget);
    expect(find.text('test item 2'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    // Tap Clear all
    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 50));

    // History is now cleared and overlay closes
    expect(container.read(searchHistoryProvider), isEmpty);
    expect(find.text('Recent Searches'), findsNothing);
  });

  testWidgets('AppSearchBar individual item deletion removes item and keeps overlay open', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(searchHistoryProvider);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchBar(
                hint: 'Search test...',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Open overlay
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('test item 1'), findsOneWidget);
    expect(find.text('test item 2'), findsOneWidget);

    // Find the close buttons on history items
    final closeIcons = find.byIcon(Icons.close_rounded);
    expect(closeIcons, findsWidgets);

    // Tap the first history item close button
    await tester.tap(closeIcons.first);
    await tester.pump(const Duration(milliseconds: 50));

    // Item 1 was removed, Item 2 remains, overlay remains open
    expect(container.read(searchHistoryProvider), isNot(contains('test item 1')));
    expect(container.read(searchHistoryProvider), contains('test item 2'));
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('test item 2'), findsOneWidget);
  });

  testWidgets('AppSearchBar pressing escape closes overlay', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(searchHistoryProvider);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchBar(
                hint: 'Search test...',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Focus to open overlay
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Recent Searches'), findsOneWidget);

    // Press Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));

    // Overlay is dismissed
    expect(find.text('Recent Searches'), findsNothing);
  });

  testWidgets('AppSearchBar inside showDialog supports clear all and item deletion', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(searchHistoryProvider);
    await tester.pump(const Duration(milliseconds: 100));

    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (ctx) {
                        return Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                            child: Material(
                              child: AppSearchBar(
                                controller: searchController,
                                focusNode: searchFocusNode,
                                collapsible: false,
                                hint: 'Search students by LRN or Name...',
                                maxWidth: 600,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    searchFocusNode.requestFocus();
                  },
                  child: const Text('Open Search Dialog'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Open Search Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('test item 1'), findsOneWidget);
    expect(find.text('test item 2'), findsOneWidget);

    // Find the close buttons in the history list
    final closeIcons = find.byIcon(Icons.close_rounded);
    expect(closeIcons, findsWidgets);

    // Tap the first history item's delete button
    await tester.tap(closeIcons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Item 1 should be removed, item 2 should still be there, and overlay should remain open!
    expect(container.read(searchHistoryProvider), isNot(contains('test item 1')));
    expect(container.read(searchHistoryProvider), contains('test item 2'));
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('test item 2'), findsOneWidget);

    // Tap Clear all
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    // All items cleared and overlay closed
    expect(container.read(searchHistoryProvider), isEmpty);
    expect(find.text('Recent Searches'), findsNothing);
  });
}


