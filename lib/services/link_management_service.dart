import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import 'supabase_service.dart';

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
  final SupabaseService _supabaseService;

  /// Regular expression to match [[Note Title]] or [[Note Title|Display Text]]
  static final RegExp _linkPattern = RegExp(
    r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
  );

  LinkManagementService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService.instance;

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
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        throw Exception('Failed to get notes: ${result.error}');
      }
      return result.data!
          .where((note) => note.outgoingLinks.contains(noteTitle))
          .toList();
    } catch (e) {
      debugPrint('Error getting backlinks: $e');
      throw Exception('Failed to get backlinks: $e');
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
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return;
      }
      final notes = result.data!;
      final notesToUpdate =
          notes.where((note) => note.outgoingLinks.contains(oldTitle)).toList();

      // Update each note's content and outgoingLinks array
      for (final note in notesToUpdate) {
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

        // Create updated note
        final updatedNote = note.copyWith(
          description: updatedDescription,
          outgoingLinks: updatedLinks,
        );

        await _supabaseService.updateNote(note.id, updatedNote);
      }
    } catch (e) {
      debugPrint('Error updating links on rename: $e');
      throw Exception('Failed to update links: $e');
    }
  }

  /// Create a new note from a link to a non-existent note
  Future<String> createNoteFromLink(String userId, String noteTitle) async {
    try {
      final newNote = NoteModel(
        id: '',
        title: noteTitle,
        description: '',
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        isPinned: false,
        tags: [],
        outgoingLinks: [],
        audioUrls: [],
        imageUrls: [],
        drawingUrls: [],
        isShared: false,
        collaboratorIds: [],
        viewCount: 0,
        wordCount: 0,
      );

      final result = await _supabaseService.createNote(newNote);
      if (result.success && result.data != null) {
        return result.data!;
      } else {
        throw Exception('Failed to create note: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error creating note from link: $e');
      throw Exception('Failed to create note: $e');
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
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return [];
      }
      final notes = result.data!;
      final partialLower = partial.toLowerCase();
      final suggestions = <String>[];

      for (final note in notes) {
        final titleLower = note.title.toLowerCase();
        if (titleLower.contains(partialLower)) {
          suggestions.add(note.title);
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
    } catch (e) {
      debugPrint('Error getting title suggestions: $e');
      throw Exception('Failed to get suggestions: $e');
    }
  }

  /// Build graph data structure for visualization
  /// Creates nodes for each note and edges for links between them
  Future<GraphData> buildNoteGraph(String userId) async {
    try {
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return GraphData(nodes: [], edges: []);
      }
      final notes = result.data!;

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
        // Add outgoing links count
        connectionCounts[note.id] =
            ((connectionCounts[note.id] ?? 0) + note.outgoingLinks.length)
                .toInt();
        // Add incoming links count for targets
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
    } catch (e) {
      debugPrint('Error building note graph: $e');
      throw Exception('Failed to build graph: $e');
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
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return titles.asMap().map((_, title) => MapEntry(title, false));
      }
      final notes = result.data!;
      final existingTitles = <String>{};
      for (final note in notes) {
        existingTitles.add(note.title);
      }

      final resultMap = <String, bool>{};
      for (final title in titles) {
        resultMap[title] = existingTitles.contains(title);
      }

      return resultMap;
    } catch (e) {
      debugPrint('Error checking notes exist: $e');
      throw Exception('Failed to check notes: $e');
    }
  }

  /// Get a note by its title
  Future<NoteModel?> getNoteByTitle(String userId, String title) async {
    try {
      final result = await _supabaseService.getAllNotes();
      if (!result.success || result.data == null) {
        return null;
      }
      final notes = result.data!;
      for (final note in notes) {
        if (note.title == title) {
          return note;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting note by title: $e');
      throw Exception('Failed to get note: $e');
    }
  }
}
