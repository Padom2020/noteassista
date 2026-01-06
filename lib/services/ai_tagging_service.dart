/// Model class representing a tag suggestion with confidence score
class TagSuggestion {
  final String tag;
  final double confidence;
  final String reason;

  TagSuggestion({
    required this.tag,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() => 'TagSuggestion(tag: $tag, confidence: $confidence)';
}

/// Service for AI-powered tag suggestions using TF-IDF algorithm
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Full AI tagging features will be implemented with Supabase in the future
class AITaggingService {
  /// Constructor (stub - ignores firestore parameter for migration compatibility)
  AITaggingService({dynamic firestore});

  /// Generate tag suggestions for note content (stub)
  Future<List<TagSuggestion>> generateTagSuggestions(String content) async {
    // Stub: return empty list for now
    return [];
  }

  /// Get popular tags from user's notes (stub)
  Future<List<String>> getPopularTags(String userId) async {
    // Stub: return empty list for now
    return [];
  }

  /// Get related tags based on existing tags (stub)
  Future<List<String>> getRelatedTags(List<String> existingTags) async {
    // Stub: return empty list for now
    return [];
  }

  /// Extract keywords from text (basic implementation for stub)
  List<String> extractKeywords(String text, int maxKeywords) {
    if (text.isEmpty) return [];

    // Basic keyword extraction - split by whitespace and clean up
    final words =
        text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
            .split(RegExp(r'\s+'))
            .where((word) => word.length >= 3) // Filter short words
            .toList();

    // Remove stop words
    final filteredWords = removeStopWords(words);

    // Return up to maxKeywords
    return filteredWords.take(maxKeywords).toList();
  }

  /// Remove stop words from text (basic implementation for stub)
  List<String> removeStopWords(List<String> words) {
    // Basic English stop words
    const stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'must',
      'can',
      'this',
      'that',
      'these',
      'those',
      'i',
      'you',
      'he',
      'she',
      'it',
      'we',
      'they',
      'me',
      'him',
      'her',
      'us',
      'them',
      'if',
      'then',
      'over',
    };

    return words
        .where((word) => !stopWords.contains(word.toLowerCase()))
        .toList();
  }

  /// Record tag acceptance for learning (stub implementation)
  Future<void> recordTagAcceptance(String tag, String content) async {
    // Stub: do nothing for now
  }
}
