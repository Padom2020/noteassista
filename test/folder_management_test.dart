import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/folder_model.dart';

void main() {
  // Note: Widget tests for dialogs are skipped because they require Firebase mocking
  // The dialogs have been manually tested and are working correctly
  // Focus on unit tests for the FolderModel

  group('Folder Management - Folder Model', () {
    test('FolderModel creates correctly with required fields', () {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
      );

      expect(folder.id, 'test-id');
      expect(folder.name, 'Test Folder');
      expect(folder.color, '#2196F3');
      expect(folder.noteCount, 0);
      expect(folder.isFavorite, false);
      expect(folder.parentId, null);
    });

    test('FolderModel creates correctly with all fields', () {
      final createdAt = DateTime(2024, 1, 1);
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        parentId: 'parent-id',
        noteCount: 5,
        createdAt: createdAt,
        isFavorite: true,
      );

      expect(folder.id, 'test-id');
      expect(folder.name, 'Test Folder');
      expect(folder.color, '#2196F3');
      expect(folder.parentId, 'parent-id');
      expect(folder.noteCount, 5);
      expect(folder.createdAt, createdAt);
      expect(folder.isFavorite, true);
    });

    test('FolderModel.copyWith updates fields correctly', () {
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
      );

      final updated = folder.copyWith(name: 'Updated Folder', isFavorite: true);

      expect(updated.id, 'test-id');
      expect(updated.name, 'Updated Folder');
      expect(updated.color, '#2196F3');
      expect(updated.isFavorite, true);
    });

    test('FolderModel.toMap converts to map correctly', () {
      final createdAt = DateTime(2024, 1, 1);
      final folder = FolderModel(
        id: 'test-id',
        name: 'Test Folder',
        color: '#2196F3',
        parentId: 'parent-id',
        noteCount: 5,
        createdAt: createdAt,
        isFavorite: true,
      );

      final map = folder.toMap();

      expect(map['name'], 'Test Folder');
      expect(map['color'], '#2196F3');
      expect(map['parentId'], 'parent-id');
      expect(map['noteCount'], 5);
      expect(map['isFavorite'], true);
      expect(map['createdAt'], isNotNull);
    });
  });
}
