// This is a basic Flutter widget test for the NoteAssista app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noteassista/main.dart';
import 'package:noteassista/services/reminder_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseAuthMocks();
  });

  tearDownAll(() {
    tearDownFirebaseAuthMocks();
  });

  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Create a mock reminder service for testing
    final reminderService = ReminderService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(reminderService: reminderService));

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the app launches successfully
    expect(tester.takeException(), isNull);

    // Look for common app elements
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
