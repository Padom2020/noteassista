import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

/// Represents a parsed link from note content
class NoteLink {
  final String targetTitle;
  final String displayText;
  final int startIndex;
  final int endIndex;
  final bool exists;

  NoteLink({
    required this.targetTitle,
    required this.displayText,
    required this.startIndex,
    required this.endIndex,
    required this.exists,
  });

  @override
  String toString() {
    return 'NoteLink(targetTitle: $targetTitle, displayText: $displayText, '
        'startIndex: $startIndex, endIndex: $endIndex, exists: $exists)';
  }
}

/// Represents a node in the note graph
class GraphNode {
  final String id;
  final String title;
  final int connectionCount;
  final String? category;
  final List<String> tags;
  double x;
  double y;
  double vx;
  double vy;

  GraphNode({
    required this.id,
    required this.title,
    required this.connectionCount,
    this.category,
    this.tags = const [],
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
  });

  @override
  String toString() {
    return 'GraphNode(id: $id, title: $title, connectionCount: $connectionCount)';
  }
}

/// Represents an edge between two nodes in the graph
class GraphEdge {
  final String sourceId;
  final String targetId;

  GraphEdge({required this.sourceId, required this.targetId});

  @override
  String toString() {
    return 'GraphEdge(sourceId: $sourceId, targetId: $targetId)';
  }
}

/// Represents the complete graph data structure
class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  GraphData({required this.nodes, required this.edges});

  @override
  String toString() {
    return 'GraphData(nodes: ${nodes.length}, edges: ${edges.length})';
  }
}

/// Service for managing note links and building knowledge graphs
class LinkManagementService {
  final FirebaseFirestore _firestore;

  /// Regular expression to match [[Note Title]] or [[Note Title|Display Text]]
  static final RegExp _linkPattern = RegExp(
    r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
  );

  LinkManagementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Parse note content to extract all wiki-style links
  /// Supports both [[Note Title]] and [[Note Title|Display Text]] syntax
  List<NoteLink> parseLinks(String content) {
    final List<NoteLink> links = [];
    final matches = _linkPattern.allMatches(content);

    for (final match in matches) {
      final targetTitle = match.group(1)?.trim() ?? '';
      final displayText = match.group(2)?.trim() ?? targetTitle;

      if (targetTitle.isNotEmpty) {
        links.add(
          NoteLink(
            targetTitle: targetTitle,
            displayText: displayText,
            startIndex: match.start,
            endIndex: match.end,
            exists: false, // Will be updated when checking against database
          ),
        );
      }
    }

    return links;
  }

  /// Get all notes that link to the specified note (backlinks)
  Future<List<NoteModel>> getBacklinks(String userId, String noteTitle) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .where('outgoingLinks', arrayContains: noteTitle)
              .get();

