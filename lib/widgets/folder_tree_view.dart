import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../services/supabase_service.dart';
import 'rename_folder_dialog.dart';

/// A widget that displays folders in a hierarchical tree structure
/// with expandable/collapsible nodes, indentation, and folder navigation.
class FolderTreeView extends StatefulWidget {
  /// Callback when a folder is selected
  final Function(FolderModel?)? onFolderSelected;

  /// Currently selected folder ID
  final String? selectedFolderId;

  const FolderTreeView({
    super.key,
    this.onFolderSelected,
    this.selectedFolderId,
  });

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FolderModel>>(
      stream: _supabaseService.streamFolders(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Error loading folders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
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
                  Icon(
                    Icons.folder_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No folders yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create folders to organize your notes',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        // Build folder tree
        final folders = snapshot.data!;

        // Build hierarchical structure
        final rootFolders = _buildFolderHierarchy(folders);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // "All Notes" option
            FolderListTile(
              folder: null,
              isSelected: widget.selectedFolderId == null,
              onTap: () => widget.onFolderSelected?.call(null),
              level: 0,
            ),
            const Divider(height: 1),
            // Folder tree
            ...rootFolders.map(
              (folder) => _buildFolderTree(folder, folders, 0),
            ),
          ],
        );
      },
    );
  }

  /// Build hierarchical folder structure
  List<FolderModel> _buildFolderHierarchy(List<FolderModel> allFolders) {
    return allFolders.where((folder) => folder.parentId == null).toList();
  }

  /// Recursively build folder tree with children
  Widget _buildFolderTree(
    FolderModel folder,
    List<FolderModel> allFolders,
    int level,
  ) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final children = allFolders.where((f) => f.parentId == folder.id).toList();
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FolderListTile(
          folder: folder,
          isSelected: widget.selectedFolderId == folder.id,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          onTap: () => widget.onFolderSelected?.call(folder),
          onExpandToggle:
              hasChildren
                  ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedFolders.remove(folder.id);
                      } else {
                        _expandedFolders.add(folder.id);
                      }
                    });
                  }
                  : null,
          level: level,
        ),
        // Render children if expanded
        if (isExpanded && hasChildren)
          ...children.map(
            (child) => _buildFolderTree(child, allFolders, level + 1),
          ),
      ],
    );
  }
}

/// A list tile widget for displaying individual folders in the tree
class FolderListTile extends StatefulWidget {
  /// The folder to display (null for "All Notes")
  final FolderModel? folder;

  /// Whether this folder is currently selected
  final bool isSelected;

  /// Whether this folder is expanded (showing children)
  final bool isExpanded;

  /// Whether this folder has children
  final bool hasChildren;

  /// Callback when the folder is tapped
  final VoidCallback? onTap;

  /// Callback when the expand/collapse button is tapped
  final VoidCallback? onExpandToggle;

  /// Indentation level (0 = root)
  final int level;

  const FolderListTile({
    super.key,
    required this.folder,
    required this.isSelected,
    this.isExpanded = false,
    this.hasChildren = false,
    this.onTap,
    this.onExpandToggle,
    required this.level,
  });

  @override
  State<FolderListTile> createState() => _FolderListTileState();
}

class _FolderListTileState extends State<FolderListTile> {
  bool _isDragOver = false;

