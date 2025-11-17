import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note_model.dart';
import 'add_note_screen.dart';

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
          const SnackBar(content: Text('Note deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
      }
    }
  }

  Future<void> _toggleNoteStatus(String noteId, bool currentStatus) async {
    final userId = _authService.currentUser?.uid ?? '';
    try {
      await _firestoreService.toggleNoteStatus(userId, noteId, !currentStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating note: $e')));
      }
    }
  }

  void _navigateToEditNote(NoteModel note) {
    // Navigation to EditNoteScreen will be implemented when EditNoteScreen is created
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit screen not yet implemented')),
    );
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => EditNoteScreen(note: note),
    //   ),
    // );
  }

  Widget _buildNoteCard(NoteModel note) {
    // Get category image asset path
    final categoryImages = [
      'assets/images/category_1.png',
      'assets/images/category_2.png',
      'assets/images/category_3.png',
      'assets/images/category_4.png',
    ];

    final imagePath = categoryImages[note.categoryImageIndex % 4];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.image, color: Colors.grey[400]);
              },
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              color: Colors.red[400],
              onPressed: () => _deleteNote(note.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              note.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              note.timestamp,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Checkbox(
          value: note.isDone,
          onChanged: (value) {
            _toggleNoteStatus(note.id, note.isDone);
          },
        ),
        onTap: () {
          _navigateToEditNote(note);
        },
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
        title: const Text('NoteAssista'),
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
          const Text(
            'Not Done',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildNotesStream(userId, false, 'No active notes yet'),
          const SizedBox(height: 32),

          // Done Section
          const Text(
            'Done',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
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
          child: FloatingActionButton(
            onPressed: () {
              // Navigate to AddNoteScreen
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => const AddNoteScreen()),
              // );
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
