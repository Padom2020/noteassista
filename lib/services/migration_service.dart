/// Service to handle data migration for existing users
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Migration is complete, this service is no longer needed
class MigrationService {
  /// Run all migrations for a user (stub)
  Future<MigrationResult> runMigrations(String userId) async {
    // Migration is complete, return success
    return MigrationResult();
  }

  /// Check if user needs migration (stub)
  Future<bool> needsMigration(String userId) async {
    // Migration is complete, return false
    return false;
  }

  /// Get migration status for a user (stub)
  Future<MigrationStatus> getMigrationStatus(String userId) async {
    return MigrationStatus(isComplete: true, message: 'Migration is complete');
  }
}

/// Result of migration operations
class MigrationResult {
  int notesUpdated = 0;
  int foldersCreated = 0;
  int templatesCreated = 0;
  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => errors.isEmpty;

  @override
  String toString() {
    return 'MigrationResult(isSuccess: $isSuccess, notesUpdated: $notesUpdated, '
        'foldersCreated: $foldersCreated, templatesCreated: $templatesCreated, '
        'errors: ${errors.length})';
  }
}

/// Status of migration for a user
class MigrationStatus {
  final bool isComplete;
  final String message;
  final int? totalNotes;
  final int? notesNeedingMigration;

  MigrationStatus({
    required this.isComplete,
    required this.message,
    this.totalNotes,
    this.notesNeedingMigration,
  });

  @override
  String toString() {
    return 'MigrationStatus(isComplete: $isComplete, message: $message, '
        'totalNotes: $totalNotes, notesNeedingMigration: $notesNeedingMigration)';
  }
}