      return querySnapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Error getting backlinks: ${e.code} - ${e.message}');
      throw Exception('Failed to get backlinks: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error getting backlinks: $e');
      throw Exception('Failed to get backlinks');
    }
  }

  /// Update all links when a note is renamed
  /// This ensures all references to the old title are updated to the new title
  Future<void> updateLinksOnRename(
    String userId,
    String oldTitle,
    String newTitle,
  ) async {
    try {
      // Get all notes that link to the old title
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .where('outgoingLinks', arrayContains: oldTitle)
              .get();

      // Update each note's content and outgoingLinks array
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        final note = NoteModel.fromFirestore(doc);

        // Replace old title with new title in description
        String updatedDescription = note.description;
        updatedDescription = updatedDescription.replaceAll(
          '[[$oldTitle]]',
          '[[$newTitle]]',
        );
        updatedDescription = updatedDescription.replaceAll(
          '[[$oldTitle|',
          '[[$newTitle|',
        );

        // Update outgoingLinks array
        final updatedLinks =
            note.outgoingLinks.map((link) {
              return link == oldTitle ? newTitle : link;
            }).toList();

        batch.update(doc.reference, {
          'description': updatedDescription,
          'outgoingLinks': updatedLinks,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('Error updating links on rename: ${e.code} - ${e.message}');
      throw Exception('Failed to update links: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error updating links on rename: $e');
      throw Exception('Failed to update links');
    }
  }

  /// Create a new note from a link to a non-existent note
  Future<String> createNoteFromLink(String userId, String noteTitle) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notes')
          .add({
            'title': noteTitle,
            'description': '',
            'timestamp': DateTime.now().toString(),
            'categoryImageIndex': 0,
            'isDone': false,
            'isPinned': false,
            'tags': [],
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'outgoingLinks': [],
            'audioUrls': [],
            'imageUrls': [],
            'drawingUrls': [],
            'isShared': false,
            'collaboratorIds': [],
            'viewCount': 0,
            'wordCount': 0,
          });

      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('Error creating note from link: ${e.code} - ${e.message}');
      throw Exception('Failed to create note: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error creating note from link: $e');
      throw Exception('Failed to create note');
    }
  }

  /// Get note title suggestions for autocomplete
  /// Returns titles that start with or contain the partial string
  Future<List<String>> getNoteTitleSuggestions(
    String userId,
    String partial,
  ) async {
    if (partial.isEmpty) {
      return [];
    }

    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .get();

      final partialLower = partial.toLowerCase();
      final suggestions = <String>[];

      for (final doc in querySnapshot.docs) {
        final title = doc.data()['title'] as String? ?? '';
        final titleLower = title.toLowerCase();

        if (titleLower.contains(partialLower)) {
          suggestions.add(title);
        }
      }

      // Sort suggestions: exact matches first, then starts with, then contains
      suggestions.sort((a, b) {
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();

        if (aLower == partialLower) return -1;
        if (bLower == partialLower) return 1;

        if (aLower.startsWith(partialLower) &&
            !bLower.startsWith(partialLower)) {
          return -1;
        }
        if (!aLower.startsWith(partialLower) &&
            bLower.startsWith(partialLower)) {
          return 1;
        }

        return a.compareTo(b);
      });

      return suggestions.take(10).toList();
    } on FirebaseException catch (e) {
      debugPrint('Error getting title suggestions: ${e.code} - ${e.message}');
      throw Exception('Failed to get suggestions: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error getting title suggestions: $e');
      throw Exception('Failed to get suggestions');
    }
  }

  /// Build graph data structure for visualization
  /// Creates nodes for each note and edges for links between them
  Future<GraphData> buildNoteGraph(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .get();

      final notes =
          querySnapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

      // Create a map of note titles to IDs for quick lookup
      final titleToId = <String, String>{};
      for (final note in notes) {
        titleToId[note.title] = note.id;
      }

      // Build nodes
      final nodes = <GraphNode>[];
      final connectionCounts = <String, int>{};

      // Count connections for each note
      for (final note in notes) {
        connectionCounts[note.id] = note.outgoingLinks.length;
        for (final link in note.outgoingLinks) {
          final targetId = titleToId[link];
          if (targetId != null) {
            connectionCounts[targetId] = (connectionCounts[targetId] ?? 0) + 1;
          }
        }
      }

      // Create nodes with connection counts
      for (final note in notes) {
        nodes.add(
          GraphNode(
            id: note.id,
            title: note.title,
            connectionCount: connectionCounts[note.id] ?? 0,
            tags: note.tags,
          ),
        );
      }

      // Build edges
      final edges = <GraphEdge>[];
      for (final note in notes) {
        for (final link in note.outgoingLinks) {
          final targetId = titleToId[link];
          if (targetId != null) {
            edges.add(GraphEdge(sourceId: note.id, targetId: targetId));
          }
        }
      }

      return GraphData(nodes: nodes, edges: edges);
    } on FirebaseException catch (e) {
      debugPrint('Error building note graph: ${e.code} - ${e.message}');
      throw Exception('Failed to build graph: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error building note graph: $e');
      throw Exception('Failed to build graph');
    }
  }

  /// Check if notes with the given titles exist
  /// Returns a map of title -> exists boolean
  Future<Map<String, bool>> checkNotesExist(
    String userId,
    List<String> titles,
  ) async {
    if (titles.isEmpty) {
      return {};
    }

    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .get();

      final existingTitles = <String>{};
      for (final doc in querySnapshot.docs) {
        final title = doc.data()['title'] as String? ?? '';
        existingTitles.add(title);
      }

      final result = <String, bool>{};
      for (final title in titles) {
        result[title] = existingTitles.contains(title);
      }

      return result;
    } on FirebaseException catch (e) {
      debugPrint('Error checking notes exist: ${e.code} - ${e.message}');
      throw Exception('Failed to check notes: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error checking notes exist: $e');
      throw Exception('Failed to check notes');
    }
  }

  /// Get a note by its title
  Future<NoteModel?> getNoteByTitle(String userId, String title) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notes')
              .where('title', isEqualTo: title)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return NoteModel.fromFirestore(querySnapshot.docs.first);
    } on FirebaseException catch (e) {
      debugPrint('Error getting note by title: ${e.code} - ${e.message}');
      throw Exception('Failed to get note: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error getting note by title: $e');
      throw Exception('Failed to get note');
    }
  }
}
