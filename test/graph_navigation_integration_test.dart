import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noteassista/services/graph_navigation_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupSupabaseMocks();
  });

  tearDownAll(() {
    tearDownSupabaseMocks();
  });
  group('GraphNavigationService Integration', () {
    testWidgets('handleNavigationError shows appropriate error messages', (
      WidgetTester tester,
    ) async {
      final navigationService = GraphNavigationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    navigationService.handleNavigationError(
                      context,
                      'test-node-id',
                      Exception('permission-denied'),
                    );
                  },
                  child: const Text('Test Error'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger error handling
      await tester.tap(find.text('Test Error'));
      await tester.pump();

      // Verify that a SnackBar with error message is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('You don\'t have permission to access this note'),
        findsOneWidget,
      );
    });

    testWidgets('handleNavigationError handles different error types', (
      WidgetTester tester,
    ) async {
      final navigationService = GraphNavigationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        navigationService.handleNavigationError(
                          context,
                          'test-node-id',
                          Exception('not-found'),
                        );
                      },
                      child: const Text('Not Found Error'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        navigationService.handleNavigationError(
                          context,
                          'test-node-id',
                          Exception('unavailable'),
                        );
                      },
                      child: const Text('Unavailable Error'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        navigationService.handleNavigationError(
                          context,
                          'test-node-id',
                          Exception('unauthenticated'),
                        );
                      },
                      child: const Text('Auth Error'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Test not-found error
      await tester.tap(find.text('Not Found Error'));
      await tester.pump();
      expect(find.text('This note no longer exists'), findsOneWidget);

      // Dismiss the snackbar
      await tester.tap(find.text('Dismiss'));
      await tester.pump();

      // Test unavailable error
      await tester.tap(find.text('Unavailable Error'));
      await tester.pump();
      expect(
        find.text('Service temporarily unavailable. Please try again'),
        findsOneWidget,
      );

      // Dismiss the snackbar
      await tester.tap(find.text('Dismiss'));
      await tester.pump();

      // Test authentication error
      await tester.tap(find.text('Auth Error'));
      await tester.pump();
      expect(find.text('Please log in to access notes'), findsOneWidget);
    });

    testWidgets('handleNavigationError can be disabled', (
      WidgetTester tester,
    ) async {
      final navigationService = GraphNavigationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    navigationService.handleNavigationError(
                      context,
                      'test-node-id',
                      Exception('permission-denied'),
                      showUserMessage: false,
                    );
                  },
                  child: const Text('Test Silent Error'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger error handling
      await tester.tap(find.text('Test Silent Error'));
      await tester.pump();

      // Verify that no SnackBar is shown when showUserMessage is false
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
