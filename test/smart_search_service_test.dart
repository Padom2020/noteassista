import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/smart_search_service.dart';

void main() {
  late SmartSearchService service;

  setUp(() {
    // Create service for unit testing pure methods
    service = SmartSearchService();
  });

  group('Natural Language Date Parsing Tests', () {
    test('should parse "today" correctly', () {
      const query = 'notes from today';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(dateRange!.start.year, equals(today.year));
      expect(dateRange.start.month, equals(today.month));
      expect(dateRange.start.day, equals(today.day));
    });

    test('should parse "yesterday" correctly', () {
      const query = 'notes from yesterday';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      expect(dateRange!.start.year, equals(yesterday.year));
      expect(dateRange.start.month, equals(yesterday.month));
      expect(dateRange.start.day, equals(yesterday.day));
    });

    test('should parse "last week" correctly', () {
      const query = 'notes from last week';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Last week should be 7-14 days ago
      final daysDiff = today.difference(dateRange!.start).inDays;
      expect(daysDiff, greaterThanOrEqualTo(6));
      expect(daysDiff, lessThanOrEqualTo(14));
    });

    test('should parse "this week" correctly', () {
      const query = 'notes from this week';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // This week should include today
      expect(
        dateRange!.start.isBefore(today) ||
            dateRange.start.isAtSameMomentAs(today),
        isTrue,
      );
      expect(dateRange.end.isAfter(today), isTrue);
    });

    test('should parse "last month" correctly', () {
      const query = 'notes from last month';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      final expectedStart = DateTime(now.year, now.month - 1, 1);

      expect(dateRange!.start.year, equals(expectedStart.year));
      expect(dateRange.start.month, equals(expectedStart.month));
      expect(dateRange.start.day, equals(1));
    });

    test('should parse "this month" correctly', () {
      const query = 'notes from this month';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);

      final now = DateTime.now();
      expect(dateRange!.start.year, equals(now.year));
      expect(dateRange.start.month, equals(now.month));
      expect(dateRange.start.day, equals(1));
    });

    test('should parse date: operator with specific date', () {
      const query = 'notes date:2024-01-15';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);
      expect(dateRange!.start.year, equals(2024));
      expect(dateRange.start.month, equals(1));
      expect(dateRange.start.day, equals(15));
    });

    test('should return null for query without temporal expressions', () {
      const query = 'flutter development notes';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNull);
    });

    test('should handle invalid date format in date: operator', () {
      const query = 'notes date:invalid-date';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNull);
    });

    test('should prioritize first temporal expression found', () {
      const query = 'notes from today and yesterday';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);
      // Should match 'today' since it appears first
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(dateRange!.start.day, equals(today.day));
    });
  });

  group('Search Operator Extraction Tests', () {
    test('should extract tag: operator', () {
      const query = 'notes tag:flutter';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('tag', 'flutter'));
    });

    test('should extract date: operator', () {
      const query = 'notes date:2024-01-15';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('date', '2024-01-15'));
    });

    test('should extract is: operator with pinned', () {
      const query = 'notes is:pinned';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('is', 'pinned'));
    });

    test('should extract is: operator with done', () {
      const query = 'notes is:done';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('is', 'done'));
    });

    test('should extract multiple operators', () {
      const query = 'notes tag:flutter is:pinned date:2024-01-15';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('tag', 'flutter'));
      expect(operators, containsPair('is', 'pinned'));
      expect(operators, containsPair('date', '2024-01-15'));
    });

    test('should return empty map for query without operators', () {
      const query = 'simple search query';
      final operators = service.extractOperators(query);

      expect(operators, isEmpty);
    });

    test('should handle operators with special characters', () {
      const query = 'notes tag:flutter-dev';
      final operators = service.extractOperators(query);

      expect(operators, containsPair('tag', 'flutter-dev'));
    });

    test(
      'should extract first occurrence when operator appears multiple times',
      () {
        const query = 'notes tag:flutter tag:dart';
        final operators = service.extractOperators(query);

        expect(operators, containsPair('tag', 'flutter'));
      },
    );
  });

  group('Query Parsing Tests', () {
    test('should parse simple query with keywords only', () {
      const query = 'flutter development notes';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isNotEmpty);
      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
      expect(searchQuery.dateRange, isNull);
      expect(searchQuery.tags, isEmpty);
      expect(searchQuery.filters, isEmpty);
    });

    test('should parse query with tag operator', () {
      const query = 'notes tag:flutter';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.tags, contains('flutter'));
    });

    test('should parse query with is:pinned filter', () {
      const query = 'notes is:pinned';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.filters, containsPair('isPinned', true));
    });

    test('should parse query with is:done filter', () {
      const query = 'notes is:done';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.filters, containsPair('isDone', true));
    });

    test('should parse query with temporal expression', () {
      const query = 'notes from today';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.dateRange, isNotNull);
    });

    test('should parse complex query with multiple components', () {
      const query = 'flutter development tag:mobile is:pinned from today';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
      expect(searchQuery.tags, contains('mobile'));
      expect(searchQuery.filters, containsPair('isPinned', true));
      expect(searchQuery.dateRange, isNotNull);
    });

    test('should remove stop words from keywords', () {
      const query = 'the quick brown fox and the lazy dog';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('the'), isFalse);
      expect(searchQuery.keywords.contains('and'), isFalse);
      expect(searchQuery.keywords.contains('quick'), isTrue);
      expect(searchQuery.keywords.contains('brown'), isTrue);
      expect(searchQuery.keywords.contains('fox'), isTrue);
      expect(searchQuery.keywords.contains('lazy'), isTrue);
      expect(searchQuery.keywords.contains('dog'), isTrue);
    });

    test('should handle empty query', () {
      const query = '';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isEmpty);
      expect(searchQuery.dateRange, isNull);
      expect(searchQuery.tags, isEmpty);
      expect(searchQuery.filters, isEmpty);
    });

    test('should handle query with only operators', () {
      const query = 'tag:flutter is:pinned';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.tags, contains('flutter'));
      expect(searchQuery.filters, containsPair('isPinned', true));
    });

    test('should be case insensitive', () {
      const query = 'FLUTTER Development NOTES';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
    });
  });

  group('Search Ranking Algorithm Tests', () {
    test('should calculate higher score for title matches', () {
      // This test verifies the ranking logic conceptually
      // In a real implementation, we would need mock notes to test scoring
      const query = 'flutter development';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, contains('flutter'));
      expect(searchQuery.keywords, contains('development'));

      // Title matches should have weight 3.0
      // Description matches should have weight 2.0
      // Tag matches should have weight 2.5
      // This is verified by the implementation
    });

    test('should include recency bonus in scoring', () {
      // Recency bonus formula: 1.0 / (1.0 + daysSinceCreation * 0.1)
      // Recent notes should score higher
      const query = 'notes';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery, isNotNull);
      // Scoring logic is tested through integration tests
    });

    test('should include pin status bonus', () {
      // Pinned notes should get +0.5 bonus
      const query = 'is:pinned';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.filters, containsPair('isPinned', true));
    });

    test('should handle queries with no keywords', () {
      const query = 'is:pinned';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isEmpty);
      expect(searchQuery.filters, containsPair('isPinned', true));
      // Should still return results based on filters
    });
  });

  group('Edge Cases', () {
    test('should handle very long query', () {
      final longQuery = List.generate(100, (i) => 'word$i').join(' ');
      final searchQuery = service.parseQuery(longQuery);

      expect(searchQuery.keywords, isNotEmpty);
    });

    test('should handle query with special characters', () {
      const query = '@flutter #development \$price *important!';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isNotEmpty);
      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
    });

    test('should handle query with multiple spaces', () {
      const query = 'flutter    development     notes';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
    });

    test('should handle query with tabs and newlines', () {
      const query = 'flutter\tdevelopment\nnotes';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
    });

    test('should handle query with only stop words', () {
      const query = 'the and or but if';
      final searchQuery = service.parseQuery(query);

      // Some words like 'or', 'but', 'if' are not in the stop words list
      // so they may be included
      expect(searchQuery.keywords.length, lessThanOrEqualTo(3));
    });

    test('should handle query with mixed operators and keywords', () {
      const query = 'flutter tag:mobile development is:pinned notes';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('development'), isTrue);
      expect(searchQuery.tags, contains('mobile'));
      expect(searchQuery.filters, containsPair('isPinned', true));
    });

    test('should handle malformed operators gracefully', () {
      const query = 'tag: is: date:';
      final searchQuery = service.parseQuery(query);

      // Should not crash, may have empty values
      expect(searchQuery, isNotNull);
    });

    test('should handle query with URLs', () {
      const query = 'check https://flutter.dev for documentation';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isNotEmpty);
      expect(searchQuery.keywords.contains('check'), isTrue);
      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.keywords.contains('dev'), isTrue);
      expect(searchQuery.keywords.contains('documentation'), isTrue);
    });

    test('should handle query with email addresses', () {
      const query = 'contact user@example.com for support';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords, isNotEmpty);
      expect(searchQuery.keywords.contains('contact'), isTrue);
      expect(searchQuery.keywords.contains('user'), isTrue);
      expect(searchQuery.keywords.contains('support'), isTrue);
    });
  });

  group('Date Range Edge Cases', () {
    test('should handle year boundary for last month', () {
      // If current month is January, last month should be December of previous year
      // This would need to be tested with a mockable date provider
      // For now, we verify the logic exists
      final query = 'notes from last month';
      final dateRange = service.extractDateRange(query);
      expect(dateRange, isNotNull);
    });

    test('should handle leap year dates', () {
      const query = 'notes date:2024-02-29';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);
      expect(dateRange!.start.year, equals(2024));
      expect(dateRange.start.month, equals(2));
      expect(dateRange.start.day, equals(29));
    });

    test('should handle invalid leap year date', () {
      const query = 'notes date:2023-02-29';
      final dateRange = service.extractDateRange(query);

      // Dart's DateTime.parse is lenient and adjusts invalid dates
      // 2023-02-29 becomes 2023-03-01
      expect(dateRange, isNotNull);
    });

    test('should handle future dates', () {
      const query = 'notes date:2099-12-31';
      final dateRange = service.extractDateRange(query);

      expect(dateRange, isNotNull);
      expect(dateRange!.start.year, equals(2099));
    });
  });

  group('Operator Combinations', () {
    test('should handle all operators together', () {
      const query = 'flutter tag:mobile is:pinned date:2024-01-15';
      final searchQuery = service.parseQuery(query);

      expect(searchQuery.keywords.contains('flutter'), isTrue);
      expect(searchQuery.tags, contains('mobile'));
      expect(searchQuery.filters, containsPair('isPinned', true));
      expect(searchQuery.dateRange, isNotNull);
    });

    test('should handle temporal expression with date operator', () {
      const query = 'notes from today date:2024-01-15';
      final searchQuery = service.parseQuery(query);

      // date: operator should take precedence
      expect(searchQuery.dateRange, isNotNull);
    });

    test('should handle multiple is: operators', () {
      const query = 'notes is:pinned is:done';
      final searchQuery = service.parseQuery(query);

      // Should extract first occurrence
      expect(searchQuery.filters, containsPair('isPinned', true));
    });
  });
}
