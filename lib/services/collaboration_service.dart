import 'package:flutter/material.dart';
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
/// NOTE: This is a stub implementation for Firebase-to-Supabase migration
/// Full collaboration features will be implemented with Supabase in the future
class CollaborationService {
  // Stub methods that return default values to prevent compilation errors

  Future<bool> canEdit(String userId, String noteId, String ownerId) async {
    // Default: allow editing for now
    return true;
  }

  Future<bool> canView(String userId, String noteId, String noteOwnerId) async {
    // Default: allow viewing for now
    return true;
  }

  Future<String> getUserRole(
    String userId,
    String noteId,
    String noteOwnerId,
  ) async {
    // Default: return owner role
    return 'owner';
  }

  Future<void> updatePresence(
    String noteId,
    String userId,
    String email,
    String displayName,
    PresenceStatus status,
  ) async {
    // Stub: do nothing for now
  }

  void cleanupPresence(String noteId, String userId) {
    // Stub: do nothing for now
  }

  Future<void> shareNote(
    String userId,
    String noteId,
    List<String> collaboratorEmails, {
    CollaboratorRole role = CollaboratorRole.editor,
  }) async {
    // Stub: do nothing for now
  }

  Future<List<CollaboratorModel>> getCollaboratorDetails(
    String userId,
    String noteId,
  ) async {
    // Return empty list for now
    return [];
  }

  Future<void> removeCollaborator(
    String userId,
    String noteId,
    String collaboratorId,
  ) async {
    // Stub: do nothing for now
  }

  Future<void> updateCollaboratorRole(
    String userId,
    String noteId,
    String collaboratorId,
    CollaboratorRole newRole,
  ) async {
    // Stub: do nothing for now
  }

  Stream<List<Collaborator>> getActiveCollaborators(String noteId) {
    // Return empty stream for now
    return Stream.value([]);
  }

  Future<void> broadcastCursorPosition(
    String noteId,
    String userId,
    int position,
  ) async {
    // Stub: do nothing for now
  }

  Stream<NoteChange> listenForChanges(String userId, String noteId) {
    // Return empty stream for now
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

  Future<void> broadcastOperation(String noteId, Operation operation) async {
    // Stub: do nothing for now
  }

  String applyOperationalTransform(
    String localText,
    List<Operation> remoteOps,
  ) {
    // For now, just return the local text unchanged
    return localText;
  }
}
