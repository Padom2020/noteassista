import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/collaborator_model.dart';
import 'collaboration_notification_service.dart';

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
      'lastSeen': ServerValue.timestamp,
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final CollaborationNotificationService _notificationService =
      CollaborationNotificationService();

  // Color palette for collaborator cursors
  static const List<Color> _cursorColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  /// Check if user has permission to edit a note
  Future<bool> canEdit(String userId, String noteId, String noteOwnerId) async {
    try {
      // Owner can always edit
      if (userId == noteOwnerId) {
        return true;
      }

      // Check if user is a collaborator with editor or owner role
      final noteRef = _firestore
          .collection('users')
          .doc(noteOwnerId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        return false;
      }

      final noteData = noteDoc.data()!;
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      for (final collab in collaborators) {
        if (collab['userId'] == userId) {
          final role = collab['role'] as String?;
          return role == CollaboratorRole.editor.toString() ||
              role == CollaboratorRole.owner.toString();
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has permission to view a note
  Future<bool> canView(String userId, String noteId, String noteOwnerId) async {
    try {
      // Owner can always view
      if (userId == noteOwnerId) {
        return true;
      }

      // Check if user is a collaborator with any role
      final noteRef = _firestore
          .collection('users')
          .doc(noteOwnerId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        return false;
      }

      final noteData = noteDoc.data()!;
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      for (final collab in collaborators) {
        if (collab['userId'] == userId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the role of a user for a specific note
  Future<CollaboratorRole?> getUserRole(
    String userId,
    String noteId,
    String noteOwnerId,
  ) async {
    try {
      // Owner has owner role
      if (userId == noteOwnerId) {
        return CollaboratorRole.owner;
      }

      final noteRef = _firestore
          .collection('users')
          .doc(noteOwnerId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        return null;
      }

      final noteData = noteDoc.data()!;
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      for (final collab in collaborators) {
        if (collab['userId'] == userId) {
          final roleStr = collab['role'] as String?;
          if (roleStr != null) {
            return CollaboratorRole.values.firstWhere(
              (e) => e.toString() == roleStr,
              orElse: () => CollaboratorRole.viewer,
            );
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Share a note with collaborators by email
  Future<void> shareNote(
    String userId,
    String noteId,
    List<String> collaboratorEmails, {
    CollaboratorRole role = CollaboratorRole.editor,
  }) async {
    try {
      // Get the note reference
      final noteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId);

      // Get current note data
      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        throw Exception('Note not found');
      }

      // Get existing collaborators
      final noteData = noteDoc.data()!;
      final List<dynamic> existingCollaborators =
          noteData['collaborators'] ?? [];
      final List<String> existingCollaboratorIds = List<String>.from(
        noteData['collaboratorIds'] ?? [],
      );

      // Find users by email and add them as collaborators
      final List<Map<String, dynamic>> newCollaborators = [];
      final List<String> newCollaboratorIds = [];

      for (final email in collaboratorEmails) {
        // Query for user with this email
        final userQuery =
            await _firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

        if (userQuery.docs.isNotEmpty) {
          final collaboratorId = userQuery.docs.first.id;
          final userData = userQuery.docs.first.data();

          // Check if not already a collaborator and not the owner
          final alreadyExists = existingCollaborators.any(
            (c) => c['userId'] == collaboratorId,
          );

          if (!alreadyExists && collaboratorId != userId) {
            final collaboratorData = {
              'userId': collaboratorId,
              'email': email,
              'displayName': userData['displayName'] ?? email,
              'role': role.toString(),
              'addedAt': Timestamp.now(),
            };

            newCollaborators.add(collaboratorData);
            newCollaboratorIds.add(collaboratorId);
          }
        }
      }

      // Update note with new collaborators
      if (newCollaborators.isNotEmpty) {
        final updatedCollaborators = [
          ...existingCollaborators,
          ...newCollaborators,
        ];
        final updatedCollaboratorIds = [
          ...existingCollaboratorIds,
          ...newCollaboratorIds,
        ];

        await noteRef.update({
          'isShared': true,
          'collaborators': updatedCollaborators,
          'collaboratorIds': updatedCollaboratorIds,
          'ownerId': userId, // Set owner if not already set
        });

        // Send notifications to new collaborators
        if (newCollaborators.isNotEmpty) {
          // Get note title for notification
          final noteTitle = noteData['title'] ?? 'Untitled Note';

          // Get owner information for notification
          final ownerDoc =
              await _firestore.collection('users').doc(userId).get();
          final ownerName =
              ownerDoc.exists
                  ? (ownerDoc.data()?['displayName'] ?? 'Someone')
                  : 'Someone';

          // Send notifications to new collaborators
          await _notificationService.notifyNewCollaborators(
            noteId: noteId,
            noteTitle: noteTitle,
            ownerName: ownerName,
            newCollaboratorIds: newCollaboratorIds,
            ownerId: userId,
          );
        }
      }
    } on FirebaseException catch (e) {
      throw Exception('Failed to share note: ${e.message}');
    } catch (e) {
      throw Exception('Failed to share note: $e');
    }
  }

  /// Get a stream of active collaborators for a note
  Stream<List<Collaborator>> getActiveCollaborators(String noteId) {
    final presenceRef = _realtimeDb.ref('presence/$noteId');

    return presenceRef.onValue.map((event) {
      final List<Collaborator> collaborators = [];

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((userId, userData) {
          if (userData is Map) {
            final userDataMap = Map<String, dynamic>.from(userData);
            collaborators.add(Collaborator.fromMap(userDataMap));
          }
        });
      }

      return collaborators;
    });
  }

  /// Update the current user's presence status for a note
  Future<void> updatePresence(
    String noteId,
    String userId,
    String email,
    String displayName,
    PresenceStatus status,
  ) async {
    try {
      final presenceRef = _realtimeDb.ref('presence/$noteId/$userId');

      // Assign a cursor color based on user ID
      final colorIndex = userId.hashCode.abs() % _cursorColors.length;
      final cursorColor = _cursorColors[colorIndex];

      final collaborator = Collaborator(
        userId: userId,
        email: email,
        displayName: displayName,
        cursorColor: cursorColor,
        status: status,
      );

      await presenceRef.set(collaborator.toMap());

      // Set up automatic cleanup on disconnect
      await presenceRef.onDisconnect().remove();
    } on FirebaseException catch (e) {
      throw Exception('Failed to update presence: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update presence: $e');
    }
  }

  /// Broadcast cursor position to other collaborators
  Future<void> broadcastCursorPosition(
    String noteId,
    String userId,
    int position,
  ) async {
    try {
      final cursorRef = _realtimeDb.ref(
        'presence/$noteId/$userId/cursorPosition',
      );
      await cursorRef.set(position);
    } on FirebaseException catch (e) {
      throw Exception('Failed to broadcast cursor position: ${e.message}');
    } catch (e) {
      throw Exception('Failed to broadcast cursor position: $e');
    }
  }

  /// Listen for remote changes to a note
  Stream<NoteChange> listenForChanges(String userId, String noteId) {
    final changesRef = _realtimeDb.ref('changes/$noteId');

    return changesRef.onChildAdded
        .map((event) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          return NoteChange.fromMap(data);
        })
        .where((change) => change.userId != userId); // Filter out own changes
  }

  /// Broadcast an edit operation to other collaborators
  Future<void> broadcastOperation(String noteId, Operation operation) async {
    try {
      final changesRef = _realtimeDb.ref('changes/$noteId');
      final newChangeRef = changesRef.push();

      final change = NoteChange(
        noteId: noteId,
        operation: operation,
        userId: operation.userId,
      );

      await newChangeRef.set(change.toMap());

      // Clean up old changes (keep only last 100)
      final snapshot = await changesRef.limitToLast(100).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.length > 100) {
          // Remove oldest entries
          final sortedKeys =
              data.keys.toList()..sort((a, b) {
                final aTime = DateTime.parse(
                  (data[a] as Map)['timestamp'] as String,
                );
                final bTime = DateTime.parse(
                  (data[b] as Map)['timestamp'] as String,
                );
                return aTime.compareTo(bTime);
              });

          for (int i = 0; i < sortedKeys.length - 100; i++) {
            await changesRef.child(sortedKeys[i].toString()).remove();
          }
        }
      }
    } on FirebaseException catch (e) {
      throw Exception('Failed to broadcast operation: ${e.message}');
    } catch (e) {
      throw Exception('Failed to broadcast operation: $e');
    }
  }

  /// Apply operational transform to resolve concurrent edits
  /// This is a simplified implementation of operational transform
  String applyOperationalTransform(
    String localText,
    List<Operation> remoteOps,
  ) {
    String result = localText;

    // Sort operations by timestamp to apply in order
    final sortedOps = List<Operation>.from(remoteOps)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final op in sortedOps) {
      result = _applyOperation(result, op);
    }

    return result;
  }

  /// Apply a single operation to text
  String _applyOperation(String text, Operation op) {
    switch (op.type) {
      case OperationType.insert:
        if (op.text != null && op.position <= text.length) {
          return text.substring(0, op.position) +
              op.text! +
              text.substring(op.position);
        }
        return text;

      case OperationType.delete:
        if (op.length != null &&
            op.position >= 0 &&
            op.position + op.length! <= text.length) {
          return text.substring(0, op.position) +
              text.substring(op.position + op.length!);
        }
        return text;

      case OperationType.retain:
        // Retain operations don't modify the text
        return text;
    }
  }

  /// Update a collaborator's role
  Future<void> updateCollaboratorRole(
    String userId,
    String noteId,
    String collaboratorId,
    CollaboratorRole newRole,
  ) async {
    try {
      final noteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        throw Exception('Note not found');
      }

      final noteData = noteDoc.data()!;
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      // Find and update the collaborator's role
      final updatedCollaborators =
          collaborators.map((collab) {
            if (collab['userId'] == collaboratorId) {
              return {
                ...Map<String, dynamic>.from(collab),
                'role': newRole.toString(),
              };
            }
            return collab;
          }).toList();

      await noteRef.update({'collaborators': updatedCollaborators});
    } on FirebaseException catch (e) {
      throw Exception('Failed to update collaborator role: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update collaborator role: $e');
    }
  }

  /// Remove a collaborator from a note
  Future<void> removeCollaborator(
    String userId,
    String noteId,
    String collaboratorId,
  ) async {
    try {
      final noteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        throw Exception('Note not found');
      }

      final noteData = noteDoc.data()!;
      final List<String> collaboratorIds = List<String>.from(
        noteData['collaboratorIds'] ?? [],
      );
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      // Remove from both lists
      collaboratorIds.remove(collaboratorId);
      final updatedCollaborators =
          collaborators
              .where((collab) => collab['userId'] != collaboratorId)
              .toList();

      await noteRef.update({
        'collaboratorIds': collaboratorIds,
        'collaborators': updatedCollaborators,
        'isShared': collaboratorIds.isNotEmpty,
      });

      // Remove presence data for this collaborator
      final presenceRef = _realtimeDb.ref('presence/$noteId/$collaboratorId');
      await presenceRef.remove();
    } on FirebaseException catch (e) {
      throw Exception('Failed to remove collaborator: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove collaborator: $e');
    }
  }

  /// Clean up presence data when user leaves a note
  Future<void> cleanupPresence(String noteId, String userId) async {
    try {
      final presenceRef = _realtimeDb.ref('presence/$noteId/$userId');
      await presenceRef.remove();
    } on FirebaseException catch (e) {
      throw Exception('Failed to cleanup presence: ${e.message}');
    } catch (e) {
      throw Exception('Failed to cleanup presence: $e');
    }
  }

  /// Get collaborator details from Firestore
  Future<List<CollaboratorModel>> getCollaboratorDetails(
    String userId,
    String noteId,
  ) async {
    try {
      final noteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId);

      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        throw Exception('Note not found');
      }

      final noteData = noteDoc.data()!;
      final List<dynamic> collaborators = noteData['collaborators'] ?? [];

      final List<CollaboratorModel> collaboratorModels = [];

      for (final collab in collaborators) {
        final collaboratorData = Map<String, dynamic>.from(collab);
        collaboratorModels.add(CollaboratorModel.fromMap(collaboratorData));
      }

      return collaboratorModels;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get collaborator details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get collaborator details: $e');
    }
  }
}
