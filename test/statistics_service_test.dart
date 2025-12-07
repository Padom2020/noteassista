import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:noteassista/services/statistics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('StatisticsService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late StatisticsService statisticsService;
    const testUserId = 'test-user-123';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      statisticsService = StatisticsService(firestore: fakeFirestore);
    });

    test(
      'calculateStatistics returns empty stats for user with no notes',
      () async {
        final stats = await statisticsService.calculateStatistics(testUserId);

        expect(stats.totalNotes, 0);
        expect(stats.notesThisWeek, 0);
        expect(stats.notesThisMonth, 0);
        expect(stats.currentStreak, 0);
        expect(stats.longestStreak, 0);
        expect(stats.totalWordCount, 0);
        expect(stats.tagFrequency, isEmpty);
        expect(stats.categoryDistribution, isEmpty);
        expect(stats.creationHeatmap, isEmpty);
        expect(stats.completionRate, 0.0);
        expect(stats.linkedNotesCount, 0);
        expect(stats.avgConnectionsPerNote, 0.0);
      },
    );

    test('calculateStatistics calculates total note count correctly', () async {
      // Create test notes
      final now = DateTime.now();
      final notesRef = fakeFirestore
          .collection('users')
          .doc(testUserId)
          .collection('notes');

      await notesRef.add({
        'title': 'Note 1',
        'description': 'Test note one',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 0,
        'isDone': false,
        'isPinned': false,
        'tags': ['tag1', 'tag2'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': [],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 3,
      });

      await notesRef.add({
        'title': 'Note 2',
        'description': 'Test note two',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 1,
        'isDone': true,
        'isPinned': false,
        'tags': ['tag2', 'tag3'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': ['Note 1'],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 3,
      });

      final stats = await statisticsService.calculateStatistics(testUserId);

      expect(stats.totalNotes, 2);
      expect(stats.totalWordCount, 6);
      expect(stats.completionRate, 50.0);
    });

    test('calculateStatistics calculates tag frequency correctly', () async {
      final now = DateTime.now();
      final notesRef = fakeFirestore
          .collection('users')
          .doc(testUserId)
          .collection('notes');

      await notesRef.add({
        'title': 'Note 1',
        'description': 'Test',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 0,
        'isDone': false,
        'isPinned': false,
        'tags': ['tag1', 'tag2'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': [],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 1,
      });

      await notesRef.add({
        'title': 'Note 2',
        'description': 'Test',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 0,
        'isDone': false,
        'isPinned': false,
        'tags': ['tag2', 'tag3'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': [],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 1,
      });

      final stats = await statisticsService.calculateStatistics(testUserId);

      expect(stats.tagFrequency['tag1'], 1);
      expect(stats.tagFrequency['tag2'], 2);
      expect(stats.tagFrequency['tag3'], 1);
    });

    test(
      'calculateStatistics calculates category distribution correctly',
      () async {
        final now = DateTime.now();
        final notesRef = fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('notes');

        await notesRef.add({
          'title': 'Note 1',
          'description': 'Test',
          'timestamp': now.toIso8601String(),
          'categoryImageIndex': 0,
          'isDone': false,
          'isPinned': false,
          'tags': [],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'outgoingLinks': [],
          'audioUrls': [],
          'imageUrls': [],
          'drawingUrls': [],
          'isShared': false,
          'collaboratorIds': [],
          'collaborators': [],
          'viewCount': 0,
          'wordCount': 1,
        });

        await notesRef.add({
          'title': 'Note 2',
          'description': 'Test',
          'timestamp': now.toIso8601String(),
          'categoryImageIndex': 0,
          'isDone': false,
          'isPinned': false,
          'tags': [],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'outgoingLinks': [],
          'audioUrls': [],
          'imageUrls': [],
          'drawingUrls': [],
          'isShared': false,
          'collaboratorIds': [],
          'collaborators': [],
          'viewCount': 0,
          'wordCount': 1,
        });

        await notesRef.add({
          'title': 'Note 3',
          'description': 'Test',
          'timestamp': now.toIso8601String(),
          'categoryImageIndex': 1,
          'isDone': false,
          'isPinned': false,
          'tags': [],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'outgoingLinks': [],
          'audioUrls': [],
          'imageUrls': [],
          'drawingUrls': [],
          'isShared': false,
          'collaboratorIds': [],
          'collaborators': [],
          'viewCount': 0,
          'wordCount': 1,
        });

        final stats = await statisticsService.calculateStatistics(testUserId);

        expect(stats.categoryDistribution['category_0'], 2);
        expect(stats.categoryDistribution['category_1'], 1);
      },
    );

    test('calculateStatistics calculates linked notes correctly', () async {
      final now = DateTime.now();
      final notesRef = fakeFirestore
          .collection('users')
          .doc(testUserId)
          .collection('notes');

      await notesRef.add({
        'title': 'Note 1',
        'description': 'Test',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 0,
        'isDone': false,
        'isPinned': false,
        'tags': [],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': ['Note 2', 'Note 3'],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 1,
      });

      await notesRef.add({
        'title': 'Note 2',
        'description': 'Test',
        'timestamp': now.toIso8601String(),
        'categoryImageIndex': 0,
        'isDone': false,
        'isPinned': false,
        'tags': [],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'outgoingLinks': [],
        'audioUrls': [],
        'imageUrls': [],
        'drawingUrls': [],
        'isShared': false,
        'collaboratorIds': [],
        'collaborators': [],
        'viewCount': 0,
        'wordCount': 1,
      });

      final stats = await statisticsService.calculateStatistics(testUserId);

      expect(stats.linkedNotesCount, 1);
      expect(stats.avgConnectionsPerNote, 1.0);
    });
  });
}
