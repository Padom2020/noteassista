import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to get user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return "You don't have permission to perform this action";
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again';
        case 'not-found':
          return 'The requested item was not found';
        case 'already-exists':
          return 'This item already exists';
        case 'cancelled':
          return 'Operation was cancelled';
        case 'deadline-exceeded':
          return 'Operation timed out. Please check your connection';
        case 'unauthenticated':
          return 'Please log in to continue';
        case 'resource-exhausted':
          return 'Too many requests. Please try again later';
        default:
          return error.message ?? 'An error occurred. Please try again';
      }
    }
    return 'An unexpected error occurred. Please try again';
  }

  // Create user document in Firestore
  Future<void> createUser(String uid, String email) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore error creating user: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error creating user: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Create a new note in user's subcollection
  Future<void> createNote(String userId, NoteModel note) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .add(note.toMap());
    } on FirebaseException catch (e) {
      debugPrint('Firestore error creating note: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error creating note: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Update an existing note
  Future<void> updateNote(String userId, String noteId, NoteModel note) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId)
          .update(note.toMap());
    } on FirebaseException catch (e) {
      debugPrint('Firestore error updating note: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error updating note: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Delete a note
  Future<void> deleteNote(String userId, String noteId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId)
          .delete();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error deleting note: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error deleting note: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Stream notes filtered by isDone status
  Stream<QuerySnapshot> streamNotes(String userId, bool isDone) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .where('isDone', isEqualTo: isDone)
        .snapshots();
  }

  // Toggle note completion status
  Future<void> toggleNoteStatus(
    String userId,
    String noteId,
    bool newStatus,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId)
          .update({'isDone': newStatus});
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error toggling note status: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error toggling note status: $e');
      throw Exception(_getErrorMessage(e));
    }
  }
}
