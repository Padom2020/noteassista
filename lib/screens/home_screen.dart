import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note_model.dart';
import '../widgets/clickable_note_link.dart';
import 'add_note_screen.dart';
import 'edit_note_screen.dart';
import 'voice_capture_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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
      stream: _firestoreService.streamNotes(userId, isDone),
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          // Not Done Section
          _buildSectionHeader(
            'Not Done',
            Icons.radio_button_unchecked,
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _buildNotesStream(userId, false, 'No active notes yet'),
          const SizedBox(height: 32),

          // Done Section
          _buildSectionHeader('Done', Icons.check_circle, Colors.green[600]!),
          const SizedBox(height: 16),
          _buildNotesStream(userId, true, 'No completed notes yet'),
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
