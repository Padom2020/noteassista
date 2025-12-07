import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../widgets/clickable_note_link.dart';
import 'add_note_screen.dart';
import 'edit_note_screen.dart';
import 'voice_capture_screen.dart';
import 'graph_view_screen.dart';
import 'folder_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;
  double _lastScrollPosition = 0.0;

  // Folder filtering state
  String? _selectedFolderId;
  String _selectedFolderName = 'All Notes';
  List<FolderModel> _folders = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      try {
        final folders = await _firestoreService.getFolders(userId);
        if (mounted) {
          setState(() {
            _folders = folders;
          });
        }
      } catch (e) {
        // Handle error silently for now
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final currentScrollPosition = _scrollController.position.pixels;
    final isScrollingDown = currentScrollPosition > _lastScrollPosition;
    final isScrollingUp = currentScrollPosition < _lastScrollPosition;

    // Update FAB visibility based on scroll direction
    if (isScrollingDown && _isFabVisible) {
      setState(() {
        _isFabVisible = false;
      });
    } else if (isScrollingUp && !_isFabVisible) {
      setState(() {
        _isFabVisible = true;
      });
    }

    _lastScrollPosition = currentScrollPosition;
  }

  Future<void> _deleteNote(String noteId) async {
    final userId = _authService.currentUser?.uid ?? '';
    try {
      await _firestoreService.deleteNote(userId, noteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNoteStatus(String noteId, bool currentStatus) async {
    final userId = _authService.currentUser?.uid ?? '';
    try {
      await _firestoreService.toggleNoteStatus(userId, noteId, !currentStatus);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditNote(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    // Get category image asset path
    final categoryImages = [
      'assets/images/0.png',
      'assets/images/1.png',
      'assets/images/2.png',
      'assets/images/3.png',
      'assets/images/4.png',
    ];

    final imagePath = categoryImages[note.categoryImageIndex % 5];

    return Card(
      elevation: note.isDone ? 1 : 4,
      shadowColor: note.isDone ? Colors.grey[300] : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: note.isDone ? Colors.grey[300]! : Colors.transparent,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToEditNote(note),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                note.isDone
                    ? null
                    : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.02),
                      ],
                    ),
            color: note.isDone ? Colors.grey[50] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: note.isDone ? Colors.grey[200] : Colors.white,
                    border: Border.all(
                      color:
                          note.isDone
                              ? Colors.grey[300]!
                              : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow:
                        note.isDone
                            ? null
                            : [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: note.isDone ? 0.4 : 1.0,
                      child:
                          note.customImageUrl != null &&
                                  File(note.customImageUrl!).existsSync()
                              ? Image.file(
                                File(note.customImageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 30,
                                  );
                                },
                              )
                              : Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 30,
                                  );
                                },
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Note content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    note.isDone
                                        ? Colors.grey[600]
                                        : Colors.black87,
                                decoration:
                                    note.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                decorationColor: Colors.grey[500],
                                decorationThickness: 2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 22),
                            color: Colors.red[400],
                            onPressed: () => _deleteNote(note.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete note',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClickableNoteLink(
                        content: note.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        defaultStyle: TextStyle(
                          fontSize: 14,
                          color:
                              note.isDone ? Colors.grey[500] : Colors.grey[700],
                          height: 1.4,
                          decoration:
                              note.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            note.timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Checkbox
                Checkbox(
                  value: note.isDone,
                  onChanged: (value) {
                    _toggleNoteStatus(note.id, note.isDone);
                  },
                  activeColor: Colors.green[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesStream(String userId, bool isDone, String emptyMessage) {
    return StreamBuilder(
      stream: _firestoreService.streamNotesByFolder(
        userId,
        _selectedFolderId,
        isDone: isDone,
      ),
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
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Error loading notes: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                emptyMessage,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          );
        }

        // Build note cards
        final notes =
            snapshot.data!.docs
                .map((doc) => NoteModel.fromFirestore(doc))
                .toList();

        return Column(
          children: notes.map((note) => _buildNoteCard(note)).toList(),
        );
      },
    );
  }

  Widget _buildFolderFilterDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedFolderId,
                isExpanded: true,
                hint: Text(
                  _selectedFolderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.home, size: 18),
                        SizedBox(width: 8),
                        Text('All Notes'),
                      ],
                    ),
                  ),
                  ..._folders.map((folder) {
                    return DropdownMenuItem<String?>(
                      value: folder.id,
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  folder.color.replaceFirst('#', '0xFF'),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              folder.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (folder.noteCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${folder.noteCount}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFolderId = newValue;
                    if (newValue == null) {
                      _selectedFolderName = 'All Notes';
                    } else {
                      final folder = _folders.firstWhere(
                        (f) => f.id == newValue,
                      );
                      _selectedFolderName = folder.name;
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderBreadcrumb() {
    if (_selectedFolderId == null) {
      return const SizedBox.shrink();
    }

    final folder = _folders.firstWhere((f) => f.id == _selectedFolderId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(
          int.parse(folder.color.replaceFirst('#', '0xFF')),
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(
            int.parse(folder.color.replaceFirst('#', '0xFF')),
          ).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            color: Color(int.parse(folder.color.replaceFirst('#', '0xFF'))),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Viewing: ${folder.name}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(int.parse(folder.color.replaceFirst('#', '0xFF'))),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFolderId = null;
                _selectedFolderName = 'All Notes';
              });
            },
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/noteassista-logo-transparent.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.note_alt, size: 28);
              },
            ),
            const SizedBox(width: 12),
            const Text('NoteAssista'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderViewScreen(),
                ),
              );
            },
            tooltip: 'Folders',
          ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GraphViewScreen(),
                ),
              );
            },
            tooltip: 'Graph View',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // Folder filter dropdown
          _buildFolderFilterDropdown(),

          // Folder breadcrumb (only show when folder is selected)
          _buildFolderBreadcrumb(),

          const SizedBox(height: 8),

          // Not Done Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSectionHeader(
              'Not Done',
              Icons.radio_button_unchecked,
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildNotesStream(userId, false, 'No active notes yet'),
          ),
          const SizedBox(height: 32),

          // Done Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSectionHeader(
              'Done',
              Icons.check_circle,
              Colors.green[600]!,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildNotesStream(userId, true, 'No completed notes yet'),
          ),
        ],
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isFabVisible ? 1.0 : 0.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Voice capture FAB
              FloatingActionButton(
                heroTag: 'voice_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VoiceCaptureScreen(),
                    ),
                  );
                },
                backgroundColor: Colors.red[400],
                child: const Icon(Icons.mic),
              ),
              const SizedBox(height: 12),
              // Regular add note FAB
              FloatingActionButton(
                heroTag: 'add_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddNoteScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
