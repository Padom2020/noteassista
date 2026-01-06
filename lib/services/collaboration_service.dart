import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collaborator_model.dart';

/// Enum representing the presence status of a collaborator
enum PresenceStatus { viewing, editing, away }

/// Model representing a collaborator with presence information
class Collaborator {
  final String userId;
  final String email;
  final String displayName;
  final Color cursorColor;
  final int? cursorPosition;
  final PresenceStatus status;

  Collaborator({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.cursorColor,
    this.cursorPosition,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'cursorColor': cursorColor.toARGB32(),
      'cursorPosition': cursorPosition,
      'status': status.toString(),
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory Collaborator.fromMap(Map<String, dynamic> data) {
    return Collaborator(
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      cursorColor: Color(data['cursorColor'] ?? Colors.blue.toARGB32()),
      cursorPosition: data['cursorPosition'],
      status: PresenceStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => PresenceStatus.viewing,
      ),
    );
  }

  Collaborator copyWith({
    String? userId,
    String? email,
    String? displayName,
    Color? cursorColor,
    int? cursorPosition,
    PresenceStatus? status,
  }) {
    return Collaborator(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      cursorColor: cursorColor ?? this.cursorColor,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      status: status ?? this.status,
    );
  }
}

/// Enum representing the type of operation in collaborative editing
enum OperationType { insert, delete, retain }

/// Model representing an edit operation for operational transform
class Operation {
  final OperationType type;
  final int position;
  final String? text;
  final int? length;
  final DateTime timestamp;
  final String userId;

  Operation({
    required this.type,
    required this.position,
    this.text,
    this.length,
    DateTime? timestamp,
    required this.userId,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'position': position,
      'text': text,
      'length': length,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  factory Operation.fromMap(Map<String, dynamic> data) {
    return Operation(
      type: OperationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => OperationType.retain,
      ),
      position: data['position'] ?? 0,
      text: data['text'],
      length: data['length'],
      timestamp: DateTime.parse(data['timestamp']),
      userId: data['userId'] ?? '',
    );
  }
}

/// Model representing a change to a note
class NoteChange {
  final String noteId;
  final Operation operation;
  final String userId;
  final DateTime timestamp;

