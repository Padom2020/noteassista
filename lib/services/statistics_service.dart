import '../models/note_model.dart';
import '../models/statistics_model.dart';
import '../services/supabase_service.dart';

class StatisticsService {
  final SupabaseService _supabaseService;

  StatisticsService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService.instance;

  /// Calculate comprehensive statistics for a user's notes
  Future<StatisticsModel> calculateStatistics(String userId) async {
    try {
      // Fetch all notes for the user
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return StatisticsModel();
      }
      final notes = result.data!;

      if (notes.isEmpty) {
        return StatisticsModel();
      }

      // Calculate total note count
      final totalNotes = notes.length;

      // Calculate notes this week and this month
      final now = DateTime.now();
      final startOfWeek = _getStartOfWeek(now);
      final startOfMonth = DateTime(now.year, now.month, 1);

      final notesThisWeek =
          notes.where((note) => note.createdAt.isAfter(startOfWeek)).length;

      final notesThisMonth =
          notes.where((note) => note.createdAt.isAfter(startOfMonth)).length;

      // Calculate streaks
      final streaks = _calculateStreaks(notes);
      final currentStreak = streaks['current'] ?? 0;
      final longestStreak = streaks['longest'] ?? 0;

      // Calculate total word count
      final totalWordCount = notes.fold<int>(
        0,
        (total, note) => total + note.wordCount,
      );

      // Calculate tag frequency distribution
      final tagFrequency = <String, int>{};
      for (final note in notes) {
        for (final tag in note.tags) {
          tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
        }
      }

      // Calculate category distribution
      final categoryDistribution = <String, int>{};
      for (final note in notes) {
        final categoryKey = 'category_${note.categoryImageIndex}';
        categoryDistribution[categoryKey] =
            (categoryDistribution[categoryKey] ?? 0) + 1;
      }

      // Generate creation heatmap data
      final creationHeatmap = <DateTime, int>{};
      for (final note in notes) {
        final dateOnly = DateTime(
          note.createdAt.year,
          note.createdAt.month,
          note.createdAt.day,
        );
        creationHeatmap[dateOnly] = (creationHeatmap[dateOnly] ?? 0) + 1;
      }

      // Calculate completion rate
      final completedNotes = notes.where((note) => note.isDone).length;
      final completionRate =
          totalNotes > 0 ? (completedNotes / totalNotes) * 100 : 0.0;

      // Calculate linked notes count and average connections
      final notesWithLinks =
          notes.where((note) => note.outgoingLinks.isNotEmpty).length;

      final totalConnections = notes.fold<int>(
        0,
        (total, note) => total + note.outgoingLinks.length,
      );

      final avgConnectionsPerNote =
          totalNotes > 0 ? totalConnections / totalNotes : 0.0;

      return StatisticsModel(
        totalNotes: totalNotes,
        notesThisWeek: notesThisWeek,
        notesThisMonth: notesThisMonth,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalWordCount: totalWordCount,
        tagFrequency: tagFrequency,
        categoryDistribution: categoryDistribution,
        creationHeatmap: creationHeatmap,
        completionRate: completionRate,
        linkedNotesCount: notesWithLinks,
        avgConnectionsPerNote: avgConnectionsPerNote,
      );
    } catch (e) {
      throw Exception('Failed to calculate statistics: $e');
    }
  }

  /// Get the start of the current week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    final daysToSubtract = weekday - 1; // Monday is 1
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  /// Calculate current and longest streaks of consecutive days with notes
  Map<String, int> _calculateStreaks(List<NoteModel> notes) {
    if (notes.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    // Sort notes by creation date
    final sortedNotes = List<NoteModel>.from(notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Get unique dates (date only, no time)
    final uniqueDates = <DateTime>{};
    for (final note in sortedNotes) {
      final dateOnly = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );
      uniqueDates.add(dateOnly);
    }

    final sortedDates = uniqueDates.toList()..sort();

    // Calculate streaks
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < sortedDates.length; i++) {
      if (i > 0) {
        final daysDifference =
            sortedDates[i].difference(sortedDates[i - 1]).inDays;

        if (daysDifference == 1) {
          // Consecutive day
          tempStreak++;
        } else {
          // Streak broken
          longestStreak =
              tempStreak > longestStreak ? tempStreak : longestStreak;
          tempStreak = 1;
        }
      }
    }

    // Update longest streak with the last streak
    longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;

    // Calculate current streak (must include today or yesterday)
    if (sortedDates.isNotEmpty) {
      final lastDate = sortedDates.last;
      final daysSinceLastNote = todayOnly.difference(lastDate).inDays;

      if (daysSinceLastNote == 0 || daysSinceLastNote == 1) {
        // Current streak is active
        currentStreak = 1;
        for (int i = sortedDates.length - 2; i >= 0; i--) {
          final daysDifference =
              sortedDates[i + 1].difference(sortedDates[i]).inDays;

          if (daysDifference == 1) {
            currentStreak++;
          } else {
            break;
          }
        }
      }
    }

    return {'current': currentStreak, 'longest': longestStreak};
  }
}
