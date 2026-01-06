import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../services/supabase_service.dart';

/// Dialog for moving a note to a different folder
class MoveFolderDialog extends StatefulWidget {
  /// The note to move
  final NoteModel note;

  /// List of all available folders
  final List<FolderModel> folders;

  const MoveFolderDialog({
    super.key,
    required this.note,
    required this.folders,
  });

  @override
  State<MoveFolderDialog> createState() => _MoveFolderDialogState();
}

class _MoveFolderDialogState extends State<MoveFolderDialog> {
  final SupabaseService _supabaseService = SupabaseService.instance;

  String? _selectedFolderId;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.note.folderId;
  }

  Future<void> _moveNote() async {
    // Check if folder actually changed
    if (_selectedFolderId == widget.note.folderId) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isMoving = true);

    try {
      final result = await _supabaseService.moveNoteToFolder(
        widget.note.id,
        _selectedFolderId,
      );

      if (mounted) {
        if (result.success) {
          final folderName =
              _selectedFolderId == null
                  ? 'Root'
                  : widget.folders
                      .firstWhere((f) => f.id == _selectedFolderId)
                      .name;

          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note moved to "$folderName"'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error moving note: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMoving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move Note'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, color: Colors.grey[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.note.description.isNotEmpty)
                          Text(
                            widget.note.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Folder selection
            const Text(
              'Select destination folder:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Folder list
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Root folder option
                  _buildFolderOption(
                    folderId: null,
                    folderName: 'Root (No folder)',
                    folderColor: Colors.grey,
                    icon: Icons.home_outlined,
                  ),
                  const Divider(height: 1),

                  // All folders
                  ...widget.folders.map((folder) {
                    Color folderColor;
                    try {
                      final colorString = folder.color.replaceAll('#', '');
                      folderColor = Color(
                        int.parse('FF$colorString', radix: 16),
                      );
                    } catch (e) {
                      folderColor = Colors.blue;
                    }

                    return _buildFolderOption(
                      folderId: folder.id,
                      folderName: folder.name,
                      folderColor: folderColor,
                      icon:
                          folder.isFavorite
                              ? Icons.folder_special
                              : Icons.folder,
                      noteCount: folder.noteCount,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isMoving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isMoving ? null : _moveNote,
          child:
              _isMoving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Move'),
        ),
      ],
    );
  }

  Widget _buildFolderOption({
    required String? folderId,
    required String folderName,
    required Color folderColor,
    required IconData icon,
    int? noteCount,
  }) {
    final isSelected = _selectedFolderId == folderId;

    return InkWell(
      onTap: () {
        setState(() => _selectedFolderId = folderId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? folderColor.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? folderColor : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? folderColor : null,
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 12),

            // Folder icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: folderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: folderColor),
            ),
            const SizedBox(width: 12),

            // Folder name
            Expanded(
              child: Text(
                folderName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? folderColor : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Note count
            if (noteCount != null && noteCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  noteCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: folderColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
