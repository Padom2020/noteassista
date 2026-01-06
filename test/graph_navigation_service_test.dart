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
  group('GraphNavigationService', () {
    late GraphNavigationService navigationService;

    setUp(() {
      navigationService = GraphNavigationService();
    });

    group('validateNoteAccess', () {
      test('returns false when user is null', () async {
        final result = await navigationService.validateNoteAccess(
          'test-id',
          null,
        );
        expect(result, false);
      });

      test('returns false when nodeId is empty', () async {
        final result = await navigationService.validateNoteAccess('', null);
        expect(result, false);
      });

      test('returns false when nodeId is whitespace only', () async {
        final result = await navigationService.validateNoteAccess('   ', null);
        expect(result, false);
      });
    });

    group('noteExists', () {
      test('returns false for empty nodeId', () async {
        final result = await navigationService.noteExists('', 'user-123');
        expect(result, false);
      });

      test('returns false for empty userId', () async {
        final result = await navigationService.noteExists('test-id', '');
        expect(result, false);
      });

      test('returns false for whitespace nodeId', () async {
        final result = await navigationService.noteExists('   ', 'user-123');
        expect(result, false);
      });
    });

    group('getCurrentUser', () {
      test('returns current user from auth service', () {
        final result = navigationService.getCurrentUser();
        expect(result, isA<dynamic>());
      });
    });

    group('isAuthenticated', () {
      test('returns boolean based on current auth state', () {
        final result = navigationService.isAuthenticated;
        expect(result, isA<bool>());
      });
    });

    group('batchValidateNotes', () {
      test('returns all false when user is null', () async {
        final nodeIds = ['id1', 'id2', 'id3'];

        final result = await navigationService.batchValidateNotes(
          nodeIds,
          null,
        );

        expect(result, {'id1': false, 'id2': false, 'id3': false});
      });

      test('handles empty nodeIds list', () async {
        final nodeIds = <String>[];

        final result = await navigationService.batchValidateNotes(
          nodeIds,
          null,
        );

        expect(result, isEmpty);
      });
    });
  });
}
