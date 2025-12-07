import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/link_management_service.dart';
import '../screens/edit_note_screen.dart';

/// Widget that displays backlinks (notes that link to the current note)
/// at the bottom of a note view
class BacklinksSection extends StatefulWidget {
  final String userId;
  final String noteTitle;
  final LinkManagementService linkService;

  const BacklinksSection({
    super.key,
    required this.userId,
    required this.noteTitle,
    required this.linkService,
  });

  @override
  State<BacklinksSection> createState() => _BacklinksSectionState();
}

class _BacklinksSectionState extends State<BacklinksSection> {
  List<NoteModel>? _backlinks;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBacklinks();
  }

  @override
  void didUpdateWidget(BacklinksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload backlinks if the note title changes
    if (oldWidget.noteTitle != widget.noteTitle) {
      _loadBacklinks();
    }
  }

  Future<void> _loadBacklinks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final backlinks = await widget.linkService.getBacklinks(
        widget.userId,
        widget.noteTitle,
      );

      if (mounted) {
        setState(() {
          _backlinks = backlinks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToNote(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
    ).then((_) {
      // Reload backlinks when returning from edit screen
      // in case links were modified
      _loadBacklinks();
    });
  }

  String _getPreviewText(String description, int maxLength) {
    if (description.length <= maxLength) {
      return description;
    }
    return '${description.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    // Don't show section if loading initially
    if (_isLoading && _backlinks == null) {
      return const SizedBox.shrink();
    }

    // Don't show section if there are no backlinks
    if (_backlinks != null && _backlinks!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(
              Icons.link,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Linked References',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (_backlinks != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_backlinks!.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[700], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        if (_backlinks != null && _backlinks!.isNotEmpty)
          ..._backlinks!.map((note) => _buildBacklinkCard(note)),
      ],
    );
  }

  Widget _buildBacklinkCard(NoteModel note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: InkWell(
        onTap: () => _navigateToNote(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        'assets/images/${note.categoryImageIndex}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.note,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Note title
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Navigation arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              if (note.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getPreviewText(note.description, 100),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Tags if present
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
