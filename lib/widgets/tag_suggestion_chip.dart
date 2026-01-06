import 'package:flutter/material.dart';
import '../services/ai_tagging_service.dart';

/// A chip widget that displays a tag suggestion with confidence indicator
class TagSuggestionChip extends StatelessWidget {
  final TagSuggestion suggestion;
  final VoidCallback onTap;

  const TagSuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // Visual confidence indicator: higher confidence = more opaque
      opacity: 0.5 + (suggestion.confidence * 0.5),
      child: ActionChip(
        label: Text(suggestion.tag),
        avatar: Icon(
          Icons.auto_awesome,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// A horizontal scrollable list of tag suggestion chips
class TagSuggestionList extends StatelessWidget {
  final List<TagSuggestion> suggestions;
  final Function(String) onTagAccepted;
  final bool isLoading;

  const TagSuggestionList({
    super.key,
    required this.suggestions,
    required this.onTagAccepted,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Generating suggestions...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested tags:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return TagSuggestionChip(
                suggestion: suggestion,
                onTap: () => onTagAccepted(suggestion.tag),
              );
            },
          ),
        ),
      ],
    );
  }
}
