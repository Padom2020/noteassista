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
    required this.tags,
    required this.filters,
  });
}

/// Represents a date range for search filtering
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

/// Represents a search result with relevance score
class SearchResult {
  final NoteModel note;
  final double relevanceScore;
  final List<String> matchedTerms;

  SearchResult({
    required this.note,
    required this.relevanceScore,
    required this.matchedTerms,
  });
}

/// Service for intelligent natural language search with ranking
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Full search features will be implemented with Supabase in the future
class SmartSearchService {
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
  };

  /// Parse natural language search query into structured components
  SearchQuery parseQuery(String query) {
    final keywords = <String>[];
    final tags = <String>[];
    final filters = <String, dynamic>{};
    DateRange? dateRange;

    // Extract operators first
    final operators = extractOperators(query);

    // Process operators
    for (final entry in operators.entries) {
      switch (entry.key) {
        case 'tag':
          tags.add(entry.value);
          break;
        case 'is':
          switch (entry.value) {
            case 'pinned':
              filters['isPinned'] = true;
              break;
            case 'done':
              filters['isDone'] = true;
              break;
          }
          break;
        case 'date':
          // For stub implementation, just set dateRange to null
          break;
      }
    }

    // Extract date range from temporal expressions
    dateRange = extractDateRange(query);

    // Remove operators from query for keyword extraction
    String cleanQuery = query;
    for (final entry in operators.entries) {
      cleanQuery = cleanQuery.replaceAll('${entry.key}:${entry.value}', '');
    }

    // Simple keyword extraction
    final words = cleanQuery.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      if (!_stopWords.contains(word) && word.isNotEmpty) {
        if (word.startsWith('#')) {
          tags.add(word.substring(1));
        } else {
          keywords.add(word);
        }
      }
    }

    return SearchQuery(
      keywords: keywords,
      dateRange: dateRange,
      tags: tags,
      filters: filters,
    );
  }

  /// Search notes using natural language query
  /// Returns empty list for now (stub implementation)
  Future<List<SearchResult>> searchNotes(String userId, String query) async {
    // Stub: return empty list
    return [];
  }

  /// Get search suggestions based on partial query
  /// Returns empty list for now (stub implementation)
  Future<List<String>> getSearchSuggestions(
    String userId,
    String partial,
  ) async {
    // Stub: return empty list
    return [];
  }

  /// Extract date range from natural language query
  /// Basic implementation for stub
  DateRange? extractDateRange(String query) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Handle basic temporal expressions
    if (query.contains('today')) {
      return DateRange(start: today, end: today.add(const Duration(days: 1)));
    }

    if (query.contains('yesterday')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return DateRange(start: yesterday, end: today);
    }

    // Handle date: operator
    final dateMatch = RegExp(r'date:(\d{4}-\d{2}-\d{2})').firstMatch(query);
    if (dateMatch != null) {
      try {
        final date = DateTime.parse(dateMatch.group(1)!);
        return DateRange(start: date, end: date.add(const Duration(days: 1)));
      } catch (e) {
        // Invalid date format, return null
        return null;
      }
    }

    // For other temporal expressions, return null for now
    if (query.contains('last week') ||
        query.contains('this week') ||
        query.contains('last month') ||
        query.contains('this month') ||
        query.contains('from today')) {
      // For stub implementation, return a basic range
      return DateRange(start: today, end: today.add(const Duration(days: 1)));
    }

    return null;
  }

  /// Extract search operators from query (tag:, is:, date:, etc.)
  /// Basic implementation for stub
  Map<String, dynamic> extractOperators(String query) {
    final operators = <String, dynamic>{};

    // Simple regex patterns for common operators
    final patterns = {
      'tag': RegExp(r'tag:(\S+)'),
      'is': RegExp(r'is:(\S+)'),
      'date': RegExp(r'date:(\S+)'),
    };

    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(query);
      if (match != null && match.group(1) != null) {
        operators[entry.key] = match.group(1)!;
      }
    }

    return operators;
  }
}
