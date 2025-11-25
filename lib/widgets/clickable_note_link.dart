import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/link_management_service.dart';
import '../services/auth_service.dart';
import '../screens/edit_note_screen.dart';

/// Widget that renders note description with clickable wiki-style links.
///
/// This widget parses the content for wiki-style link syntax and renders them
/// as clickable links that navigate to the referenced notes.
///
/// Supported syntax:
/// - [[Note Title]] - Simple link that displays the note title
/// - [[Note Title|Display Text]] - Link with custom display text (alias)
///
/// Features:
/// - Clickable links that navigate to the referenced note
/// - Broken links (non-existent notes) are highlighted in red
/// - Valid links are highlighted in blue
/// - Tapping a broken link offers to create the note
/// - Automatically checks link existence on mount and content changes
///
/// Example:
/// ```dart
/// ClickableNoteLink(
///   content: 'See [[Project Plan]] for details.',
///   defaultStyle: TextStyle(fontSize: 14),
///   maxLines: 2,
///   overflow: TextOverflow.ellipsis,
/// )
/// ```
class ClickableNoteLink extends StatefulWidget {
  final String content;
  final TextStyle? defaultStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClickableNoteLink({
    super.key,
    required this.content,
    this.defaultStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  State<ClickableNoteLink> createState() => _ClickableNoteLinkState();
}

class _ClickableNoteLinkState extends State<ClickableNoteLink> {
  final LinkManagementService _linkService = LinkManagementService();
  final AuthService _authService = AuthService();
  Map<String, bool> _linkExistence = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLinkExistence();
  }

  @override
  void didUpdateWidget(ClickableNoteLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _checkLinkExistence();
    }
  }

  /// Check which linked notes exist in the database
  Future<void> _checkLinkExistence() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final links = _linkService.parseLinks(widget.content);
    final titles = links.map((link) => link.targetTitle).toSet().toList();

    if (titles.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final existence = await _linkService.checkNotesExist(userId, titles);
      if (mounted) {
        setState(() {
          _linkExistence = existence;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking link existence: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to the linked note
  Future<void> _navigateToNote(String noteTitle) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening note...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Get the note by title
      final note = await _linkService.getNoteByTitle(userId, noteTitle);

      if (!mounted) return;

      if (note != null) {
        // Navigate to edit note screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
        );
      } else {
        // Note doesn't exist, offer to create it
        _showCreateNoteDialog(noteTitle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show dialog to create a new note from a broken link
  void _showCreateNoteDialog(String noteTitle) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Note Not Found'),
            content: Text(
              'The note "$noteTitle" doesn\'t exist. Would you like to create it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _createAndNavigateToNote(noteTitle);
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  /// Create a new note and navigate to it
  Future<void> _createAndNavigateToNote(String noteTitle) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating note...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Create the note
      await _linkService.createNoteFromLink(userId, noteTitle);

      // Get the created note
      final note = await _linkService.getNoteByTitle(userId, noteTitle);

      if (!mounted) return;

      if (note != null) {
        // Navigate to edit note screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
        );

        // Update link existence
        setState(() {
          _linkExistence[noteTitle] = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build the text with clickable links
  TextSpan _buildTextSpan() {
    final links = _linkService.parseLinks(widget.content);

    if (links.isEmpty) {
      // No links, return plain text
      return TextSpan(text: widget.content, style: widget.defaultStyle);
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final link in links) {
      // Add text before the link
      if (link.startIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: widget.content.substring(currentIndex, link.startIndex),
            style: widget.defaultStyle,
          ),
        );
      }

      // Determine if link is broken (note doesn't exist)
      final exists = _linkExistence[link.targetTitle] ?? true;
      final linkColor = exists ? Colors.blue : Colors.red;

      // Add the clickable link
      spans.add(
        TextSpan(
          text: link.displayText,
          style:
              widget.defaultStyle?.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ) ??
              TextStyle(
                color: linkColor,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () => _navigateToNote(link.targetTitle),
        ),
      );

      currentIndex = link.endIndex;
    }

    // Add remaining text after the last link
    if (currentIndex < widget.content.length) {
      spans.add(
        TextSpan(
          text: widget.content.substring(currentIndex),
          style: widget.defaultStyle,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show plain text while loading
      return Text(
        widget.content,
        style: widget.defaultStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return RichText(
      text: _buildTextSpan(),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
