import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/widgets/folder_tree_view.dart';
import 'package:noteassista/models/folder_model.dart';

void main() {
  group('FolderListTile Widget Tests', () {
    testWidgets('displays "All Notes" for null folder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: null, isSelected: false, level: 0),
          ),
        ),
      );

      expect(find.text('All Notes'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('displays folder name and icon', (tester) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        noteCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: false, level: 0),
          ),
        ),
      );

      expect(find.text('Test Folder'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('displays note count badge when noteCount > 0', (tester) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        noteCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: false, level: 0),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does not display note count badge when noteCount is 0', (
      tester,
    ) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: false, level: 0),
          ),
        ),
      );

      // Note count badge should not be visible
      expect(find.text('0'), findsNothing);
    });

    testWidgets('displays favorite star icon for favorite folders', (
      tester,
    ) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Favorite Folder',
        color: '#2196F3',
        noteCount: 3,
        isFavorite: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: false, level: 0),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder_special), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('displays expand icon when hasChildren is true', (
      tester,
    ) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Parent Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(
              folder: folder,
              isSelected: false,
              hasChildren: true,
              isExpanded: false,
              level: 0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('displays collapse icon when expanded', (tester) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Parent Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(
              folder: folder,
              isSelected: false,
              hasChildren: true,
              isExpanded: true,
              level: 0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('applies indentation based on level', (tester) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Nested Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: false, level: 2),
          ),
        ),
      );

      // Find the container with padding
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );

      final padding = container.padding as EdgeInsets;
      // Level 2 should have 16 + (2 * 24) = 64 left padding
      expect(padding.left, 64.0);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(
              folder: folder,
              isSelected: false,
              level: 0,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('calls onExpandToggle when expand button tapped', (
      tester,
    ) async {
      bool toggleCalled = false;
      final folder = FolderModel(
        id: 'test-id',
        name: 'Parent Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(
              folder: folder,
              isSelected: false,
              hasChildren: true,
              isExpanded: false,
              level: 0,
              onExpandToggle: () {
                toggleCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap on the chevron icon specifically
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(toggleCalled, true);
    });

    testWidgets('shows selected state with border and background', (
      tester,
    ) async {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Selected Folder',
        color: '#2196F3',
        noteCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderListTile(folder: folder, isSelected: true, level: 0),
          ),
        ),
      );

      // Find the container with decoration
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNotNull);
    });
  });
}
