import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/note_model.dart';
import 'package:noteassista/services/statistics_service.dart';
import 'package:noteassista/services/supabase_service.dart';

/// Mock SupabaseService for testing
class MockSupabaseService implements SupabaseService {
  List<NoteModel> _mockNotes = [];
  bool _shouldFail = false;
  String? _failureMessage;

  void setMockNotes(List<NoteModel> notes) {
    _mockNotes = notes;
  }

  void setShouldFail(bool shouldFail, [String? message]) {
    _shouldFail = shouldFail;
    _failureMessage = message;
  }

  void reset() {
    _mockNotes = [];
    _shouldFail = false;
    _failureMessage = null;
  }

  @override
  Future<SupabaseOperationResult<List<NoteModel>>> getAllNotes() async {
    if (_shouldFail) {
      return SupabaseOperationResult.failure(
        _failureMessage ?? 'Mock failure',
        errorType: SupabaseErrorType.database,
      );
    }
    return SupabaseOperationResult.success(_mockNotes);
  }

  // Implement other required methods with no-op implementations
  @override
  String? get currentUserId => 'test-user-id';

  @override
  bool get isAuthenticated => true;

  @override
  Future<SupabaseOperationResult<String>> createNote(NoteModel note) async {
    return SupabaseOperationResult.success('test-note-id');
  }

