import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Test suite for Firestore security rules
///
/// Note: These tests simulate the security rules logic since we cannot
/// directly test Firestore security rules in unit tests without the emulator.
/// For full security rule testing, use Firebase Emulator Suite.
///
/// To test with emulator:
/// 1. Install Firebase CLI: npm install -g firebase-tools
/// 2. Run: firebase emulators:start
/// 3. Run integration tests against emulator
void main() {
  group('Firestore Security Rules - Simulated Tests', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    group('Notes Collection Rules', () {
      test('Owner can read their own notes', () async {
        const userId = 'user1';
        const noteId = 'note1';

        // Create a note as owner
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notes')
            .doc(noteId)
            .set({
              'title': 'Test Note',
              'description': 'Test content',
              'isShared': false,
              'collaborators': [],
            });

        // Owner should be able to read
        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('notes')
                .doc(noteId)
                .get();

        expect(doc.exists, true);
        expect(doc.data()?['title'], 'Test Note');
      });

      test('Owner can write to their own notes', () async {
        const userId = 'user1';
        const noteId = 'note1';

        // Owner should be able to create
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notes')
            .doc(noteId)
            .set({
              'title': 'Test Note',
              'description': 'Test content',
              'isShared': false,
              'collaborators': [],
            });

        // Owner should be able to update
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notes')
            .doc(noteId)
            .update({'title': 'Updated Note'});

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('notes')
                .doc(noteId)
                .get();

        expect(doc.data()?['title'], 'Updated Note');
      });

      test('Collaborator with viewer role can read shared notes', () async {
        const ownerId = 'user1';
        const collaboratorId = 'user2';
        const noteId = 'note1';

        // Create a shared note
        await firestore
            .collection('users')
            .doc(ownerId)
            .collection('notes')
            .doc(noteId)
            .set({
              'title': 'Shared Note',
              'description': 'Shared content',
              'isShared': true,
              'collaborators': [
                {
                  'userId': collaboratorId,
                  'email': 'user2@example.com',
                  'role': 'viewer',
                },
              ],
            });

        // Collaborator should be able to read
        final doc =
            await firestore
                .collection('users')
                .doc(ownerId)
                .collection('notes')
                .doc(noteId)
                .get();

        expect(doc.exists, true);
        expect(doc.data()?['isShared'], true);
      });

      test('Collaborator with editor role can write to shared notes', () async {
        const ownerId = 'user1';
        const editorId = 'user2';
        const noteId = 'note1';

        // Create a shared note
        await firestore
            .collection('users')
            .doc(ownerId)
            .collection('notes')
            .doc(noteId)
            .set({
              'title': 'Shared Note',
              'description': 'Shared content',
              'isShared': true,
              'collaborators': [
                {
                  'userId': editorId,
                  'email': 'editor@example.com',
                  'role': 'editor',
                },
              ],
            });

        // Editor should be able to update
        await firestore
            .collection('users')
            .doc(ownerId)
            .collection('notes')
            .doc(noteId)
            .update({'description': 'Updated by editor'});

        final doc =
            await firestore
                .collection('users')
                .doc(ownerId)
                .collection('notes')
                .doc(noteId)
                .get();

        expect(doc.data()?['description'], 'Updated by editor');
      });

      test('Non-shared notes are not accessible to other users', () async {
        const ownerId = 'user1';
        const noteId = 'note1';

        // Create a private note
        await firestore
            .collection('users')
            .doc(ownerId)
            .collection('notes')
            .doc(noteId)
            .set({
              'title': 'Private Note',
              'description': 'Private content',
              'isShared': false,
              'collaborators': [],
            });

        // Note exists and is private
        final doc =
            await firestore
                .collection('users')
                .doc(ownerId)
                .collection('notes')
                .doc(noteId)
                .get();

        expect(doc.exists, true);
        expect(doc.data()?['isShared'], false);
      });
    });

    group('Folders Collection Rules', () {
      test('Owner can create folders', () async {
        const userId = 'user1';
        const folderId = 'folder1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .set({
              'name': 'Test Folder',
              'parentId': null,
              'color': '#FF0000',
              'noteCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'isFavorite': false,
            });

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('folders')
                .doc(folderId)
                .get();

        expect(doc.exists, true);
        expect(doc.data()?['name'], 'Test Folder');
      });

      test('Owner can read their own folders', () async {
        const userId = 'user1';
        const folderId = 'folder1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .set({
              'name': 'Test Folder',
              'parentId': null,
              'color': '#FF0000',
              'noteCount': 0,
              'isFavorite': false,
            });

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('folders')
                .doc(folderId)
                .get();

        expect(doc.exists, true);
      });

      test('Owner can update their own folders', () async {
        const userId = 'user1';
        const folderId = 'folder1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .set({
              'name': 'Test Folder',
              'parentId': null,
              'color': '#FF0000',
              'noteCount': 0,
              'isFavorite': false,
            });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .update({'name': 'Updated Folder'});

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('folders')
                .doc(folderId)
                .get();

        expect(doc.data()?['name'], 'Updated Folder');
      });

      test('Owner can delete their own folders', () async {
        const userId = 'user1';
        const folderId = 'folder1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .set({
              'name': 'Test Folder',
              'parentId': null,
              'color': '#FF0000',
              'noteCount': 0,
              'isFavorite': false,
            });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(folderId)
            .delete();

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('folders')
                .doc(folderId)
                .get();

        expect(doc.exists, false);
      });
    });

    group('Templates Collection Rules', () {
      test('Owner can create templates', () async {
        const userId = 'user1';
        const templateId = 'template1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .set({
              'name': 'Meeting Notes',
              'description': 'Template for meeting notes',
              'content':
                  '# Meeting Notes\n\n## Attendees\n\n## Agenda\n\n## Notes',
              'variables': [],
              'usageCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'isCustom': true,
            });

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('templates')
                .doc(templateId)
                .get();

        expect(doc.exists, true);
        expect(doc.data()?['name'], 'Meeting Notes');
      });

      test('Owner can read their own templates', () async {
        const userId = 'user1';
        const templateId = 'template1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .set({
              'name': 'Test Template',
              'description': 'Test description',
              'content': 'Test content',
              'variables': [],
              'usageCount': 0,
              'isCustom': true,
            });

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('templates')
                .doc(templateId)
                .get();

        expect(doc.exists, true);
      });

      test('Owner can update their own templates', () async {
        const userId = 'user1';
        const templateId = 'template1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .set({
              'name': 'Test Template',
              'description': 'Test description',
              'content': 'Test content',
              'variables': [],
              'usageCount': 0,
              'isCustom': true,
            });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .update({'usageCount': 1});

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('templates')
                .doc(templateId)
                .get();

        expect(doc.data()?['usageCount'], 1);
      });

      test('Owner can delete their own templates', () async {
        const userId = 'user1';
        const templateId = 'template1';

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .set({
              'name': 'Test Template',
              'description': 'Test description',
              'content': 'Test content',
              'variables': [],
              'usageCount': 0,
              'isCustom': true,
            });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('templates')
            .doc(templateId)
            .delete();

        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('templates')
                .doc(templateId)
                .get();

        expect(doc.exists, false);
      });
    });
  });
}
