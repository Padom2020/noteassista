import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

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
class AITaggingService {
  final FirebaseFirestore? _firestore;

  AITaggingService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  // Common English stop words to filter out
  static const Set<String> _stopWords = {
    'a',
    'about',
    'above',
    'after',
    'again',
    'against',
    'all',
    'am',
    'an',
    'and',
    'any',
    'are',
    'as',
    'at',
    'be',
    'because',
    'been',
    'before',
    'being',
    'below',
    'between',
    'both',
    'but',
    'by',
    'can',
    'did',
    'do',
    'does',
    'doing',
    'down',
    'during',
    'each',
    'few',
    'for',
    'from',
    'further',
    'had',
    'has',
    'have',
    'having',
    'he',
    'her',
    'here',
    'hers',
    'herself',
    'him',
    'himself',
    'his',
    'how',
    'i',
    'if',
    'in',
    'into',
    'is',
    'it',
    'its',
    'itself',
    'just',
    'me',
    'might',
    'more',
    'most',
    'must',
    'my',
    'myself',
    'no',
    'nor',
    'not',
    'now',
    'of',
    'off',
    'on',
    'once',
    'only',
    'or',
    'other',
    'our',
    'ours',
    'ourselves',
    'out',
    'over',
    'own',
    's',
    'same',
    'she',
    'should',
    'so',
    'some',
    'such',
    't',
    'than',
    'that',
    'the',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'to',
    'too',
    'under',
    'until',
    'up',
    'very',
    'was',
    'we',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'who',
    'whom',
    'why',
    'will',
    'with',
    'would',
    'you',
    'your',
    'yours',
    'yourself',
    'yourselves',
  };

  /// Generate tag suggestions based on note content using TF-IDF analysis
  ///
  /// Returns up to 5 suggested tags ranked by relevance score
  Future<List<TagSuggestion>> generateTagSuggestions(
    String userId,
    String title,
    String description,
  ) async {
    try {
      // Combine title and description for analysis
      final content = '$title $description';

      // Extract keywords using TF-IDF
      final keywords = extractKeywords(content, 10);

      if (keywords.isEmpty) {
        return [];
      }

      // Get user's tag usage frequency for personalization
      final userTagFrequency = await getUserTagFrequency(userId);

      // Score and rank keywords as potential tags
      final suggestions = <TagSuggestion>[];

      for (final keyword in keywords) {
        // Calculate confidence based on:
        // 1. Keyword significance (from TF-IDF)
        // 2. User's previous usage of similar tags
        double confidence = 0.5; // Base confidence

        // Boost confidence if user has used this tag before
        if (userTagFrequency.containsKey(keyword.toLowerCase())) {
          final frequency = userTagFrequency[keyword.toLowerCase()]!;
          confidence += min(0.3, frequency * 0.05); // Up to +0.3 boost
        }

        // Boost confidence for longer, more specific terms
        if (keyword.length > 5) {
          confidence += 0.1;
        }

        // Cap confidence at 1.0
        confidence = min(1.0, confidence);

        suggestions.add(
          TagSuggestion(
            tag: keyword.toLowerCase(),
            confidence: confidence,
            reason:
                userTagFrequency.containsKey(keyword.toLowerCase())
                    ? 'Previously used'
                    : 'Extracted from content',
          ),
        );
      }

      // Sort by confidence (descending) and return top 5
      suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
      return suggestions.take(5).toList();
    } catch (e) {
      debugPrint('Error generating tag suggestions: $e');
      return [];
    }
  }

  /// Extract significant keywords from text using TF-IDF algorithm
  ///
  /// [text] - The text to analyze
  /// [maxKeywords] - Maximum number of keywords to return
  List<String> extractKeywords(String text, int maxKeywords) {
    if (text.trim().isEmpty) {
      return [];
    }

    // Tokenize: convert to lowercase and split into words
    final words =
        text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();

    // Remove stop words and short words
    final filteredWords =
        words
            .where((word) => !_stopWords.contains(word) && word.length > 2)
            .toList();

    if (filteredWords.isEmpty) {
      return [];
    }

    // Calculate term frequency (TF)
    final termFrequency = <String, int>{};
    for (final word in filteredWords) {
      termFrequency[word] = (termFrequency[word] ?? 0) + 1;
    }

    // Calculate TF-IDF scores
    // For simplicity, we use term frequency as a proxy for TF-IDF
    // In a full implementation, IDF would be calculated across all user's notes
    final tfIdfScores = <String, double>{};
    final totalWords = filteredWords.length;

    for (final entry in termFrequency.entries) {
      final tf = entry.value / totalWords;
      // Boost score for terms that appear multiple times
      final boost = log(1 + entry.value);
      tfIdfScores[entry.key] = tf * boost;
    }

    // Sort by score and return top keywords
    final sortedKeywords =
        tfIdfScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sortedKeywords.take(maxKeywords).map((e) => e.key).toList();
  }

  /// Record when a user accepts a suggested tag to improve future suggestions
  ///
  /// This helps the system learn user preferences over time
  Future<void> recordTagAcceptance(
    String userId,
    String tag,
    String noteContent,
  ) async {
    try {
      final userRef = firestore.collection('users').doc(userId);

      // Get current tag frequency
      final userDoc = await userRef.get();
      final data = userDoc.data();
      final tagFrequency = Map<String, int>.from(data?['tagFrequency'] ?? {});

      // Increment frequency for this tag
      final normalizedTag = tag.toLowerCase();
      tagFrequency[normalizedTag] = (tagFrequency[normalizedTag] ?? 0) + 1;

      // Update user document
      await userRef.set({
        'tagFrequency': tagFrequency,
      }, SetOptions(merge: true));

      debugPrint(
        'Recorded tag acceptance: $tag (count: ${tagFrequency[normalizedTag]})',
      );
    } catch (e) {
      debugPrint('Error recording tag acceptance: $e');
      // Don't throw - this is a non-critical operation
    }
  }

  /// Retrieve user's tag usage history for personalization
  ///
  /// Returns a map of tag names to usage counts
  Future<Map<String, int>> getUserTagFrequency(String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {};
      }

      final data = userDoc.data();
      if (data == null || !data.containsKey('tagFrequency')) {
        return {};
      }

      return Map<String, int>.from(data['tagFrequency']);
    } catch (e) {
      debugPrint('Error getting user tag frequency: $e');
      return {};
    }
  }

  /// Remove stop words from a list of words
  ///
  /// This is a helper method for text processing
  List<String> removeStopWords(List<String> words) {
    return words
        .where((word) => !_stopWords.contains(word.toLowerCase()))
        .toList();
  }
}
