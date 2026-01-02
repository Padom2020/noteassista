/// Service for handling collaboration-related notifications
/// Service for managing collaboration-related notifications
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Full notification features will be implemented with Supabase in the future
class CollaborationNotificationService {
  static final CollaborationNotificationService _instance =
      CollaborationNotificationService._internal();
  factory CollaborationNotificationService() => _instance;
  CollaborationNotificationService._internal();

  bool _isInitialized = false;

  /// Initialize the notification service (stub)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Send notification to new collaborators (stub)
  Future<void> notifyNewCollaborators({
    required String noteId,
    required String noteTitle,
    required String ownerName,
    required List<String> newCollaboratorIds,
    required String ownerId,
  }) async {
    // Stub: do nothing for now
  }

  /// Send notification when note is updated (stub)
  Future<void> notifyNoteUpdate({
    required String noteId,
    required String noteTitle,
    required String updaterName,
    required List<String> collaboratorIds,
  }) async {
    // Stub: do nothing for now
  }

  /// Send notification when collaborator role changes (stub)
  Future<void> notifyRoleChange({
    required String noteId,
    required String noteTitle,
    required String collaboratorId,
    required String newRole,
    required String changedByName,
  }) async {
    // Stub: do nothing for now
  }

  /// Send notification when removed from collaboration (stub)
  Future<void> notifyCollaboratorRemoved({
    required String noteId,
    required String noteTitle,
    required String removedCollaboratorId,
    required String removedByName,
  }) async {
    // Stub: do nothing for now
  }

  /// Send notification when someone comments on a shared note (stub)
  Future<void> notifyCollaboratorsOfComment({
    required String noteId,
    required String noteTitle,
    required String commenterName,
    required String comment,
    required List<String> collaboratorIds,
    required String ownerId,
  }) async {
    // Stub: do nothing for now
  }

  /// Mark all notifications as read for a user (stub)
  Future<void> markNotificationsAsRead(String userId) async {
    // Stub: do nothing for now
  }

  /// Get unread notification count for a user (stub)
  Future<int> getUnreadNotificationCount(String userId) async {
    // Stub: return 0
    return 0;
  }

  /// Get notifications stream (stub)
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    // Return empty stream for now
    return Stream.value([]);
  }
}
