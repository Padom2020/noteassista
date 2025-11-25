class StatisticsModel {
  final int totalNotes;
  final int notesThisWeek;
  final int notesThisMonth;
  final int currentStreak;
  final int longestStreak;
  final int totalWordCount;
  final Map<String, int> tagFrequency;
  final Map<String, int> categoryDistribution;
  final Map<DateTime, int> creationHeatmap;
  final double completionRate;
  final int linkedNotesCount;
  final double avgConnectionsPerNote;

  StatisticsModel({
    this.totalNotes = 0,
    this.notesThisWeek = 0,
    this.notesThisMonth = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalWordCount = 0,
    this.tagFrequency = const {},
    this.categoryDistribution = const {},
    this.creationHeatmap = const {},
    this.completionRate = 0.0,
    this.linkedNotesCount = 0,
    this.avgConnectionsPerNote = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalNotes': totalNotes,
      'notesThisWeek': notesThisWeek,
      'notesThisMonth': notesThisMonth,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalWordCount': totalWordCount,
      'tagFrequency': tagFrequency,
      'categoryDistribution': categoryDistribution,
      'creationHeatmap': creationHeatmap.map(
        (key, value) => MapEntry(key.toIso8601String(), value),
      ),
      'completionRate': completionRate,
      'linkedNotesCount': linkedNotesCount,
      'avgConnectionsPerNote': avgConnectionsPerNote,
    };
  }

  factory StatisticsModel.fromMap(Map<String, dynamic> data) {
    return StatisticsModel(
      totalNotes: data['totalNotes'] ?? 0,
      notesThisWeek: data['notesThisWeek'] ?? 0,
      notesThisMonth: data['notesThisMonth'] ?? 0,
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      totalWordCount: data['totalWordCount'] ?? 0,
      tagFrequency: Map<String, int>.from(data['tagFrequency'] ?? {}),
      categoryDistribution: Map<String, int>.from(
        data['categoryDistribution'] ?? {},
      ),
      creationHeatmap:
          (data['creationHeatmap'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(DateTime.parse(key), value as int),
          ) ??
          {},
      completionRate: (data['completionRate'] ?? 0.0).toDouble(),
      linkedNotesCount: data['linkedNotesCount'] ?? 0,
      avgConnectionsPerNote: (data['avgConnectionsPerNote'] ?? 0.0).toDouble(),
    );
  }

  StatisticsModel copyWith({
    int? totalNotes,
    int? notesThisWeek,
    int? notesThisMonth,
    int? currentStreak,
    int? longestStreak,
    int? totalWordCount,
    Map<String, int>? tagFrequency,
    Map<String, int>? categoryDistribution,
    Map<DateTime, int>? creationHeatmap,
    double? completionRate,
    int? linkedNotesCount,
    double? avgConnectionsPerNote,
  }) {
    return StatisticsModel(
      totalNotes: totalNotes ?? this.totalNotes,
      notesThisWeek: notesThisWeek ?? this.notesThisWeek,
      notesThisMonth: notesThisMonth ?? this.notesThisMonth,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalWordCount: totalWordCount ?? this.totalWordCount,
      tagFrequency: tagFrequency ?? this.tagFrequency,
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
      creationHeatmap: creationHeatmap ?? this.creationHeatmap,
      completionRate: completionRate ?? this.completionRate,
      linkedNotesCount: linkedNotesCount ?? this.linkedNotesCount,
      avgConnectionsPerNote:
          avgConnectionsPerNote ?? this.avgConnectionsPerNote,
    );
  }
}
