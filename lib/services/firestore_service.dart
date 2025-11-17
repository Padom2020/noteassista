import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create user document in Firestore
  Future<void> createUser(String uid, String email) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
    });
  }

  // Create a new note in user's subcollection
  Future<void> createNote(String userId, NoteModel note) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .add(note.toMap());
  }

  // Update an existing note
  Future<void> updateNote(String userId, String noteId, NoteModel note) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update(note.toMap());
  }

  // Delete a note
  Future<void> deleteNote(String userId, String noteId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .delete();
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
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({'isDone': newStatus});
  }
}
