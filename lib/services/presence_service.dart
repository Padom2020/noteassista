/// Service for managing user presence in Supabase
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Full presence features will be implemented with Supabase in the future
///
/// Presence data structure:
/// ```
/// presence/
///   {noteId}/
///     {userId}/
///       status: "viewing" | "editing" | "away"
///       cursorPosition: number
///       lastSeen: timestamp
///       displayName: string
///       email: string
/// ```
class PresenceService {
  /// Set user presence for a note (stub)
  Future<void> setPresence(String noteId, String status) async {
    // Stub: do nothing for now
  }

  /// Remove user presence for a note (stub)
  Future<void> removePresence(String noteId) async {
    // Stub: do nothing for now
  }

  /// Get presence stream for a note (stub)
  Stream<Map<String, dynamic>> getPresenceStream(String noteId) {
    // Return empty stream for now
    return Stream.value({});
  }

  /// Update cursor position (stub)
  Future<void> updateCursorPosition(String noteId, int position) async {
    // Stub: do nothing for now
  }

  /// Sets up automatic cleanup on disconnect (stub)
  Future<void> initializePresence(String noteId) async {
    // Stub: do nothing for now
  }

  /// Update user's presence status (stub)
  Future<void> updatePresenceStatus(
    String noteId,
    String status, {
    int? cursorPosition,
  }) async {
    // Stub: do nothing for now
  }

  /// Listen to all active users on a note (stub)
  Stream<Map<String, Map<String, dynamic>>> watchPresence(String noteId) {
    // Return empty stream for now
    return Stream.value(<String, Map<String, dynamic>>{});
  }

  /// Get current active users count on a note (stub)
  Future<int> getActiveUsersCount(String noteId) async {
    // Stub: return 0 for now
    return 0;
  }

  /// Clean up stale presence data (stub)
  Future<void> cleanupStalePresence(String noteId) async {
    // Stub: do nothing for now
  }

  /// Mark user as away after period of inactivity (stub)
  Future<void> markAsAway(String noteId) async {
    // Stub: do nothing for now
  }

  /// Mark user as viewing (stub)
  Future<void> markAsViewing(String noteId) async {
    // Stub: do nothing for now
  }

  /// Mark user as editing (stub)
  Future<void> markAsEditing(String noteId) async {
    // Stub: do nothing for now
  }
}
