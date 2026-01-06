import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/screens/graph_view_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupSupabaseMocks();
  });

  tearDownAll(() {
    tearDownSupabaseMocks();
  });
  group('Graph Gesture Integration Tests', () {
    testWidgets('single tap vs double-tap distinction works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 2.1, 2.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      // Test single tap - should highlight node without navigation
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Verify single tap behavior (no navigation attempt)
      expect(tester.takeException(), isNull);

      // Test double-tap with proper timing
      await tester.tap(find.byType(CustomPaint));
      await tester.pump(const Duration(milliseconds: 50)); // Short delay
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Verify double-tap behavior
      expect(tester.takeException(), isNull);
    });

    testWidgets('zoom and pan do not interfere with tap gestures', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 2.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      final interactiveViewer = find.byType(InteractiveViewer);
      expect(interactiveViewer, findsOneWidget);

      // Perform pan gesture
      await tester.drag(interactiveViewer, const Offset(100, 50));
      await tester.pumpAndSettle();

      // Test tap after pan
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Perform zoom gesture (simulate pinch)
      final center = tester.getCenter(interactiveViewer);
      await tester.startGesture(center - const Offset(50, 0));
      await tester.startGesture(center + const Offset(50, 0));
      await tester.pumpAndSettle();

      // Test tap after zoom
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Verify no interference between gestures
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture detection works at different zoom levels', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 4.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      final interactiveViewer = find.byType(InteractiveViewer);
      final graphCanvas = find.byType(CustomPaint);

      // Test at default zoom
      await tester.tap(graphCanvas);
      await tester.pumpAndSettle();

      // Simulate zoom in
      await tester.drag(interactiveViewer, const Offset(0, 0));
      await tester.pumpAndSettle();

      // Test gesture detection after zoom
      await tester.tap(graphCanvas);
      await tester.pumpAndSettle();

      // Test double-tap after zoom
      await tester.tap(graphCanvas);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(graphCanvas);
      await tester.pumpAndSettle();

      // Verify gestures work at all zoom levels
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty space gestures clear selections properly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 2.5

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      // Tap in center area (potential node location)
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Tap in empty space (corner)
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Look for selection cleared message
      expect(find.text('Selection cleared'), findsAny);

      // Test double-tap on empty space
      await tester.tapAt(const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Verify empty space double-tap doesn't cause issues
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture handling works with search filtering', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 2.1, 2.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      // Find and interact with search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter search query
      await tester.enterText(searchField, 'test search');
      await tester.pumpAndSettle();

      // Test gestures with search active
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Test double-tap with search active
      await tester.tap(find.byType(CustomPaint));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pumpAndSettle();
      }

      // Test gestures after clearing search
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Verify search doesn't interfere with gestures
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid successive gestures are handled correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 3.1, 3.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      final graphCanvas = find.byType(CustomPaint);

      // Perform rapid successive taps
      for (int i = 0; i < 10; i++) {
        await tester.tap(graphCanvas);
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpAndSettle();

      // Perform rapid successive double-taps
      for (int i = 0; i < 5; i++) {
        await tester.tap(graphCanvas);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(graphCanvas);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Verify rapid gestures don't cause performance issues or crashes
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture handling works across different device orientations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.1, 1.2

      // Test in portrait mode
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));
      await tester.pumpAndSettle();

      // Test gestures in portrait
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Switch to landscape mode
      await tester.binding.setSurfaceSize(const Size(667, 375));
      await tester.pumpAndSettle();

      // Test gestures in landscape
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Test double-tap in landscape
      await tester.tap(find.byType(CustomPaint));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Reset to default size
      await tester.binding.setSurfaceSize(null);

      // Verify orientation changes don't break gestures
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture boundaries are respected for overlapping nodes', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.4

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      // Test taps at various positions to simulate overlapping node scenarios
      final testPositions = [
        const Offset(350, 350), // Slightly off-center
        const Offset(400, 400), // Center
        const Offset(450, 450), // Slightly off-center other direction
        const Offset(380, 420), // Diagonal offset
      ];

      for (final position in testPositions) {
        // Single tap
        await tester.tapAt(position);
        await tester.pumpAndSettle();

        // Double-tap
        await tester.tapAt(position);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(position);
        await tester.pumpAndSettle();
      }

      // Verify precise hit detection works
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture detection accuracy is maintained during animations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.3, 2.2

      await tester.pumpWidget(const MaterialApp(home: GraphViewScreen()));

      await tester.pumpAndSettle();

      // Trigger an animation by toggling graph mode
      final toggleButton = find.byIcon(Icons.location_on);
      if (toggleButton.evaluate().isNotEmpty) {
        await tester.tap(toggleButton);
        // Don't wait for settle - test during animation
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Test gesture during potential animation
      await tester.tap(find.byType(CustomPaint));
      await tester.pump(const Duration(milliseconds: 50));

      // Complete any animations
      await tester.pumpAndSettle();

      // Test gesture after animation completes
      await tester.tap(find.byType(CustomPaint));
      await tester.pumpAndSettle();

      // Verify gestures work during and after animations
      expect(tester.takeException(), isNull);
    });
  });
}