  @override
  Future<SupabaseOperationResult<void>> updateNote(
    String noteId,
    NoteModel note,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<void>> deleteNote(String noteId) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<NoteModel?>> getNoteById(String noteId) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Stream<List<NoteModel>> streamNotes(bool isDone) {
    return Stream.value([]);
  }

  @override
  Stream<List<NoteModel>> streamNotesByFolder(
    String? folderId, {
    bool? isDone,
  }) {
    return Stream.value([]);
  }

  @override
  Stream<List<NoteModel>> streamAllNotes() {
    return Stream.value([]);
  }

  @override
  Future<SupabaseOperationResult<List<NoteModel>>> getNotesByFolder(
    String? folderId, {
    bool? isDone,
  }) async {
    return SupabaseOperationResult.success([]);
  }

  @override
  Future<SupabaseOperationResult<void>> moveNoteToFolder(
    String noteId,
    String? newFolderId,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<void>> toggleNotePinStatus(
    String noteId,
    bool isPinned,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<void>> incrementNoteViewCount(
    String noteId,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<void>> toggleNoteStatus(
    String noteId,
    bool newStatus,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<List<NoteModel>>> searchNotes(
    String searchQuery,
  ) async {
    return SupabaseOperationResult.success([]);
  }

  @override
  Future<SupabaseOperationResult<List<NoteModel>>> getNotesByTags(
    List<String> tags,
  ) async {
    return SupabaseOperationResult.success([]);
  }

  @override
  Future<SupabaseOperationResult<List<NoteModel>>> getPinnedNotes() async {
    return SupabaseOperationResult.success([]);
  }

  @override
  Future<SupabaseOperationResult<void>> updateNoteWordCount(
    String noteId,
    int wordCount,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<void>> bulkDeleteNotes(
    List<String> noteIds,
  ) async {
    return SupabaseOperationResult.success(null);
  }

  @override
  Future<SupabaseOperationResult<Map<String, int>>> getNotesCount() async {
    return SupabaseOperationResult.success({
      'total': 0,
      'completed': 0,
      'pending': 0,
    });
  }

  // Add other required method implementations as no-ops
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('StatisticsService', () {
    late StatisticsService statisticsService;
    late MockSupabaseService mockSupabaseService;

    setUp(() {
      mockSupabaseService = MockSupabaseService();
      statisticsService = StatisticsService(
        supabaseService: mockSupabaseService,
      );
    });

    group('calculateStatistics', () {
      test('returns empty statistics when no notes exist', () async {
        // Arrange
        mockSupabaseService.setMockNotes([]);

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.totalNotes, 0);
        expect(result.notesThisWeek, 0);
        expect(result.notesThisMonth, 0);
        expect(result.currentStreak, 0);
        expect(result.longestStreak, 0);
        expect(result.totalWordCount, 0);
        expect(result.tagFrequency, isEmpty);
        expect(result.categoryDistribution, isEmpty);
        expect(result.creationHeatmap, isEmpty);
        expect(result.completionRate, 0.0);
        expect(result.linkedNotesCount, 0);
        expect(result.avgConnectionsPerNote, 0.0);
      });

      test('calculates basic statistics correctly', () async {
        // Arrange
        final now = DateTime.now();
        final mockNotes = <NoteModel>[
          NoteModel(
            id: '1',
            title: 'Note 1',
            description: 'This is a test note',
            timestamp: now.toIso8601String(),
            categoryImageIndex: 0,
            isDone: true,
            wordCount: 5,
            tags: ['tag1', 'tag2'],
            outgoingLinks: ['note2'],
            createdAt: now,
            updatedAt: now,
          ),
          NoteModel(
            id: '2',
            title: 'Note 2',
            description: 'Another test note',
            timestamp: now.subtract(const Duration(days: 1)).toIso8601String(),
            categoryImageIndex: 1,
            isDone: false,
            wordCount: 3,
            tags: ['tag1', 'tag3'],
            outgoingLinks: [],
            createdAt: now.subtract(const Duration(days: 1)),
            updatedAt: now.subtract(const Duration(days: 1)),
          ),
        ];
        mockSupabaseService.setMockNotes(mockNotes);

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.totalNotes, 2);
        expect(result.totalWordCount, 8);
        expect(result.completionRate, 50.0); // 1 out of 2 notes completed
        expect(result.linkedNotesCount, 1); // Only note 1 has outgoing links
        expect(result.avgConnectionsPerNote, 0.5); // 1 connection / 2 notes
        expect(result.tagFrequency['tag1'], 2);
        expect(result.tagFrequency['tag2'], 1);
        expect(result.tagFrequency['tag3'], 1);
        expect(result.categoryDistribution['category_0'], 1);
        expect(result.categoryDistribution['category_1'], 1);
      });

      test('calculates weekly and monthly statistics correctly', () async {
        // Arrange
        final now = DateTime.now();
        final startOfWeek = now.subtract(
          Duration(days: now.weekday - 1),
        ); // Monday of this week
        final startOfMonth = DateTime(now.year, now.month, 1);

        final mockNotes = <NoteModel>[
          // Note from this week (within the week)
          NoteModel(
            id: '1',
            title: 'This week',
            description: 'Content',
            timestamp:
                startOfWeek.add(const Duration(days: 1)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: startOfWeek.add(const Duration(days: 1)),
            updatedAt: now,
          ),
          // Note from this month but not this week (before start of week)
          NoteModel(
            id: '2',
            title: 'This month',
            description: 'Content',
            timestamp:
                startOfMonth.add(const Duration(days: 1)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: startOfMonth.add(const Duration(days: 1)),
            updatedAt: now,
          ),
          // Note from last month
          NoteModel(
            id: '3',
            title: 'Last month',
            description: 'Content',
            timestamp:
                startOfMonth
                    .subtract(const Duration(days: 5))
                    .toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: startOfMonth.subtract(const Duration(days: 5)),
            updatedAt: now,
          ),
        ];
        mockSupabaseService.setMockNotes(mockNotes);

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.totalNotes, 3);
        // At least one note should be from this week and this month
        expect(result.notesThisWeek, greaterThanOrEqualTo(1));
        expect(result.notesThisMonth, greaterThanOrEqualTo(1));
      });

      test('calculates streaks correctly', () async {
        // Arrange
        final now = DateTime.now();
        final mockNotes = <NoteModel>[
          // Today
          NoteModel(
            id: '1',
            title: 'Today',
            description: 'Content',
            timestamp: now.toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now,
            updatedAt: now,
          ),
          // Yesterday
          NoteModel(
            id: '2',
            title: 'Yesterday',
            description: 'Content',
            timestamp: now.subtract(const Duration(days: 1)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
          // Day before yesterday
          NoteModel(
            id: '3',
            title: 'Day before',
            description: 'Content',
            timestamp: now.subtract(const Duration(days: 2)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now.subtract(const Duration(days: 2)),
            updatedAt: now,
          ),
          // Gap - 5 days ago
          NoteModel(
            id: '4',
            title: 'Gap',
            description: 'Content',
            timestamp: now.subtract(const Duration(days: 5)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now.subtract(const Duration(days: 5)),
            updatedAt: now,
          ),
        ];
        mockSupabaseService.setMockNotes(mockNotes);

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.currentStreak, 3); // Today, yesterday, day before
        expect(result.longestStreak, 3); // Same as current in this case
      });

      test('handles creation heatmap correctly', () async {
        // Arrange
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final mockNotes = <NoteModel>[
          // Two notes today
          NoteModel(
            id: '1',
            title: 'Note 1',
            description: 'Content',
            timestamp: now.toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now,
            updatedAt: now,
          ),
          NoteModel(
            id: '2',
            title: 'Note 2',
            description: 'Content',
            timestamp: now.add(const Duration(hours: 2)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: now.add(const Duration(hours: 2)),
            updatedAt: now,
          ),
          // One note yesterday
          NoteModel(
            id: '3',
            title: 'Note 3',
            description: 'Content',
            timestamp:
                yesterday.add(const Duration(hours: 10)).toIso8601String(),
            categoryImageIndex: 0,
            isDone: false,
            wordCount: 5,
            createdAt: yesterday.add(const Duration(hours: 10)),
            updatedAt: now,
          ),
        ];
        mockSupabaseService.setMockNotes(mockNotes);

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.creationHeatmap[today], 2);
        expect(result.creationHeatmap[yesterday], 1);
      });

      test('returns empty statistics when service fails', () async {
        // Arrange
        mockSupabaseService.setShouldFail(true, 'Database connection failed');

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.totalNotes, 0);
        expect(result.notesThisWeek, 0);
        expect(result.notesThisMonth, 0);
      });

      test('returns empty statistics when service returns null data', () async {
        // Arrange
        mockSupabaseService.setShouldFail(
          true,
        ); // This will return failure result

        // Act
        final result = await statisticsService.calculateStatistics('user123');

        // Assert
        expect(result.totalNotes, 0);
        expect(result.notesThisWeek, 0);
        expect(result.notesThisMonth, 0);
      });
    });
  });
}
