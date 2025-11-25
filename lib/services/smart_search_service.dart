import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

/// Represents a parsed search query with extracted components
class SearchQuery {
  final List<String> keywords;
  final DateRange? dateRange;
  final List<String> tags;
  final Map<String, dynamic> filters;

  SearchQuery({
    required this.keywords,
    this.dateRange,
    this.tags = const [],
    this.filters = const {},
  });
}

/// Represents a date range for filtering
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

/// Represents a search result with relevance scoring
class SearchResult {
  final NoteModel note;
  final double relevanceScore;
  final List<TextHighlight> highlights;

  SearchResult({
    required this.note,
    required this.relevanceScore,
    this.highlights = const [],
  });
}

/// Represents a highlighted text match in search results
class TextHighlight {
  final String text;
  final int startIndex;
  final int endIndex;

  TextHighlight({
    required this.text,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Service for intelligent natural language search with ranking
class SmartSearchService {
  final FirebaseFirestore? _firestore;

  SmartSearchService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  // Common English stop words to filter out
  static const Set<String> _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'he',
    'in',
    'is',
    'it',
    'its',
    'of',
    'on',
    'that',
    'the',
    'to',
    'was',
    'will',
    'with',
    'about',
    'notes',
    'note',
    'my',
    'i',
  };

  /// Parse natural language query into structured SearchQuery
  SearchQuery parseQuery(String naturalLanguageQuery) {
    final query = naturalLanguageQuery.toLowerCase().trim();

    // Extract operators first
    final operators = extractOperators(query);

    // Extract date range
    final dateRange = extractDateRange(query);

    // Extract tags from operators
    final tags = <String>[];
    if (operators.containsKey('tag')) {
      tags.add(operators['tag'] as String);
    }

    // Extract filters
    final filters = <String, dynamic>{};
    if (operators.containsKey('is')) {
      final isValue = operators['is'] as String;
      if (isValue == 'pinned') {
        filters['isPinned'] = true;
      } else if (isValue == 'done') {
        filters['isDone'] = true;
      }
    }

    // Remove operators and temporal expressions from query
    String cleanedQuery = query;

    // Remove operator patterns
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'tag:\S+'), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'date:\S+'), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'is:\S+'), '');

    // Remove temporal expressions
    final temporalPatterns = [
      'today',
      'yesterday',
      'last week',
      'last month',
      'this week',
      'this month',
      'from',
      'about',
      'the',
      'project',
    ];
    for (final pattern in temporalPatterns) {
      cleanedQuery = cleanedQuery.replaceAll(pattern, ' ');
    }

    // Extract keywords
    final keywords = _extractKeywords(cleanedQuery);

    return SearchQuery(
      keywords: keywords,
      dateRange: dateRange,
      tags: tags,
      filters: filters,
    );
  }

  /// Extract date range from natural language temporal expressions
  DateRange? extractDateRange(String query) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (query.contains('today')) {
      return DateRange(start: today, end: today.add(const Duration(days: 1)));
    }

    if (query.contains('yesterday')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return DateRange(start: yesterday, end: today);
    }

    if (query.contains('last week')) {
      final lastWeekStart = today.subtract(Duration(days: today.weekday + 6));
      final lastWeekEnd = lastWeekStart.add(const Duration(days: 7));
      return DateRange(start: lastWeekStart, end: lastWeekEnd);
    }

    if (query.contains('this week')) {
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));
      return DateRange(start: weekStart, end: weekEnd);
    }

    if (query.contains('last month')) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 1);
      return DateRange(start: lastMonth, end: lastMonthEnd);
    }

    if (query.contains('this month')) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      return DateRange(start: monthStart, end: monthEnd);
    }

    // Check for date: operator with specific date
    final dateMatch = RegExp(r'date:(\d{4}-\d{2}-\d{2})').firstMatch(query);
    if (dateMatch != null) {
      try {
        final date = DateTime.parse(dateMatch.group(1)!);
        return DateRange(start: date, end: date.add(const Duration(days: 1)));
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    return null;
  }

  /// Extract search operators like tag:, date:, is:
  Map<String, String> extractOperators(String query) {
    final operators = <String, String>{};

    // Extract tag: operator
    final tagMatch = RegExp(r'tag:(\S+)').firstMatch(query);
    if (tagMatch != null) {
      operators['tag'] = tagMatch.group(1)!;
    }

    // Extract date: operator
    final dateMatch = RegExp(r'date:(\S+)').firstMatch(query);
    if (dateMatch != null) {
      operators['date'] = dateMatch.group(1)!;
    }

    // Extract is: operator
    final isMatch = RegExp(r'is:(\S+)').firstMatch(query);
    if (isMatch != null) {
      operators['is'] = isMatch.group(1)!;
    }

    return operators;
  }

  /// Extract keywords from query by removing stop words
  List<String> _extractKeywords(String text) {
    // Split by whitespace and punctuation
    final words =
        text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty && !_stopWords.contains(word))
            .toList();

    return words;
  }

  /// Search notes with relevance ranking
  Future<List<SearchResult>> search(String userId, SearchQuery query) async {
    try {
      // Get all notes for the user
      Query<Map<String, dynamic>> notesQuery = firestore
          .collection('users')
          .doc(userId)
          .collection('notes');

      // Apply filters
      if (query.filters.containsKey('isPinned')) {
        notesQuery = notesQuery.where(
          'isPinned',
          isEqualTo: query.filters['isPinned'],
        );
      }
      if (query.filters.containsKey('isDone')) {
        notesQuery = notesQuery.where(
          'isDone',
          isEqualTo: query.filters['isDone'],
        );
      }

      final snapshot = await notesQuery.get();
      final notes =
          snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();

      // Filter and rank results
      final results = <SearchResult>[];

      for (final note in notes) {
        // Apply date range filter
        if (query.dateRange != null) {
          if (note.createdAt.isBefore(query.dateRange!.start) ||
              note.createdAt.isAfter(query.dateRange!.end)) {
            continue;
          }
        }

        // Apply tag filter
        if (query.tags.isNotEmpty) {
          bool hasTag = false;
          for (final tag in query.tags) {
            if (note.tags.any(
              (t) => t.toLowerCase().contains(tag.toLowerCase()),
            )) {
              hasTag = true;
              break;
            }
          }
          if (!hasTag) continue;
        }

        // Calculate relevance score
        final score = _calculateRelevanceScore(note, query.keywords);

        // Only include notes with positive relevance
        if (score > 0 || query.keywords.isEmpty) {
          final highlights = _findHighlights(note, query.keywords);
          results.add(
            SearchResult(
              note: note,
              relevanceScore: score,
              highlights: highlights,
            ),
          );
        }
      }

      // Sort by relevance score (descending)
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return results;
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  /// Calculate relevance score based on keyword matches
  double _calculateRelevanceScore(NoteModel note, List<String> keywords) {
    if (keywords.isEmpty) {
      // No keywords, use recency and pin status
      final daysSinceCreation =
          DateTime.now().difference(note.createdAt).inDays;
      final recencyScore = 1.0 / (1.0 + daysSinceCreation * 0.1);
      final pinBonus = note.isPinned ? 0.5 : 0.0;
      return recencyScore + pinBonus;
    }

    double score = 0.0;

    final titleLower = note.title.toLowerCase();
    final descriptionLower = note.description.toLowerCase();
    final tagsLower = note.tags.map((t) => t.toLowerCase()).toList();

    for (final keyword in keywords) {
      final keywordLower = keyword.toLowerCase();

      // Title matches (weight: 3.0)
      final titleMatches = _countOccurrences(titleLower, keywordLower);
      score += titleMatches * 3.0;

      // Description matches (weight: 2.0)
      final descriptionMatches = _countOccurrences(
        descriptionLower,
        keywordLower,
      );
      score += descriptionMatches * 2.0;

      // Tag matches (weight: 2.5)
      for (final tag in tagsLower) {
        if (tag.contains(keywordLower)) {
          score += 2.5;
        }
      }
    }

    // Recency bonus (weight: 1.0)
    final daysSinceCreation = DateTime.now().difference(note.createdAt).inDays;
    final recencyBonus = 1.0 / (1.0 + daysSinceCreation * 0.1);
    score += recencyBonus;

    // Pin status bonus (weight: 0.5)
    if (note.isPinned) {
      score += 0.5;
    }

    return score;
  }

  /// Count occurrences of a substring in a string
  int _countOccurrences(String text, String substring) {
    if (substring.isEmpty) return 0;

    int count = 0;
    int index = 0;

    while ((index = text.indexOf(substring, index)) != -1) {
      count++;
      index += substring.length;
    }

    return count;
  }

  /// Find text highlights for search results
  List<TextHighlight> _findHighlights(NoteModel note, List<String> keywords) {
    final highlights = <TextHighlight>[];

    if (keywords.isEmpty) return highlights;

    final titleLower = note.title.toLowerCase();
    final descriptionLower = note.description.toLowerCase();

    for (final keyword in keywords) {
      final keywordLower = keyword.toLowerCase();

      // Find in title
      int index = titleLower.indexOf(keywordLower);
      if (index != -1) {
        highlights.add(
          TextHighlight(
            text: note.title.substring(index, index + keyword.length),
            startIndex: index,
            endIndex: index + keyword.length,
          ),
        );
      }

      // Find first occurrence in description
      index = descriptionLower.indexOf(keywordLower);
      if (index != -1) {
        highlights.add(
          TextHighlight(
            text: note.description.substring(index, index + keyword.length),
            startIndex: index,
            endIndex: index + keyword.length,
          ),
        );
      }
    }

    return highlights;
  }
}
