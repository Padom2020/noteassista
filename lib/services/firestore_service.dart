import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/template_model.dart';

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

  // ==================== Folder Management Methods ====================

  // Create a new folder
  Future<String> createFolder(String userId, FolderModel folder) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .add(folder.toMap());
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('Firestore error creating folder: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error creating folder: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Update an existing folder
  Future<void> updateFolder(
    String userId,
    String folderId,
    FolderModel folder,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .doc(folderId)
          .update(folder.toMap());
    } on FirebaseException catch (e) {
      debugPrint('Firestore error updating folder: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error updating folder: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Delete a folder and reassign its notes to parent folder or root
  Future<void> deleteFolder(
    String userId,
    String folderId, {
    String? targetFolderId,
  }) async {
    try {
      // Get all notes in this folder
      final notesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .where('folderId', isEqualTo: folderId)
              .get();

      // Get the folder to check if it has a parent
      final folderDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('folders')
              .doc(folderId)
              .get();

      if (!folderDoc.exists) {
        throw Exception('Folder not found');
      }

      final folderData = folderDoc.data() as Map<String, dynamic>;
      final parentId = folderData['parentId'] as String?;

      // Determine where to move notes
      final newFolderId = targetFolderId ?? parentId;

      // Update all notes to move them to the target folder
      final batch = _firestore.batch();
      for (var noteDoc in notesSnapshot.docs) {
        batch.update(noteDoc.reference, {'folderId': newFolderId});
      }

      // Update note count for parent folder if moving notes there
      if (newFolderId != null && notesSnapshot.docs.isNotEmpty) {
        final parentFolderRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(newFolderId);

        final parentFolderDoc = await parentFolderRef.get();
        if (parentFolderDoc.exists) {
          final currentCount =
              (parentFolderDoc.data()?['noteCount'] as int?) ?? 0;
          batch.update(parentFolderRef, {
            'noteCount': currentCount + notesSnapshot.docs.length,
          });
        }
      }

      // Delete the folder
      batch.delete(folderDoc.reference);

      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error deleting folder: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error deleting folder: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Get all folders with hierarchy support
  Future<List<FolderModel>> getFolders(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('folders')
              .orderBy('createdAt', descending: false)
              .get();

      return snapshot.docs
          .map((doc) => FolderModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error getting folders: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error getting folders: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Stream folders for real-time updates
  Stream<QuerySnapshot> streamFolders(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Move a note to a different folder
  Future<void> moveNoteToFolder(
    String userId,
    String noteId,
    String? newFolderId,
  ) async {
    try {
      final noteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(noteId);

      // Get the note to find its current folder
      final noteDoc = await noteRef.get();
      if (!noteDoc.exists) {
        throw Exception('Note not found');
      }

      final noteData = noteDoc.data() as Map<String, dynamic>;
      final oldFolderId = noteData['folderId'] as String?;

      // If moving to the same folder, do nothing
      if (oldFolderId == newFolderId) {
        return;
      }

      final batch = _firestore.batch();

      // Update the note's folderId
      batch.update(noteRef, {'folderId': newFolderId});

      // Decrement note count in old folder
      if (oldFolderId != null) {
        final oldFolderRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(oldFolderId);

        final oldFolderDoc = await oldFolderRef.get();
        if (oldFolderDoc.exists) {
          final currentCount = (oldFolderDoc.data()?['noteCount'] as int?) ?? 0;
          batch.update(oldFolderRef, {
            'noteCount': currentCount > 0 ? currentCount - 1 : 0,
          });
        }
      }

      // Increment note count in new folder
      if (newFolderId != null) {
        final newFolderRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(newFolderId);

        final newFolderDoc = await newFolderRef.get();
        if (newFolderDoc.exists) {
          final currentCount = (newFolderDoc.data()?['noteCount'] as int?) ?? 0;
          batch.update(newFolderRef, {'noteCount': currentCount + 1});
        }
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error moving note to folder: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error moving note to folder: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Stream notes filtered by folder
  Stream<QuerySnapshot> streamNotesByFolder(
    String userId,
    String? folderId, {
    bool? isDone,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notes');

    // Filter by folderId (null means root/no folder)
    if (folderId != null) {
      query = query.where('folderId', isEqualTo: folderId);
    } else {
      query = query.where('folderId', isNull: true);
    }

    // Optionally filter by isDone status
    if (isDone != null) {
      query = query.where('isDone', isEqualTo: isDone);
    }

    return query.snapshots();
  }

  // Get notes by folder (one-time fetch)
  Future<List<NoteModel>> getNotesByFolder(
    String userId,
    String? folderId, {
    bool? isDone,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('notes');

      // Filter by folderId
      if (folderId != null) {
        query = query.where('folderId', isEqualTo: folderId);
      } else {
        query = query.where('folderId', isNull: true);
      }

      // Optionally filter by isDone status
      if (isDone != null) {
        query = query.where('isDone', isEqualTo: isDone);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error getting notes by folder: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error getting notes by folder: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Toggle folder favorite status
  Future<void> toggleFolderFavorite(
    String userId,
    String folderId,
    bool isFavorite,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .doc(folderId)
          .update({'isFavorite': isFavorite});
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error toggling folder favorite: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error toggling folder favorite: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Update folder color
  Future<void> updateFolderColor(
    String userId,
    String folderId,
    String color,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .doc(folderId)
          .update({'color': color});
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error updating folder color: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error updating folder color: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // ==================== Template Management Methods ====================

  // Create a new template
  Future<String> createTemplate(String userId, TemplateModel template) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('templates')
          .add(template.toMap());
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('Firestore error creating template: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error creating template: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Update an existing template
  Future<void> updateTemplate(
    String userId,
    String templateId,
    TemplateModel template,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('templates')
          .doc(templateId)
          .update(template.toMap());
    } on FirebaseException catch (e) {
      debugPrint('Firestore error updating template: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error updating template: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Delete a template
  Future<void> deleteTemplate(String userId, String templateId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('templates')
          .doc(templateId)
          .delete();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error deleting template: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error deleting template: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Get all templates for a user
  Future<List<TemplateModel>> getTemplates(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('templates')
              .orderBy('usageCount', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => TemplateModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error getting templates: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error getting templates: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Stream templates for real-time updates
  Stream<QuerySnapshot> streamTemplates(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('templates')
        .orderBy('usageCount', descending: true)
        .snapshots();
  }

  // Increment template usage count
  Future<void> incrementTemplateUsage(String userId, String templateId) async {
    try {
      final templateRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('templates')
          .doc(templateId);

      await _firestore.runTransaction((transaction) async {
        final templateDoc = await transaction.get(templateRef);
        if (!templateDoc.exists) {
          throw Exception('Template not found');
        }

        final currentUsage = (templateDoc.data()?['usageCount'] as int?) ?? 0;
        transaction.update(templateRef, {'usageCount': currentUsage + 1});
      });
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error incrementing template usage: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error incrementing template usage: $e');
      throw Exception(_getErrorMessage(e));
    }
  }

  // Create predefined templates for a new user
  Future<void> createPredefinedTemplates(String userId) async {
    try {
      final batch = _firestore.batch();
      final templatesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('templates');

      // Meeting Notes Template
      final meetingTemplate = TemplateModel(
        id: '',
        name: 'Meeting Notes',
        description:
            'Template for capturing meeting discussions and action items',
        content: '''# {{meeting_title}}

**Date:** {{date}}
**Attendees:** {{attendees}}
**Duration:** {{duration}}

## Agenda
- {{agenda_item_1}}
- {{agenda_item_2}}
- {{agenda_item_3}}

## Discussion Points
{{discussion_notes}}

## Action Items
- [ ] {{action_item_1}} - Assigned to: {{assignee_1}}
- [ ] {{action_item_2}} - Assigned to: {{assignee_2}}
- [ ] {{action_item_3}} - Assigned to: {{assignee_3}}

## Next Steps
{{next_steps}}

## Next Meeting
**Date:** {{next_meeting_date}}
**Time:** {{next_meeting_time}}''',
        variables: [
          TemplateVariable(
            name: 'meeting_title',
            placeholder: 'Enter meeting title',
            required: true,
          ),
          TemplateVariable(
            name: 'date',
            placeholder: 'Enter meeting date',
            required: true,
          ),
          TemplateVariable(
            name: 'attendees',
            placeholder: 'List attendees',
            required: true,
          ),
          TemplateVariable(
            name: 'duration',
            placeholder: 'Meeting duration',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_1',
            placeholder: 'First agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_2',
            placeholder: 'Second agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_3',
            placeholder: 'Third agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'discussion_notes',
            placeholder: 'Key discussion points',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_1',
            placeholder: 'First action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_1',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_2',
            placeholder: 'Second action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_2',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_3',
            placeholder: 'Third action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_3',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'next_steps',
            placeholder: 'What happens next',
            required: false,
          ),
          TemplateVariable(
            name: 'next_meeting_date',
            placeholder: 'Next meeting date',
            required: false,
          ),
          TemplateVariable(
            name: 'next_meeting_time',
            placeholder: 'Next meeting time',
            required: false,
          ),
        ],
        isCustom: false,
      );

      // Project Plan Template
      final projectTemplate = TemplateModel(
        id: '',
        name: 'Project Plan',
        description: 'Template for planning and tracking project progress',
        content: '''# {{project_name}}

## Project Overview
**Start Date:** {{start_date}}
**End Date:** {{end_date}}
**Project Manager:** {{project_manager}}
**Team Members:** {{team_members}}

## Objectives
{{project_objectives}}

## Scope
### In Scope
- {{in_scope_1}}
- {{in_scope_2}}
- {{in_scope_3}}

### Out of Scope
- {{out_scope_1}}
- {{out_scope_2}}

## Milestones
- [ ] {{milestone_1}} - Due: {{milestone_1_date}}
- [ ] {{milestone_2}} - Due: {{milestone_2_date}}
- [ ] {{milestone_3}} - Due: {{milestone_3_date}}

## Tasks
- [ ] {{task_1}}
- [ ] {{task_2}}
- [ ] {{task_3}}
- [ ] {{task_4}}

## Resources Required
{{resources}}

## Risks and Mitigation
{{risks}}

## Success Criteria
{{success_criteria}}''',
        variables: [
          TemplateVariable(
            name: 'project_name',
            placeholder: 'Enter project name',
            required: true,
          ),
          TemplateVariable(
            name: 'start_date',
            placeholder: 'Project start date',
            required: true,
          ),
          TemplateVariable(
            name: 'end_date',
            placeholder: 'Project end date',
            required: true,
          ),
          TemplateVariable(
            name: 'project_manager',
            placeholder: 'Project manager name',
            required: true,
          ),
          TemplateVariable(
            name: 'team_members',
            placeholder: 'List team members',
            required: false,
          ),
          TemplateVariable(
            name: 'project_objectives',
            placeholder: 'What are the main goals?',
            required: true,
          ),
          TemplateVariable(
            name: 'in_scope_1',
            placeholder: 'First in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'in_scope_2',
            placeholder: 'Second in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'in_scope_3',
            placeholder: 'Third in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'out_scope_1',
            placeholder: 'First out-of-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'out_scope_2',
            placeholder: 'Second out-of-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_1',
            placeholder: 'First milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_1_date',
            placeholder: 'Milestone 1 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_2',
            placeholder: 'Second milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_2_date',
            placeholder: 'Milestone 2 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_3',
            placeholder: 'Third milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_3_date',
            placeholder: 'Milestone 3 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'task_1',
            placeholder: 'First task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_2',
            placeholder: 'Second task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_3',
            placeholder: 'Third task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_4',
            placeholder: 'Fourth task',
            required: false,
          ),
          TemplateVariable(
            name: 'resources',
            placeholder: 'Required resources',
            required: false,
          ),
          TemplateVariable(
            name: 'risks',
            placeholder: 'Potential risks and mitigation',
            required: false,
          ),
          TemplateVariable(
            name: 'success_criteria',
            placeholder: 'How will success be measured?',
            required: false,
          ),
        ],
        isCustom: false,
      );

      // Daily Journal Template
      final journalTemplate = TemplateModel(
        id: '',
        name: 'Daily Journal',
        description: 'Template for daily reflection and planning',
        content: '''# Daily Journal - {{date}}

## Morning Reflection
**Mood:** {{morning_mood}}
**Energy Level:** {{energy_level}}
**Today's Focus:** {{todays_focus}}

## Goals for Today
- [ ] {{goal_1}}
- [ ] {{goal_2}}
- [ ] {{goal_3}}

## Gratitude
I'm grateful for:
1. {{gratitude_1}}
2. {{gratitude_2}}
3. {{gratitude_3}}

## Key Events
{{key_events}}

## Lessons Learned
{{lessons_learned}}

## Tomorrow's Priorities
- {{priority_1}}
- {{priority_2}}
- {{priority_3}}

## Evening Reflection
**How did today go?** {{evening_reflection}}
**What could be improved?** {{improvements}}''',
        variables: [
          TemplateVariable(
            name: 'date',
            placeholder: 'Enter date',
            required: true,
          ),
          TemplateVariable(
            name: 'morning_mood',
            placeholder: 'How are you feeling?',
            required: false,
          ),
          TemplateVariable(
            name: 'energy_level',
            placeholder: 'High/Medium/Low',
            required: false,
          ),
          TemplateVariable(
            name: 'todays_focus',
            placeholder: 'Main focus for today',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_1',
            placeholder: 'First goal',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_2',
            placeholder: 'Second goal',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_3',
            placeholder: 'Third goal',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_1',
            placeholder: 'First thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_2',
            placeholder: 'Second thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_3',
            placeholder: 'Third thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'key_events',
            placeholder: 'Important events today',
            required: false,
          ),
          TemplateVariable(
            name: 'lessons_learned',
            placeholder: 'What did you learn?',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_1',
            placeholder: 'First priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_2',
            placeholder: 'Second priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_3',
            placeholder: 'Third priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'evening_reflection',
            placeholder: 'Reflect on your day',
            required: false,
          ),
          TemplateVariable(
            name: 'improvements',
            placeholder: 'What could be better?',
            required: false,
          ),
        ],
        isCustom: false,
      );

      // Book Notes Template
      final bookTemplate = TemplateModel(
        id: '',
        name: 'Book Notes',
        description: 'Template for capturing insights from books',
        content: '''# {{book_title}}

**Author:** {{author}}
**Genre:** {{genre}}
**Pages:** {{pages}}
**Date Started:** {{date_started}}
**Date Finished:** {{date_finished}}
**Rating:** {{rating}}/5

## Summary
{{book_summary}}

## Key Themes
- {{theme_1}}
- {{theme_2}}
- {{theme_3}}

## Important Quotes
> "{{quote_1}}" - Page {{quote_1_page}}

> "{{quote_2}}" - Page {{quote_2_page}}

> "{{quote_3}}" - Page {{quote_3_page}}

## Key Insights
{{key_insights}}

## Action Items
- [ ] {{action_1}}
- [ ] {{action_2}}
- [ ] {{action_3}}

## Personal Reflection
{{personal_reflection}}

## Recommended For
{{recommendations}}''',
        variables: [
          TemplateVariable(
            name: 'book_title',
            placeholder: 'Enter book title',
            required: true,
          ),
          TemplateVariable(
            name: 'author',
            placeholder: 'Author name',
            required: true,
          ),
          TemplateVariable(
            name: 'genre',
            placeholder: 'Book genre',
            required: false,
          ),
          TemplateVariable(
            name: 'pages',
            placeholder: 'Number of pages',
            required: false,
          ),
          TemplateVariable(
            name: 'date_started',
            placeholder: 'When did you start?',
            required: false,
          ),
          TemplateVariable(
            name: 'date_finished',
            placeholder: 'When did you finish?',
            required: false,
          ),
          TemplateVariable(
            name: 'rating',
            placeholder: 'Rate 1-5',
            required: false,
          ),
          TemplateVariable(
            name: 'book_summary',
            placeholder: 'Brief summary of the book',
            required: false,
          ),
          TemplateVariable(
            name: 'theme_1',
            placeholder: 'First key theme',
            required: false,
          ),
          TemplateVariable(
            name: 'theme_2',
            placeholder: 'Second key theme',
            required: false,
          ),
          TemplateVariable(
            name: 'theme_3',
            placeholder: 'Third key theme',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_1',
            placeholder: 'Important quote',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_1_page',
            placeholder: 'Page number',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_2',
            placeholder: 'Important quote',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_2_page',
            placeholder: 'Page number',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_3',
            placeholder: 'Important quote',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_3_page',
            placeholder: 'Page number',
            required: false,
          ),
          TemplateVariable(
            name: 'key_insights',
            placeholder: 'Main takeaways',
            required: false,
          ),
          TemplateVariable(
            name: 'action_1',
            placeholder: 'First action to take',
            required: false,
          ),
          TemplateVariable(
            name: 'action_2',
            placeholder: 'Second action to take',
            required: false,
          ),
          TemplateVariable(
            name: 'action_3',
            placeholder: 'Third action to take',
            required: false,
          ),
          TemplateVariable(
            name: 'personal_reflection',
            placeholder: 'Your thoughts on the book',
            required: false,
          ),
          TemplateVariable(
            name: 'recommendations',
            placeholder: 'Who should read this?',
            required: false,
          ),
        ],
        isCustom: false,
      );

      // Recipe Template
      final recipeTemplate = TemplateModel(
        id: '',
        name: 'Recipe',
        description: 'Template for documenting cooking recipes',
        content: '''# {{recipe_name}}

**Cuisine:** {{cuisine}}
**Prep Time:** {{prep_time}}
**Cook Time:** {{cook_time}}
**Total Time:** {{total_time}}
**Servings:** {{servings}}
**Difficulty:** {{difficulty}}

## Description
{{recipe_description}}

## Ingredients
- {{ingredient_1}}
- {{ingredient_2}}
- {{ingredient_3}}
- {{ingredient_4}}
- {{ingredient_5}}
- {{ingredient_6}}

## Instructions
1. {{step_1}}
2. {{step_2}}
3. {{step_3}}
4. {{step_4}}
5. {{step_5}}

## Tips & Notes
{{tips_notes}}

## Nutritional Information
{{nutrition_info}}

## Source
{{recipe_source}}

## Rating
{{rating}}/5 stars

## Modifications
{{modifications}}''',
        variables: [
          TemplateVariable(
            name: 'recipe_name',
            placeholder: 'Enter recipe name',
            required: true,
          ),
          TemplateVariable(
            name: 'cuisine',
            placeholder: 'Type of cuisine',
            required: false,
          ),
          TemplateVariable(
            name: 'prep_time',
            placeholder: 'Preparation time',
            required: false,
          ),
          TemplateVariable(
            name: 'cook_time',
            placeholder: 'Cooking time',
            required: false,
          ),
          TemplateVariable(
            name: 'total_time',
            placeholder: 'Total time needed',
            required: false,
          ),
          TemplateVariable(
            name: 'servings',
            placeholder: 'Number of servings',
            required: false,
          ),
          TemplateVariable(
            name: 'difficulty',
            placeholder: 'Easy/Medium/Hard',
            required: false,
          ),
          TemplateVariable(
            name: 'recipe_description',
            placeholder: 'Brief description',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_1',
            placeholder: 'First ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_2',
            placeholder: 'Second ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_3',
            placeholder: 'Third ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_4',
            placeholder: 'Fourth ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_5',
            placeholder: 'Fifth ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'ingredient_6',
            placeholder: 'Sixth ingredient',
            required: false,
          ),
          TemplateVariable(
            name: 'step_1',
            placeholder: 'First step',
            required: false,
          ),
          TemplateVariable(
            name: 'step_2',
            placeholder: 'Second step',
            required: false,
          ),
          TemplateVariable(
            name: 'step_3',
            placeholder: 'Third step',
            required: false,
          ),
          TemplateVariable(
            name: 'step_4',
            placeholder: 'Fourth step',
            required: false,
          ),
          TemplateVariable(
            name: 'step_5',
            placeholder: 'Fifth step',
            required: false,
          ),
          TemplateVariable(
            name: 'tips_notes',
            placeholder: 'Helpful tips',
            required: false,
          ),
          TemplateVariable(
            name: 'nutrition_info',
            placeholder: 'Nutritional details',
            required: false,
          ),
          TemplateVariable(
            name: 'recipe_source',
            placeholder: 'Where did you get this recipe?',
            required: false,
          ),
          TemplateVariable(
            name: 'rating',
            placeholder: 'Rate 1-5',
            required: false,
          ),
          TemplateVariable(
            name: 'modifications',
            placeholder: 'Any changes you made',
            required: false,
          ),
        ],
        isCustom: false,
      );

      // Add all templates to batch
      batch.set(templatesRef.doc(), meetingTemplate.toMap());
      batch.set(templatesRef.doc(), projectTemplate.toMap());
      batch.set(templatesRef.doc(), journalTemplate.toMap());
      batch.set(templatesRef.doc(), bookTemplate.toMap());
      batch.set(templatesRef.doc(), recipeTemplate.toMap());

      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore error creating predefined templates: ${e.code} - ${e.message}',
      );
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected error creating predefined templates: $e');
      throw Exception(_getErrorMessage(e));
    }
  }
}
