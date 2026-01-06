import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/migration_service.dart';
import '../services/onboarding_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../widgets/clickable_note_link.dart';
import '../widgets/feature_tooltip.dart';
import 'add_note_screen.dart';
import 'edit_note_screen.dart';
import 'voice_capture_screen.dart';
import 'graph_view_screen.dart';
import 'folder_view_screen.dart';
import 'reminders_screen.dart';
import 'statistics_screen.dart';
import 'daily_note_calendar_screen.dart';
import 'whats_new_screen.dart';
import 'help_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final OnboardingService _onboardingService = OnboardingService();
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;
  double _lastScrollPosition = 0.0;

  // Folder filtering state
  String? _selectedFolderId;
  List<FolderModel> _folders = [];

  // Keys for feature tooltips
  final GlobalKey _voiceFabKey = GlobalKey();
  final GlobalKey _foldersKey = GlobalKey();

  // Cached streams to prevent recreating them on every rebuild
  late Stream<List<NoteModel>> _notDoneStream;
  late Stream<List<NoteModel>> _doneStream;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFolders();
    _initializeStreams();
    _checkAndRunMigration();
    _checkForWhatsNew();
    _checkForFirstLaunch();
  }

  /// Initialize cached streams
  void _initializeStreams() {
    _notDoneStream = _supabaseService.streamNotesByFolder(
      _selectedFolderId,
      isDone: false,
    );
    _doneStream = _supabaseService.streamNotesByFolder(
      _selectedFolderId,
      isDone: true,
    );
  }

  /// Check if this is the first launch and show feature tour
  Future<void> _checkForFirstLaunch() async {
    final isOnboardingCompleted =
        await _onboardingService.isOnboardingCompleted();

    if (!isOnboardingCompleted && mounted) {
      // Delay to ensure home screen is fully loaded
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        await _showFeatureTour();
        await _onboardingService.completeOnboarding();
      }
    }
  }

  /// Show a feature tour dialog
  Future<void> _showFeatureTour() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.celebration, color: Colors.amber),
                SizedBox(width: 12),
                Text('Welcome to NoteAssista!'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Let\'s take a quick tour of the powerful features available to you:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureTourItem(
                    Icons.mic,
                    'Voice Capture',
                    'Tap the red microphone button to create notes by speaking',
                    Colors.red,
                  ),
                  _buildFeatureTourItem(
                    Icons.link,
                    'Linked Notes',
                    'Type [[ in any note to link to other notes and build your knowledge network',
                    Colors.purple,
                  ),
                  _buildFeatureTourItem(
                    Icons.account_tree,
                    'Graph View',
                    'Visualize connections between your notes in an interactive graph',
                    Colors.blue,
                  ),
                  _buildFeatureTourItem(
                    Icons.folder,
                    'Folders',
                    'Organize notes into folders and sub-folders for better structure',
                    Colors.teal,
                  ),
                  _buildFeatureTourItem(
                    Icons.people,
                    'Collaboration',
                    'Share notes and edit together with your team in real-time',
                    Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Look for tooltips and help icons throughout the app to learn more!',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Got it!'),
              ),
            ],
          ),
    );
  }

  Widget _buildFeatureTourItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Check if this is a new version and show What's New screen
  Future<void> _checkForWhatsNew() async {
    const currentVersion = '1.0.0'; // This should come from package_info
    final isNewVersion = await _onboardingService.isNewVersion(currentVersion);

    if (isNewVersion && mounted) {
      // Delay to ensure home screen is fully loaded
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WhatsNewScreen(version: currentVersion),
          ),
        );
      }
    }
  }

  /// Check if migration is needed and run it
  Future<void> _checkAndRunMigration() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final migrationService = MigrationService();

      // Check if migration is needed
      final needsMigration = await migrationService.needsMigration(userId);

      if (needsMigration) {
        debugPrint('Migration needed for user: $userId');

        // Run migration in the background
        final result = await migrationService.runMigrations(userId);

        if (result.isSuccess) {
          debugPrint('Migration completed successfully');
          debugPrint('Notes updated: ${result.notesUpdated}');
          debugPrint('Folders created: ${result.foldersCreated}');
          debugPrint('Templates created: ${result.templatesCreated}');

          // Show success message if any changes were made
          if (result.notesUpdated > 0 ||
              result.foldersCreated > 0 ||
              result.templatesCreated > 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'App updated! ${result.notesUpdated} notes migrated, '
                    '${result.foldersCreated} folders created, '
                    '${result.templatesCreated} templates added.',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } else {
          debugPrint('Migration completed with errors: ${result.errors}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Some data migration issues occurred. Please contact support if you experience problems.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        debugPrint('No migration needed for user: $userId');
      }
    } catch (e) {
      debugPrint('Error during migration check: $e');
      // Don't show error to user - migration failures shouldn't block app usage
    }
  }

  Future<void> _loadFolders() async {
    if (_supabaseService.isAuthenticated) {
      try {
        final result = await _supabaseService.getFolders();
        if (result.success && mounted) {
          setState(() {
            _folders = result.data ?? [];
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
    try {
      debugPrint('Deleting note: $noteId');
      final result = await _supabaseService.deleteNote(noteId);
      debugPrint(
        'Delete result: success=${result.success}, error=${result.error}',
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Force refresh by triggering a rebuild
          // The stream will automatically update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Error deleting note'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Exception deleting note: $e');
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
    try {
      final result = await _supabaseService.toggleNoteStatus(
        noteId,
        !currentStatus,
      );
      if (mounted && !result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Error updating note'),
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

  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Logout'),
                ),
              ],
            ),
      );

      if (confirmed == true && mounted) {
        // Sign out
        await _authService.signOut();

        // Navigate to splash screen and clear the navigation stack
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SplashScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Widget _buildNoteImage(NoteModel note, String assetPath) {
    try {
      // Safely check if custom image exists
      if (note.customImageUrl != null && note.customImageUrl!.isNotEmpty) {
        try {
          if (File(note.customImageUrl!).existsSync()) {
            return Image.file(
              File(note.customImageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.image, color: Colors.grey[400], size: 30);
              },
            );
          }
        } catch (e) {
          debugPrint('Error loading custom image: $e');
        }
      }

      // Fall back to asset image
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.image, color: Colors.grey[400], size: 30);
        },
      );
    } catch (e) {
      debugPrint('Error building note image: $e');
      return Icon(Icons.image, color: Colors.grey[400], size: 30);
    }
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
                      child: _buildNoteImage(note, imagePath),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note.timestamp,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Reminder indicator
                          if (note.reminder != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.notifications_active,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                          ],
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

  Widget _buildNotesStream(
    String sectionLabel,
    bool isDone,
    String emptyMessage,
  ) {
    final stream = isDone ? _doneStream : _notDoneStream;
    return RepaintBoundary(
      child: StreamBuilder<List<NoteModel>>(
        stream: stream,
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
          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
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
          final notes = snapshot.data ?? [];

          return Column(
            children:
                notes
                    .map(
                      (note) => KeyedSubtree(
                        key: ValueKey(note.id),
                        child: _buildNoteCard(note),
                      ),
                    )
                    .toList(),
          );
        },
      ),
    );
  }

  Widget _buildSharedNotesStream(String emptyMessage) {
    return RepaintBoundary(
      child: StreamBuilder<List<NoteModel>>(
        stream: _supabaseService.streamSharedNotes(),
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
                  'Error loading shared notes: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
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
          final notes = snapshot.data ?? [];

          return Column(
            children:
                notes
                    .map(
                      (note) => KeyedSubtree(
                        key: ValueKey('shared_${note.id}'),
                        child: _buildNoteCard(note),
                      ),
                    )
                    .toList(),
          );
        },
      ),
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
                selectedItemBuilder: (BuildContext context) {
                  return [
                    // For "All Notes" (null value)
                    Row(
                      children: [
                        const Icon(Icons.home, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All Notes',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // For folder items
                    ..._folders.map(
                      (folder) => Row(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.home, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All Notes',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
          Expanded(
            child: Text(
              'Viewing: ${folder.name}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(int.parse(folder.color.replaceFirst('#', '0xFF'))),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFolderId = null;
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
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/noteassista-white-preview.png',
            height: 36,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Logo loading error: $error');
              return const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt, size: 24),
                  SizedBox(width: 8),
                  Text('NoteAssista'),
                ],
              );
            },
          ),
        ),
        actions: [
          FeatureTooltip(
            tooltipId: 'folders_feature',
            message: 'Organize notes into folders and sub-folders',
            direction: TooltipDirection.bottom,
            child: IconButton(
              key: _foldersKey,
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
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RemindersScreen(),
                ),
              );
            },
            tooltip: 'Reminders',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'daily_notes') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyNoteCalendarScreen(),
                  ),
                );
              } else if (value == 'graph_view') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GraphViewScreen(),
                  ),
                );
              } else if (value == 'statistics') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              } else if (value == 'whats_new') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const WhatsNewScreen(version: '1.0.0'),
                  ),
                );
              } else if (value == 'help') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'daily_notes',
                    child: Row(
                      children: [
                        Icon(Icons.today, size: 20),
                        SizedBox(width: 12),
                        Text('Daily Notes'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'graph_view',
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree, size: 20),
                        const SizedBox(width: 12),
                        const Text('Graph View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'statistics',
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, size: 20),
                        SizedBox(width: 12),
                        Text('Statistics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'whats_new',
                    child: Row(
                      children: [
                        Icon(Icons.new_releases, size: 20),
                        SizedBox(width: 12),
                        Text('What\'s New'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 20),
                        SizedBox(width: 12),
                        Text('Help & Documentation'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 12),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Folder filter dropdown
          SliverToBoxAdapter(child: _buildFolderFilterDropdown()),

          // Folder breadcrumb (only show when folder is selected)
          SliverToBoxAdapter(child: _buildFolderBreadcrumb()),

          SliverToBoxAdapter(child: const SizedBox(height: 8)),

          // Shared Notes Section (only show when viewing all notes)
          if (_selectedFolderId == null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader(
                  'Shared With Me',
                  Icons.people,
                  Colors.purple[600]!,
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSharedNotesStream('No shared notes yet'),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 32)),
          ],

          // Not Done Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionHeader(
                'Not Done',
                Icons.radio_button_unchecked,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildNotesStream('', false, 'No active notes yet'),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 32)),

          // Done Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionHeader(
                'Done',
                Icons.check_circle,
                Colors.green[600]!,
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildNotesStream('', true, 'No completed notes yet'),
            ),
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
              // Voice capture FAB with tooltip
              FeatureTooltip(
                tooltipId: 'voice_capture_feature',
                message: 'Tap to create notes by speaking',
                direction: TooltipDirection.left,
                child: FloatingActionButton(
                  key: _voiceFabKey,
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
