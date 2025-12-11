import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/folder_model.dart';
import 'firestore_service.dart';

/// Service to handle data migration for existing users
/// This service adds new fields to existing notes and creates default collections
class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Run all migrations for a user
  /// This is the main entry point for migration
  Future<MigrationResult> runMigrations(String userId) async {
    try {
      debugPrint('Starting migration for user: $userId');

      final result = MigrationResult();

      // Step 1: Migrate existing notes
      final notesResult = await _migrateNotes(userId);
      result.notesUpdated = notesResult.notesUpdated;
      result.errors.addAll(notesResult.errors);

      // Step 2: Create default folders if they don't exist
      final foldersResult = await _createDefaultFolders(userId);
      result.foldersCreated = foldersResult.foldersCreated;
      result.errors.addAll(foldersResult.errors);

      // Step 3: Create default templates if they don't exist
      final templatesResult = await _createDefaultTemplates(userId);
      result.templatesCreated = templatesResult.templatesCreated;
      result.errors.addAll(templatesResult.errors);

      result.success = result.errors.isEmpty;

      debugPrint('Migration completed for user: $userId');
      debugPrint('Notes updated: ${result.notesUpdated}');
      debugPrint('Folders created: ${result.foldersCreated}');
      debugPrint('Templates created: ${result.templatesCreated}');
      debugPrint('Errors: ${result.errors.length}');

      return result;
    } catch (e) {
      debugPrint('Migration failed for user $userId: $e');
      return MigrationResult()
        ..success = false
        ..errors.add('Migration failed: $e');
    }
  }

  /// Migrate existing notes to add new fields
  Future<MigrationResult> _migrateNotes(String userId) async {
    final result = MigrationResult();

    try {
      // Get all notes for the user
      final notesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .get();

      debugPrint('Found ${notesSnapshot.docs.length} notes to migrate');

      // Process notes in batches of 500 (Firestore batch limit)
      const batchSize = 500;
      int totalProcessed = 0;

      for (int i = 0; i < notesSnapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex =
            (i + batchSize < notesSnapshot.docs.length)
                ? i + batchSize
                : notesSnapshot.docs.length;

        final batchDocs = notesSnapshot.docs.sublist(i, endIndex);

        for (final noteDoc in batchDocs) {
          try {
            final data = noteDoc.data();
            final updates = <String, dynamic>{};

            // Add new fields with default values if they don't exist

            // Array fields - default to empty arrays
            if (!data.containsKey('outgoingLinks')) {
              updates['outgoingLinks'] = [];
            }
            if (!data.containsKey('audioUrls')) {
              updates['audioUrls'] = [];
            }
            if (!data.containsKey('imageUrls')) {
              updates['imageUrls'] = [];
            }
            if (!data.containsKey('drawingUrls')) {
              updates['drawingUrls'] = [];
            }
            if (!data.containsKey('collaboratorIds')) {
              updates['collaboratorIds'] = [];
            }
            if (!data.containsKey('collaborators')) {
              updates['collaborators'] = [];
            }

            // Nullable fields - default to null
            if (!data.containsKey('folderId')) {
              updates['folderId'] = null;
            }
            if (!data.containsKey('sourceUrl')) {
              updates['sourceUrl'] = null;
            }
            if (!data.containsKey('reminder')) {
              updates['reminder'] = null;
            }
            if (!data.containsKey('ownerId')) {
              updates['ownerId'] = userId; // Set current user as owner
            }

            // Boolean fields - default to false
            if (!data.containsKey('isShared')) {
              updates['isShared'] = false;
            }

            // Numeric fields - default to 0
            if (!data.containsKey('viewCount')) {
              updates['viewCount'] = 0;
            }

            // Calculate word count if not present
            if (!data.containsKey('wordCount')) {
              final description = data['description'] as String? ?? '';
              updates['wordCount'] = _calculateWordCount(description);
            }

            // Only update if there are changes
            if (updates.isNotEmpty) {
              batch.update(noteDoc.reference, updates);
              totalProcessed++;
            }
          } catch (e) {
            debugPrint('Error migrating note ${noteDoc.id}: $e');
            result.errors.add('Note ${noteDoc.id}: $e');
          }
        }

        // Commit the batch
        if (totalProcessed > 0) {
          await batch.commit();
          debugPrint('Committed batch: $totalProcessed notes updated');
        }
      }

      result.notesUpdated = totalProcessed;
      debugPrint('Total notes migrated: $totalProcessed');
    } catch (e) {
      debugPrint('Error in _migrateNotes: $e');
      result.errors.add('Failed to migrate notes: $e');
    }

    return result;
  }

  /// Create default folders for a user if they don't exist
  Future<MigrationResult> _createDefaultFolders(String userId) async {
    final result = MigrationResult();

    try {
      // Check if user already has folders
      final existingFolders =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('folders')
              .limit(1)
              .get();

      // If folders already exist, skip creation
      if (existingFolders.docs.isNotEmpty) {
        debugPrint(
          'User already has folders, skipping default folder creation',
        );
        return result;
      }

      // Create default folders
      final defaultFolders = [
        FolderModel(
          id: '',
          name: 'Personal',
          color: '#2196F3', // Blue
          noteCount: 0,
          isFavorite: false,
        ),
        FolderModel(
          id: '',
          name: 'Work',
          color: '#4CAF50', // Green
          noteCount: 0,
          isFavorite: false,
        ),
        FolderModel(
          id: '',
          name: 'Ideas',
          color: '#FFC107', // Amber
          noteCount: 0,
          isFavorite: false,
        ),
      ];

      for (final folder in defaultFolders) {
        try {
          await _firestoreService.createFolder(userId, folder);
          result.foldersCreated++;
          debugPrint('Created default folder: ${folder.name}');
        } catch (e) {
          debugPrint('Error creating folder ${folder.name}: $e');
          result.errors.add('Folder ${folder.name}: $e');
        }
      }

      debugPrint('Created ${result.foldersCreated} default folders');
    } catch (e) {
      debugPrint('Error in _createDefaultFolders: $e');
      result.errors.add('Failed to create default folders: $e');
    }

    return result;
  }

  /// Create default templates for a user if they don't exist
  Future<MigrationResult> _createDefaultTemplates(String userId) async {
    final result = MigrationResult();

    try {
      // Check if user already has templates
      final existingTemplates =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('templates')
              .limit(1)
              .get();

      // If templates already exist, skip creation
      if (existingTemplates.docs.isNotEmpty) {
        debugPrint(
          'User already has templates, skipping default template creation',
        );
        return result;
      }

      // Use the FirestoreService method to create predefined templates
      await _firestoreService.createPredefinedTemplates(userId);

      // Count the created templates
      final templatesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('templates')
              .get();

      result.templatesCreated = templatesSnapshot.docs.length;
      debugPrint('Created ${result.templatesCreated} default templates');
    } catch (e) {
      debugPrint('Error in _createDefaultTemplates: $e');
      result.errors.add('Failed to create default templates: $e');
    }

    return result;
  }

  /// Calculate word count from text
  int _calculateWordCount(String text) {
    if (text.isEmpty) return 0;

    // Remove extra whitespace and split by whitespace
    final words = text.trim().split(RegExp(r'\s+'));

    // Filter out empty strings
    return words.where((word) => word.isNotEmpty).length;
  }

  /// Check if a user needs migration
  /// Returns true if the user has notes that need migration
  Future<bool> needsMigration(String userId) async {
    try {
      // Check if any notes are missing the new fields
      final notesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .limit(1)
              .get();

      if (notesSnapshot.docs.isEmpty) {
        // No notes, no migration needed
        return false;
      }

      // Check if the first note has the new fields
      final firstNote = notesSnapshot.docs.first.data();

      // If any of these fields are missing, migration is needed
      final requiredFields = [
        'outgoingLinks',
        'audioUrls',
        'imageUrls',
        'drawingUrls',
        'isShared',
        'collaboratorIds',
        'collaborators',
        'viewCount',
        'wordCount',
      ];

      for (final field in requiredFields) {
        if (!firstNote.containsKey(field)) {
          debugPrint('Migration needed: missing field $field');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      // If we can't check, assume migration is needed to be safe
      return true;
    }
  }

  /// Get migration status for a user
  Future<MigrationStatus> getMigrationStatus(String userId) async {
    try {
      final needsMig = await needsMigration(userId);

      if (!needsMig) {
        return MigrationStatus(
          isComplete: true,
          message: 'No migration needed',
        );
      }

      // Count notes that need migration
      final notesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .get();

      int notesNeedingMigration = 0;
      for (final doc in notesSnapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('wordCount') ||
            !data.containsKey('outgoingLinks')) {
          notesNeedingMigration++;
        }
      }

      return MigrationStatus(
        isComplete: false,
        message: '$notesNeedingMigration notes need migration',
        totalNotes: notesSnapshot.docs.length,
        notesNeedingMigration: notesNeedingMigration,
      );
    } catch (e) {
      debugPrint('Error getting migration status: $e');
      return MigrationStatus(
        isComplete: false,
        message: 'Error checking migration status: $e',
      );
    }
  }
}

/// Result of a migration operation
class MigrationResult {
  bool success = true;
  int notesUpdated = 0;
  int foldersCreated = 0;
  int templatesCreated = 0;
  List<String> errors = [];

  @override
  String toString() {
    return 'MigrationResult(success: $success, notesUpdated: $notesUpdated, '
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
