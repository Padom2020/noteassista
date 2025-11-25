import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/ai_tagging_service.dart';

void main() {
  late AITaggingService service;

  setUp(() {
    // Create service without Firebase for unit testing pure methods
    service = AITaggingService(firestore: null);
  });

  group('Keyword Extraction Tests', () {
    test('should extract keywords from simple text', () {
      const text = 'Flutter development is amazing and powerful';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('flutter'), isTrue);
      expect(keywords.contains('development'), isTrue);
      expect(keywords.contains('amazing'), isTrue);
      expect(keywords.contains('powerful'), isTrue);
    });

    test('should remove stop words from text', () {
      const text = 'The quick brown fox jumps over the lazy dog';
      final keywords = service.extractKeywords(text, 10);

      // Stop words should be filtered out
      expect(keywords.contains('the'), isFalse);
      expect(keywords.contains('over'), isFalse);

      // Content words should remain
      expect(keywords.contains('quick'), isTrue);
      expect(keywords.contains('brown'), isTrue);
      expect(keywords.contains('fox'), isTrue);
      expect(keywords.contains('jumps'), isTrue);
      expect(keywords.contains('lazy'), isTrue);
      expect(keywords.contains('dog'), isTrue);
    });

    test('should handle empty text', () {
      const text = '';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isEmpty);
    });

    test('should handle text with only stop words', () {
      const text = 'the and or but if';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isEmpty);
    });

    test('should handle text with punctuation', () {
      const text = 'Hello, world! This is a test. Amazing, right?';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('hello'), isTrue);
      expect(keywords.contains('world'), isTrue);
      expect(keywords.contains('test'), isTrue);
      expect(keywords.contains('amazing'), isTrue);
      expect(keywords.contains('right'), isTrue);
    });

    test('should filter out short words (less than 3 characters)', () {
      const text = 'I am at my desk working on a big project';
      final keywords = service.extractKeywords(text, 10);

      // Short words should be filtered
      expect(keywords.contains('am'), isFalse);
      expect(keywords.contains('at'), isFalse);
      expect(keywords.contains('my'), isFalse);
      expect(keywords.contains('on'), isFalse);

      // Longer words should remain
      expect(keywords.contains('desk'), isTrue);
      expect(keywords.contains('working'), isTrue);
      expect(keywords.contains('big'), isTrue);
      expect(keywords.contains('project'), isTrue);
    });

    test('should respect maxKeywords limit', () {
      const text =
          'one two three four five six seven eight nine ten eleven twelve';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords.length, lessThanOrEqualTo(5));
    });

    test('should handle repeated words with higher TF-IDF scores', () {
      const text =
          'machine learning machine learning artificial intelligence machine';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      // 'machine' appears 3 times, should have high score
      expect(keywords.first, equals('machine'));
    });

    test('should handle mixed case text', () {
      const text = 'Flutter DEVELOPMENT is AMAZING and Powerful';
      final keywords = service.extractKeywords(text, 5);

      // All keywords should be lowercase
      expect(keywords.every((k) => k == k.toLowerCase()), isTrue);
      expect(keywords.contains('flutter'), isTrue);
      expect(keywords.contains('development'), isTrue);
    });

    test('should extract keywords from technical content', () {
      const text =
          'Implementing REST API with authentication using JWT tokens and OAuth';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('implementing'), isTrue);
      expect(keywords.contains('authentication'), isTrue);
      // Keywords are ranked by TF-IDF, so we just verify we get relevant terms
      expect(keywords.length, greaterThan(0));
    });

    test('should handle text with numbers', () {
      const text = 'Project 2024 milestone 3 completed successfully';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('project'), isTrue);
      expect(keywords.contains('2024'), isTrue);
      expect(keywords.contains('milestone'), isTrue);
      expect(keywords.contains('completed'), isTrue);
      expect(keywords.contains('successfully'), isTrue);
    });
  });

  group('TF-IDF Calculation Tests', () {
    test('should prioritize frequently occurring terms', () {
      const text = 'flutter flutter flutter dart dart programming language';
      final keywords = service.extractKeywords(text, 5);

      // 'flutter' appears 3 times, should be ranked higher
      expect(keywords.first, equals('flutter'));
    });

    test('should calculate correct term frequency', () {
      const text = 'test test test other word';
      final keywords = service.extractKeywords(text, 5);

      // 'test' appears 3 times out of 5 words (60% frequency)
      // Should be ranked first
      expect(keywords.first, equals('test'));
    });

    test('should handle single occurrence terms', () {
      const text = 'unique special rare common common common';
      final keywords = service.extractKeywords(text, 5);

      // 'common' appears 3 times, should be first
      expect(keywords.first, equals('common'));
      // Other terms should still be included
      expect(keywords.contains('unique'), isTrue);
      expect(keywords.contains('special'), isTrue);
      expect(keywords.contains('rare'), isTrue);
    });
  });

  group('Stop Words Removal Tests', () {
    test('should remove common English stop words', () {
      final words = [
        'the',
        'quick',
        'brown',
        'fox',
        'and',
        'the',
        'lazy',
        'dog',
      ];
      final filtered = service.removeStopWords(words);

      expect(filtered.contains('the'), isFalse);
      expect(filtered.contains('and'), isFalse);
      expect(filtered.contains('quick'), isTrue);
      expect(filtered.contains('brown'), isTrue);
      expect(filtered.contains('fox'), isTrue);
      expect(filtered.contains('lazy'), isTrue);
      expect(filtered.contains('dog'), isTrue);
    });

    test('should handle empty list', () {
      final words = <String>[];
      final filtered = service.removeStopWords(words);

      expect(filtered, isEmpty);
    });

    test('should handle list with only stop words', () {
      final words = ['the', 'and', 'or', 'but', 'if', 'then'];
      final filtered = service.removeStopWords(words);

      expect(filtered, isEmpty);
    });

    test('should be case insensitive', () {
      final words = ['The', 'QUICK', 'And', 'BROWN'];
      final filtered = service.removeStopWords(words);

      expect(filtered.contains('The'), isFalse);
      expect(filtered.contains('And'), isFalse);
      expect(filtered.contains('QUICK'), isTrue);
      expect(filtered.contains('BROWN'), isTrue);
    });
  });

  group('Edge Cases', () {
    test('should handle very long text', () {
      final longText = List.generate(1000, (i) => 'word$i').join(' ');
      final keywords = service.extractKeywords(longText, 10);

      expect(keywords, isNotEmpty);
      expect(keywords.length, lessThanOrEqualTo(10));
    });

    test('should handle text with special characters', () {
      const text = '@flutter #development \$price *important!';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('flutter'), isTrue);
      expect(keywords.contains('development'), isTrue);
      expect(keywords.contains('price'), isTrue);
      expect(keywords.contains('important'), isTrue);
    });

    test('should handle text with URLs', () {
      const text = 'Check out https://flutter.dev for more information';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('check'), isTrue);
      expect(keywords.contains('flutter'), isTrue);
      expect(keywords.contains('dev'), isTrue);
      expect(keywords.contains('information'), isTrue);
    });

    test('should handle text with email addresses', () {
      const text = 'Contact user@example.com for support questions';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      // Verify we extract meaningful keywords from text with emails
      expect(keywords.length, greaterThan(0));
      // At least one of these should be present
      final hasRelevantKeyword =
          keywords.contains('contact') ||
          keywords.contains('support') ||
          keywords.contains('questions');
      expect(hasRelevantKeyword, isTrue);
    });

    test('should handle whitespace-only text', () {
      const text = '     \n\t   ';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isEmpty);
    });

    test('should handle text with multiple spaces', () {
      const text = 'flutter    development     is      amazing';
      final keywords = service.extractKeywords(text, 5);

      expect(keywords, isNotEmpty);
      expect(keywords.contains('flutter'), isTrue);
      expect(keywords.contains('development'), isTrue);
      expect(keywords.contains('amazing'), isTrue);
    });
  });
}
