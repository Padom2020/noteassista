import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../widgets/folder_tree_view.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/move_folder_dialog.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../models/note_model.dart';
import 'edit_note_screen.dart';

/// Screen that displays folders in a tree view and notes for the selected folder
class FolderViewScreen extends StatefulWidget {
  const FolderViewScreen({super.key});

  @override
  State<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  FolderModel? _selectedFolder;

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => _showCreateFolderDialog(context),
            tooltip: 'Create Folder',
          ),
        ],
      ),
      body: Row(
        children: [
          // Folder tree sidebar - takes up 55% of the width (higher priority)
          Flexible(
            flex: 55,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: FolderTreeView(
                selectedFolderId: _selectedFolder?.id,
                onFolderSelected: (folder) {
                  setState(() {
                    _selectedFolder = folder;
                  });
                },
              ),
            ),
          ),

          // Notes list for selected folder - takes up 45% of the width
          Flexible(flex: 45, child: _buildNotesForFolder(userId)),
        ],
      ),
    );
  }

  Widget _buildNotesForFolder(String userId) {
    return StreamBuilder(
      stream: _supabaseService.streamNotesByFolder(_selectedFolder?.id),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Error loading notes: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFolder == null
                        ? 'No notes in root folder'
                        : 'No notes in "${_selectedFolder!.name}"',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Build notes list
        final notes = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFolder == null
                              ? 'All Notes'
                              : _selectedFolder!.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Notes
            ...notes.map((note) => _buildNoteCard(note)),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    return LongPressDraggable<NoteModel>(
      data: note,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 280,
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  note.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildNoteCardContent(note),
      ),
      child: _buildNoteCardContent(note),
    );
  }

  Widget _buildNoteCardContent(NoteModel note) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
          );
        },
        onLongPress: () => _showMoveNoteDialog(note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (note.isDone) ...[
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.drive_file_move, size: 18),
                      onPressed: () => _showMoveNoteDialog(note),
                      tooltip: 'Move to folder',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Flexible(
                    flex: 3,
                    child: Text(
                      note.timestamp,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.label, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Flexible(
                      flex: 2,
                      child: Text(
                        note.tags.take(2).join(', '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final result = await _supabaseService.getFolders();

    if (context.mounted && result.success && result.data != null) {
      await showDialog(
        context: context,
        builder:
            (context) => CreateFolderDialog(
              parentFolderId: _selectedFolder?.id,
              allFolders: result.data!,
            ),
      );
    }
  }

  Future<void> _showMoveNoteDialog(NoteModel note) async {
    final result = await _supabaseService.getFolders();

    if (mounted && result.success && result.data != null) {
      await showDialog(
        context: context,
        builder:
            (context) => MoveFolderDialog(note: note, folders: result.data!),
      );
    }
  }
}
