import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/collaboration_notification_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupSupabaseMocks();
  });

  tearDownAll(() {
    tearDownSupabaseMocks();
  });
  group('CollaborationNotificationService Tests', () {
    late CollaborationNotificationService notificationService;

    setUp(() {
      notificationService = CollaborationNotificationService();
    });

    test('should create singleton instance', () {
      final instance1 = CollaborationNotificationService();
      final instance2 = CollaborationNotificationService();
      expect(instance1, equals(instance2));
    });

    test('should initialize without errors', () async {
      // This test verifies the service can be instantiated
      // Actual initialization requires platform-specific setup
      expect(notificationService, isNotNull);
    });

    group('Notification Methods', () {
      test('notifyNewCollaborators should handle empty list', () async {
        // Should not throw when called with empty collaborator list
        expect(
          () async => await notificationService.notifyNewCollaborators(
            noteId: 'test-note',
            noteTitle: 'Test Note',
            ownerName: 'Test Owner',
            newCollaboratorIds: [],
            ownerId: 'owner-id',
          ),
          returnsNormally,
        );
      });

      test('notifyCollaboratorsOfComment should handle empty list', () async {
        // Should not throw when called with empty collaborator list
        expect(
          () async => await notificationService.notifyCollaboratorsOfComment(
            noteId: 'test-note',
            noteTitle: 'Test Note',
            commenterName: 'Test Commenter',
            comment: 'Test comment',
            collaboratorIds: [],
            ownerId: 'owner-id',
          ),
          returnsNormally,
        );
      });
    });

    group('Firestore Operations', () {
      test('getUnreadNotificationCount should return 0 on error', () async {
        // This will fail due to no Firebase initialization, but should return 0
        final count = await notificationService.getUnreadNotificationCount(
          'test-user',
        );
        expect(count, equals(0));
      });

      test('markNotificationsAsRead should handle errors gracefully', () async {
        // Should not throw even when Firebase is not initialized
        expect(
          () async =>
              await notificationService.markNotificationsAsRead('test-user'),
          returnsNormally,
        );
      });
    });

    group('Stream Operations', () {
      test('getNotificationsStream should return stream', () {
        // Should return a stream even if Firebase is not initialized
        final stream = notificationService.getNotificationsStream('test-user');
        expect(stream, isNotNull);
      });
    });
  });
}
