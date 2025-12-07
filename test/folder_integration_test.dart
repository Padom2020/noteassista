import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/folder_model.dart';
import 'package:noteassista/models/note_model.dart';

void main() {
  group('Folder Integration Tests', () {
    test('Note model should support folderId field', () {
      final note = NoteModel(
        id: 'test-id',
        title: 'Test Note',
        description: 'Test Description',
        timestamp: '2024-01-01',
        categoryImageIndex: 0,
        isDone: false,
        folderId: 'folder-123',
      );

      expect(note.folderId, equals('folder-123'));
    });

    test('Folder model should have required fields', () {
      final folder = FolderModel(
        id: 'folder-id',
        name: 'Test Folder',
        color: '#2196F3',
        noteCount: 5,
      );

      expect(folder.id, equals('folder-id'));
      expect(folder.name, equals('Test Folder'));
      expect(folder.color, equals('#2196F3'));
      expect(folder.noteCount, equals(5));
    });

    test('Note can be created without folderId (root folder)', () {
      final note = NoteModel(
        id: 'test-id',
        title: 'Test Note',
        description: 'Test Description',
        timestamp: '2024-01-01',
        categoryImageIndex: 0,
        isDone: false,
        folderId: null, // Root folder
      );

      expect(note.folderId, isNull);
    });
  });
}