  NoteChange({
    required this.noteId,
    required this.operation,
    required this.userId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'operation': operation.toMap(),
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory NoteChange.fromMap(Map<String, dynamic> data) {
    return NoteChange(
      noteId: data['noteId'] ?? '',
      operation: Operation.fromMap(data['operation']),
      userId: data['userId'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
    );
  }
}

/// Service for managing real-time collaborative editing
class CollaborationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> canEdit(String userId, String noteId, String ownerId) async {
    try {
      final response =
          await _supabase
              .from('notes')
              .select('collaborators, owner_id, user_id')
              .eq('id', noteId)
              .single();

      final ownerId = response['owner_id'] as String?;
      final collaborators = response['collaborators'] as List?;

      // Owner can always edit
      if (userId == ownerId) return true;

      // Check if user is a collaborator with editor role
      if (collaborators != null) {
        for (final collab in collaborators) {
          if (collab is Map && collab['userId'] == userId) {
            return collab['role'] == 'editor' || collab['role'] == 'owner';
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }

  Future<bool> canView(String userId, String noteId, String noteOwnerId) async {
    try {
      final response =
          await _supabase
              .from('notes')
              .select('collaborators, owner_id, user_id, is_shared')
              .eq('id', noteId)
              .single();

      final ownerId = response['owner_id'] as String?;
      final isShared = response['is_shared'] as bool? ?? false;
      final collaborators = response['collaborators'] as List?;

      // Owner can always view
      if (userId == ownerId) return true;

      // Check if note is shared and user is a collaborator
      if (isShared && collaborators != null) {
        for (final collab in collaborators) {
          if (collab is Map && collab['userId'] == userId) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking view permission: $e');
      return false;
    }
  }

  Future<String> getUserRole(
    String userId,
    String noteId,
    String noteOwnerId,
  ) async {
    try {
      if (userId == noteOwnerId) return 'owner';

      final response =
          await _supabase
              .from('notes')
              .select('collaborators')
              .eq('id', noteId)
              .single();

      final collaborators = response['collaborators'] as List?;
      if (collaborators != null) {
        for (final collab in collaborators) {
          if (collab is Map && collab['userId'] == userId) {
            return collab['role'] ?? 'viewer';
          }
        }
      }

      return 'viewer';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'viewer';
    }
  }

  Future<void> updatePresence(
    String noteId,
    String userId,
    String email,
    String displayName,
    PresenceStatus status,
  ) async {
    try {
      // Update presence in Supabase
      await _supabase.from('note_presence').upsert({
        'note_id': noteId,
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'status': status.toString().split('.').last,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  void cleanupPresence(String noteId, String userId) {
    // Remove presence record when user leaves
    _supabase
        .from('note_presence')
        .delete()
        .eq('note_id', noteId)
        .eq('user_id', userId)
        .then((_) {
          debugPrint('Presence cleaned up for user $userId');
        })
        .catchError((e) {
          debugPrint('Error cleaning up presence: $e');
        });
  }

  Future<void> shareNote(
    String userId,
    String noteId,
    List<String> collaboratorEmails, {
    CollaboratorRole role = CollaboratorRole.editor,
  }) async {
    try {
      // Get current note data
      final noteResponse =
          await _supabase
              .from('notes')
              .select('collaborators')
              .eq('id', noteId)
              .eq('user_id', userId)
              .single();

      List<Map<String, dynamic>> collaborators =
          List<Map<String, dynamic>>.from(
            (noteResponse['collaborators'] as List?) ?? [],
          );

      // Get user IDs for the emails from profiles table
      for (final email in collaboratorEmails) {
        try {
          final userResponse =
              await _supabase
                  .from('profiles')
                  .select('id, display_name')
                  .eq('email', email)
                  .single();

          final collaboratorId = userResponse['id'] as String;
          final displayName = userResponse['display_name'] as String? ?? email;

          // Check if already a collaborator
          final exists = collaborators.any(
            (c) => c['userId'] == collaboratorId,
          );

          if (!exists) {
            collaborators.add({
              'userId': collaboratorId,
              'email': email,
              'displayName': displayName,
              'role': role.toString().split('.').last,
              'addedAt': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          debugPrint('Error finding user with email $email: $e');
          // Provide a user-friendly error message
          throw Exception(
            'User with email "$email" not found. They may need to sign up first.',
          );
        }
      }

      // Update note with new collaborators and collaborator_ids array
      final collaboratorIds =
          collaborators.map((c) => c['userId'] as String).toList();

      await _supabase
          .from('notes')
          .update({
            'collaborators': collaborators,
            'collaborator_ids': collaboratorIds,
            'is_shared': true,
          })
          .eq('id', noteId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error sharing note: $e');
      rethrow;
    }
  }

  Future<List<CollaboratorModel>> getCollaboratorDetails(
    String userId,
    String noteId,
  ) async {
    try {
      // First try to get the note where user_id matches (user is the creator)
      var response =
          await _supabase
              .from('notes')
              .select('collaborators, owner_id, user_id')
              .eq('id', noteId)
              .single();

      // Check if the current user has access to this note
      final noteUserId = response['user_id'] as String?;
      final ownerId = response['owner_id'] as String?;

      // User must be either the creator (user_id) or the owner (owner_id)
      if (userId != noteUserId && userId != ownerId) {
        debugPrint('User $userId does not have access to note $noteId');
        return [];
      }

      final collaborators = response['collaborators'] as List? ?? [];

      final result = <CollaboratorModel>[];

      // Add owner
      if (ownerId != null) {
        try {
          final ownerResponse =
              await _supabase
                  .from('profiles')
                  .select('email, display_name')
                  .eq('id', ownerId)
                  .single();

          result.add(
            CollaboratorModel(
              userId: ownerId,
              email: ownerResponse['email'] ?? '',
              displayName: ownerResponse['display_name'] ?? 'Owner',
              role: CollaboratorRole.owner,
            ),
          );
        } catch (e) {
          debugPrint('Error fetching owner details: $e');
        }
      }

      // Add collaborators
      for (final collab in collaborators) {
        if (collab is Map) {
          final roleStr = collab['role'] ?? 'viewer';
          final role =
              roleStr == 'editor'
                  ? CollaboratorRole.editor
                  : CollaboratorRole.viewer;

          result.add(
            CollaboratorModel(
              userId: collab['userId'] ?? '',
              email: collab['email'] ?? '',
              displayName: collab['displayName'] ?? collab['email'] ?? '',
              role: role,
            ),
          );
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error getting collaborator details: $e');
      return [];
    }
  }

  Future<void> removeCollaborator(
    String userId,
    String noteId,
    String collaboratorId,
  ) async {
    try {
      final response =
          await _supabase
              .from('notes')
              .select('collaborators')
              .eq('id', noteId)
              .eq('user_id', userId)
              .single();

      List<Map<String, dynamic>> collaborators =
          List<Map<String, dynamic>>.from(
            (response['collaborators'] as List?) ?? [],
          );

      // Remove the collaborator
      collaborators.removeWhere((c) => c['userId'] == collaboratorId);

      // Update collaborator_ids array
      final collaboratorIds =
          collaborators.map((c) => c['userId'] as String).toList();

      // Update note
      await _supabase
          .from('notes')
          .update({
            'collaborators': collaborators,
            'collaborator_ids': collaboratorIds,
            'is_shared': collaborators.isNotEmpty,
          })
          .eq('id', noteId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error removing collaborator: $e');
      rethrow;
    }
  }

  Future<void> updateCollaboratorRole(
    String userId,
    String noteId,
    String collaboratorId,
    CollaboratorRole newRole,
  ) async {
    try {
      final response =
          await _supabase
              .from('notes')
              .select('collaborators')
              .eq('id', noteId)
              .eq('user_id', userId)
              .single();

      List<Map<String, dynamic>> collaborators =
          List<Map<String, dynamic>>.from(
            (response['collaborators'] as List?) ?? [],
          );

      // Update the role
      for (final collab in collaborators) {
        if (collab['userId'] == collaboratorId) {
          collab['role'] = newRole.toString().split('.').last;
          break;
        }
      }

      // Update note
      await _supabase
          .from('notes')
          .update({'collaborators': collaborators})
          .eq('id', noteId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error updating collaborator role: $e');
      rethrow;
    }
  }

  Stream<List<Collaborator>> getActiveCollaborators(String noteId) {
    try {
      // Listen for presence updates from Supabase Realtime using stream
      return _supabase
          .from('note_presence')
          .stream(primaryKey: ['user_id'])
          .eq('note_id', noteId)
          .map((List<Map<String, dynamic>> data) {
            return data.map((item) {
              return Collaborator(
                userId: item['user_id'] ?? '',
                email: item['email'] ?? '',
                displayName: item['display_name'] ?? '',
                cursorColor: Colors.blue,
                status: PresenceStatus.values.firstWhere(
                  (e) => e.toString().split('.').last == item['status'],
                  orElse: () => PresenceStatus.viewing,
                ),
              );
            }).toList();
          });
    } catch (e) {
      debugPrint('Error getting active collaborators: $e');
      return Stream.value([]);
    }
  }

  Future<void> broadcastCursorPosition(
    String noteId,
    String userId,
    int position,
  ) async {
    try {
      // Broadcast cursor position to other collaborators
      await _supabase.from('cursor_positions').upsert({
        'note_id': noteId,
        'user_id': userId,
        'position': position,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error broadcasting cursor position: $e');
    }
  }

  Future<void> broadcastOperation(String noteId, Operation operation) async {
    try {
      // Broadcast the operation to other collaborators
      await _supabase.from('note_operations').insert({
        'note_id': noteId,
        'user_id': operation.userId,
        'type': operation.type.toString().split('.').last,
        'position': operation.position,
        'text': operation.text,
        'length': operation.length,
        'timestamp': operation.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error broadcasting operation: $e');
    }
  }

  Stream<NoteChange> listenForChanges(String userId, String noteId) {
    try {
      // Listen for changes from other collaborators using stream
      return _supabase
          .from('note_operations')
          .stream(primaryKey: ['id'])
          .eq('note_id', noteId)
          .map((List<Map<String, dynamic>> data) {
            if (data.isEmpty) {
              return NoteChange(
                noteId: noteId,
                operation: Operation(
                  type: OperationType.retain,
                  position: 0,
                  userId: userId,
                ),
                userId: userId,
              );
            }
            final item = data.first;
            return NoteChange(
              noteId: item['note_id'] ?? noteId,
              operation: Operation(
                type: OperationType.values.firstWhere(
                  (e) => e.toString().split('.').last == item['type'],
                  orElse: () => OperationType.retain,
                ),
                position: item['position'] ?? 0,
                text: item['text'],
                length: item['length'],
                timestamp: DateTime.parse(item['timestamp']),
                userId: item['user_id'] ?? userId,
              ),
              userId: item['user_id'] ?? userId,
            );
          });
    } catch (e) {
      debugPrint('Error listening for changes: $e');
      return Stream.value(
        NoteChange(
          noteId: noteId,
          operation: Operation(
            type: OperationType.retain,
            position: 0,
            userId: userId,
          ),
          userId: userId,
        ),
      );
    }
  }

  String applyOperationalTransform(
    String localText,
    List<Operation> remoteOps,
  ) {
    // For now, just return the local text unchanged
    return localText;
  }
}