  void _showFolderMenu(BuildContext context) {
    if (widget.folder == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => FolderMenuSheet(folder: widget.folder!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indentation = widget.level * 24.0;
    final isAllNotes = widget.folder == null;

    // Parse color from hex string
    Color folderColor = Colors.blue;
    if (widget.folder != null) {
      try {
        final colorString = widget.folder!.color.replaceAll('#', '');
        folderColor = Color(int.parse('FF$colorString', radix: 16));
      } catch (e) {
        folderColor = Colors.blue;
      }
    }

    return DragTarget<NoteModel>(
      onWillAcceptWithDetails: (details) {
        // Accept notes that are not already in this folder
        return details.data.folderId != widget.folder?.id;
      },
      onAcceptWithDetails: (details) async {
        final note = details.data;
        final supabaseService = SupabaseService.instance;

        try {
          final result = await supabaseService.moveNoteToFolder(
            note.id,
            widget.folder?.id,
          );

          if (context.mounted) {
            if (result.success) {
              final folderName =
                  widget.folder == null ? 'Root' : widget.folder!.name;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Note moved to "$folderName"'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error moving note: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        setState(() => _isDragOver = false);
      },
      onMove: (details) {
        if (!_isDragOver) {
          setState(() => _isDragOver = true);
        }
      },
      onLeave: (data) {
        setState(() => _isDragOver = false);
      },
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          onTap: widget.onTap,
          onLongPress: isAllNotes ? null : () => _showFolderMenu(context),
          child: Container(
            padding: EdgeInsets.only(
              left: 16 + indentation,
              right: 16,
              top: 12,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color:
                  _isDragOver
                      ? folderColor.withValues(alpha: 0.2)
                      : (widget.isSelected
                          ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1)
                          : null),
              border:
                  _isDragOver
                      ? Border.all(color: folderColor, width: 2)
                      : (widget.isSelected
                          ? Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 4,
                            ),
                          )
                          : null),
            ),
            child: Row(
              children: [
                // Expand/collapse button for folders with children
                if (widget.hasChildren)
                  SizedBox(
                    width: 28,
                    child: GestureDetector(
                      onTap: widget.onExpandToggle,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                else if (!isAllNotes)
                  const SizedBox(width: 28),

                // Folder icon with color indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color:
                        isAllNotes
                            ? Colors.grey[300]
                            : folderColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isDragOver
                        ? Icons.folder_open
                        : (isAllNotes
                            ? Icons.home_outlined
                            : (widget.folder!.isFavorite
                                ? Icons.folder_special
                                : Icons.folder_outlined)),
                    size: 20,
                    color: isAllNotes ? Colors.grey[700] : folderColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Folder name - takes most of the space
                Expanded(
                  flex: 3,
                  child: Text(
                    isAllNotes ? 'All Notes' : widget.folder!.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          widget.isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Right side elements - show only menu button to prevent overflow
                if (!isAllNotes)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      icon: Icon(
                        // Show different icons based on folder state
                        widget.folder!.isFavorite
                            ? Icons.star
                            : (widget.folder!.noteCount > 0
                                ? Icons.more_horiz
                                : Icons.more_vert),
                        size: 16,
                        color:
                            widget.folder!.isFavorite
                                ? Colors.amber[700]
                                : Colors.grey[600],
                      ),
                      onPressed: () => _showFolderMenu(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip:
                          widget.folder!.noteCount > 0
                              ? '${widget.folder!.noteCount} notes'
                              : 'Folder options',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet menu for folder actions
class FolderMenuSheet extends StatelessWidget {
  final FolderModel folder;

  const FolderMenuSheet({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService.instance;

    // Parse folder color
    Color folderColor;
    try {
      final colorString = folder.color.replaceAll('#', '');
      folderColor = Color(int.parse('FF$colorString', radix: 16));
    } catch (e) {
      folderColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: folderColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    folder.isFavorite ? Icons.folder_special : Icons.folder,
                    color: folderColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${folder.noteCount} ${folder.noteCount == 1 ? 'note' : 'notes'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          // Menu options
          _buildMenuItem(
            context,
            icon: Icons.edit,
            title: 'Rename',
            onTap: () async {
              Navigator.pop(context);
              final result = await showDialog(
                context: context,
                builder: (context) => RenameFolderDialog(folder: folder),
              );
              if (result == true && context.mounted) {
                // Folder renamed successfully
              }
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.palette,
            title: 'Change Color',
            onTap: () async {
              Navigator.pop(context);
              await _showColorPicker(context, supabaseService);
            },
          ),
          _buildMenuItem(
            context,
            icon: folder.isFavorite ? Icons.star : Icons.star_border,
            title:
                folder.isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
            onTap: () async {
              Navigator.pop(context);
              await _toggleFavorite(context, supabaseService);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.delete,
            title: 'Delete',
            color: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await _deleteFolder(context, supabaseService);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  Future<void> _showColorPicker(
    BuildContext context,
    SupabaseService supabaseService,
  ) async {
    Color selectedColor;
    try {
      final colorString = folder.color.replaceAll('#', '');
      selectedColor = Color(int.parse('FF$colorString', radix: 16));
    } catch (e) {
      selectedColor = Colors.blue;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) async {
                try {
                  final colorHex =
                      '#${color.toARGB32().toRadixString(16).substring(2)}';
                  final result = await supabaseService.updateFolderColor(
                    folder.id,
                    colorHex,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    if (result.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Folder color updated'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error updating color: ${result.error}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating color: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              availableColors: const [
                Colors.red,
                Colors.pink,
                Colors.purple,
                Colors.deepPurple,
                Colors.indigo,
                Colors.blue,
                Colors.lightBlue,
                Colors.cyan,
                Colors.teal,
                Colors.green,
                Colors.lightGreen,
                Colors.lime,
                Colors.yellow,
                Colors.amber,
                Colors.orange,
                Colors.deepOrange,
                Colors.brown,
                Colors.grey,
                Colors.blueGrey,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    SupabaseService supabaseService,
  ) async {
    try {
      final result = await supabaseService.toggleFolderFavorite(
        folder.id,
        !folder.isFavorite,
      );
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                folder.isFavorite
                    ? 'Removed from favorites'
                    : 'Added to favorites',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating favorite: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    SupabaseService supabaseService,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Folder'),
            content: Text(
              'Are you sure you want to delete "${folder.name}"?\n\n'
              'Notes in this folder will be moved to the root folder. '
              'Child folders will also be moved to the root.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final result = await supabaseService.deleteFolder(
        folder.id,
        targetFolderId: folder.parentId, // Move to parent or root
      );
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "${folder.name}" deleted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting folder: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
