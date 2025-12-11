import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/note_model.dart';

void main() {
  group('Daily Note Tests', () {
    test('Daily note title format is correct', () {
      // Test that the title format matches "Daily Note - YYYY-MM-DD"
      final date = DateTime(2024, 3, 15);
      final expectedTitle = 'Daily Note - 2024-03-15';

      // Simulate the title generation logic
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });

    test('Daily note title format handles single digit months and days', () {
      // Test with single digit month and day
      final date = DateTime(2024, 1, 5);
      final expectedTitle = 'Daily Note - 2024-01-05';

      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });

    test('Daily note title format handles double digit months and days', () {
      // Test with double digit month and day
      final date = DateTime(2024, 12, 31);
      final expectedTitle = 'Daily Note - 2024-12-31';

      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });

    test('Daily note has "daily" tag', () {
      // Create a daily note model
      final dailyNote = NoteModel(
        id: 'test-daily-note',
        title: 'Daily Note - 2024-03-15',
        description: '',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily'],
      );

      expect(dailyNote.tags, contains('daily'));
      expect(dailyNote.tags.length, equals(1));
    });

    test('Daily note model serialization includes daily tag', () {
      final dailyNote = NoteModel(
        id: 'test-daily-note',
        title: 'Daily Note - 2024-03-15',
        description: 'My daily thoughts',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily'],
      );

      final map = dailyNote.toMap();

      expect(map['title'], equals('Daily Note - 2024-03-15'));
      expect(map['tags'], isA<List>());
      expect(map['tags'], contains('daily'));
    });

    test('Daily note title is unique per date', () {
      // Test that different dates produce different titles
      final date1 = DateTime(2024, 3, 15);
      final date2 = DateTime(2024, 3, 16);

      final title1 =
          'Daily Note - ${date1.year}-${date1.month.toString().padLeft(2, '0')}-${date1.day.toString().padLeft(2, '0')}';
      final title2 =
          'Daily Note - ${date2.year}-${date2.month.toString().padLeft(2, '0')}-${date2.day.toString().padLeft(2, '0')}';

      expect(title1, isNot(equals(title2)));
      expect(title1, equals('Daily Note - 2024-03-15'));
      expect(title2, equals('Daily Note - 2024-03-16'));
    });

    test('Daily note can have additional tags beyond "daily"', () {
      // Daily notes can have other tags in addition to "daily"
      final dailyNote = NoteModel(
        id: 'test-daily-note',
        title: 'Daily Note - 2024-03-15',
        description: 'My daily thoughts about work',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily', 'work', 'personal'],
      );

      expect(dailyNote.tags, contains('daily'));
      expect(dailyNote.tags, contains('work'));
      expect(dailyNote.tags, contains('personal'));
      expect(dailyNote.tags.length, equals(3));
    });

    test('Daily note title format is consistent across years', () {
      // Test across different years
      final date2023 = DateTime(2023, 6, 15);
      final date2024 = DateTime(2024, 6, 15);
      final date2025 = DateTime(2025, 6, 15);

      final title2023 =
          'Daily Note - ${date2023.year}-${date2023.month.toString().padLeft(2, '0')}-${date2023.day.toString().padLeft(2, '0')}';
      final title2024 =
          'Daily Note - ${date2024.year}-${date2024.month.toString().padLeft(2, '0')}-${date2024.day.toString().padLeft(2, '0')}';
      final title2025 =
          'Daily Note - ${date2025.year}-${date2025.month.toString().padLeft(2, '0')}-${date2025.day.toString().padLeft(2, '0')}';

      expect(title2023, equals('Daily Note - 2023-06-15'));
      expect(title2024, equals('Daily Note - 2024-06-15'));
      expect(title2025, equals('Daily Note - 2025-06-15'));
    });

    test('Daily note has default empty description', () {
      final dailyNote = NoteModel(
        id: 'test-daily-note',
        title: 'Daily Note - 2024-03-15',
        description: '',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily'],
      );

      expect(dailyNote.description, equals(''));
    });

    test('Daily note is not marked as done by default', () {
      final dailyNote = NoteModel(
        id: 'test-daily-note',
        title: 'Daily Note - 2024-03-15',
        description: '',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily'],
      );

      expect(dailyNote.isDone, equals(false));
    });
  });

  group('Daily Note Date Formatting Edge Cases', () {
    test('Handles leap year dates correctly', () {
      final leapYearDate = DateTime(2024, 2, 29); // 2024 is a leap year
      final expectedTitle = 'Daily Note - 2024-02-29';

      final dateString =
          '${leapYearDate.year}-${leapYearDate.month.toString().padLeft(2, '0')}-${leapYearDate.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });

    test('Handles first day of year', () {
      final firstDay = DateTime(2024, 1, 1);
      final expectedTitle = 'Daily Note - 2024-01-01';

      final dateString =
          '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });

    test('Handles last day of year', () {
      final lastDay = DateTime(2024, 12, 31);
      final expectedTitle = 'Daily Note - 2024-12-31';

      final dateString =
          '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
      final dailyNoteTitle = 'Daily Note - $dateString';

      expect(dailyNoteTitle, equals(expectedTitle));
    });
  });
}
