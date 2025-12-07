import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service for managing user presence in Firebase Realtime Database
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
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get reference to presence data for a specific note
  DatabaseReference _getPresenceRef(String noteId) {
    return _database.ref('presence/$noteId');
  }

  /// Get reference to current user's presence for a specific note
  DatabaseReference _getUserPresenceRef(String noteId, String userId) {
    return _database.ref('presence/$noteId/$userId');
  }

  /// Initialize presence for current user on a note
  /// Sets up automatic cleanup on disconnect
  Future<void> initializePresence(String noteId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _getUserPresenceRef(noteId, user.uid);

    // Set up disconnect handler to clean up presence when user disconnects
    await presenceRef.onDisconnect().remove();

    // Set initial presence
    await presenceRef.set({
      'status': 'viewing',
      'cursorPosition': 0,
      'lastSeen': ServerValue.timestamp,
      'displayName': user.displayName ?? 'Anonymous',
      'email': user.email ?? '',
    });
  }

  /// Update user's presence status
  Future<void> updatePresenceStatus(
    String noteId,
    String status, {
    int? cursorPosition,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _getUserPresenceRef(noteId, user.uid);

    final updates = <String, dynamic>{
      'status': status,
      'lastSeen': ServerValue.timestamp,
    };

    if (cursorPosition != null) {
      updates['cursorPosition'] = cursorPosition;
    }

    await presenceRef.update(updates);
  }

  /// Update cursor position for current user
  Future<void> updateCursorPosition(String noteId, int position) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _getUserPresenceRef(noteId, user.uid);

    await presenceRef.update({
      'cursorPosition': position,
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// Remove presence when user leaves a note
  Future<void> removePresence(String noteId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _getUserPresenceRef(noteId, user.uid);
    await presenceRef.remove();
  }

  /// Listen to all active users on a note
  Stream<Map<String, Map<String, dynamic>>> watchPresence(String noteId) {
    final presenceRef = _getPresenceRef(noteId);

    return presenceRef.onValue.map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return <String, Map<String, dynamic>>{};
      }

      // Convert to Map<String, Map<String, dynamic>>
      final presenceMap = <String, Map<String, dynamic>>{};

      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            presenceMap[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      return presenceMap;
    });
  }

  /// Get current active users count on a note
  Future<int> getActiveUsersCount(String noteId) async {
    final presenceRef = _getPresenceRef(noteId);
    final snapshot = await presenceRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return 0;
    }

    if (snapshot.value is Map) {
      return (snapshot.value as Map).length;
    }

    return 0;
  }

  /// Clean up stale presence data (users inactive for more than 5 minutes)
  Future<void> cleanupStalePresence(String noteId) async {
    final presenceRef = _getPresenceRef(noteId);
    final snapshot = await presenceRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final fiveMinutesAgo = now - (5 * 60 * 1000);

    if (snapshot.value is Map) {
      final presenceData = snapshot.value as Map;

      for (var entry in presenceData.entries) {
        final userId = entry.key.toString();
        final userData = entry.value;

        if (userData is Map && userData['lastSeen'] != null) {
          final lastSeen = userData['lastSeen'] as int;

          if (lastSeen < fiveMinutesAgo) {
            await _getUserPresenceRef(noteId, userId).remove();
          }
        }
      }
    }
  }

  /// Mark user as away after period of inactivity
  Future<void> markAsAway(String noteId) async {
    await updatePresenceStatus(noteId, 'away');
  }

  /// Mark user as viewing
  Future<void> markAsViewing(String noteId) async {
    await updatePresenceStatus(noteId, 'viewing');
  }

  /// Mark user as editing
  Future<void> markAsEditing(String noteId) async {
    await updatePresenceStatus(noteId, 'editing');
  }
}
