import 'package:flutter/material.dart';
import '../services/collaboration_service.dart';

/// A text field that shows collaborative editing highlights
/// Displays colored backgrounds for text being edited by other users
class CollaborativeTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String noteId;
  final String userId;
  final CollaborationService collaborationService;
  final String? labelText;
  final String? hintText;
  final int? maxLines;
  final FormFieldValidator<String>? validator;

  const CollaborativeTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.noteId,
    required this.userId,
    required this.collaborationService,
    this.labelText,
    this.hintText,
    this.maxLines,
    this.validator,
  });

  @override
  State<CollaborativeTextField> createState() => _CollaborativeTextFieldState();
}

class _CollaborativeTextFieldState extends State<CollaborativeTextField> {
  @override
  void initState() {
    super.initState();

    // Listen for cursor position changes
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // Update presence to editing
      _updatePresence(PresenceStatus.editing);
    } else {
      // Update presence to viewing
      _updatePresence(PresenceStatus.viewing);
    }
  }

  void _onTextChange() {
    // Broadcast cursor position
    final cursorPosition = widget.controller.selection.baseOffset;
    if (cursorPosition >= 0) {
      widget.collaborationService.broadcastCursorPosition(
        widget.noteId,
        widget.userId,
        cursorPosition,
      );
    }
  }

  Future<void> _updatePresence(PresenceStatus status) async {
    try {
      // Get user info (in a real app, this would come from auth service)
      await widget.collaborationService.updatePresence(
        widget.noteId,
        widget.userId,
        'user@example.com', // This should come from auth service
        'User', // This should come from auth service
        status,
      );
    } catch (e) {
      // Silently fail - presence is not critical
      debugPrint('Error updating presence: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Collaborator>>(
      stream: widget.collaborationService.getActiveCollaborators(widget.noteId),
      builder: (context, snapshot) {
        final collaborators = snapshot.data ?? [];
        final editingCollaborators =
            collaborators
                .where(
                  (c) =>
                      c.userId != widget.userId &&
                      c.status == PresenceStatus.editing &&
                      c.cursorPosition != null,
                )
                .toList();

        return Stack(
          children: [
            // Main text field
            TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                alignLabelWithHint:
                    widget.maxLines != null && widget.maxLines! > 1,
                // Add subtle border color if others are editing
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        editingCollaborators.isNotEmpty
                            ? Colors.blue.withValues(alpha: 0.5)
                            : Colors.grey,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        editingCollaborators.isNotEmpty
                            ? Colors.blue.withValues(alpha: 0.3)
                            : Colors.grey,
                  ),
                ),
              ),
              validator: widget.validator,
            ),

            // Overlay for editing highlights
            if (editingCollaborators.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _EditingHighlightPainter(
                      collaborators: editingCollaborators,
                      textController: widget.controller,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter for highlighting text being edited by collaborators
class _EditingHighlightPainter extends CustomPainter {
  final List<Collaborator> collaborators;
  final TextEditingController textController;

  _EditingHighlightPainter({
    required this.collaborators,
    required this.textController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // This is a simplified implementation
    // In a real app, you would need to calculate exact text positions
    // based on the TextPainter and cursor positions

    for (final collaborator in collaborators) {
      if (collaborator.cursorPosition == null) continue;

      final position = collaborator.cursorPosition!;
      final text = textController.text;

      if (position < 0 || position > text.length) continue;

      // Draw a simple highlight around the cursor position
      // This is a placeholder - real implementation would need proper text layout
      final paint =
          Paint()
            ..color = collaborator.cursorColor.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill;

      // Draw a small rectangle as a placeholder
      final rect = Rect.fromLTWH(
        10,
        20 + (position / 50) * 20, // Simplified position calculation
        100,
        20,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_EditingHighlightPainter oldDelegate) {
    return oldDelegate.collaborators != collaborators ||
        oldDelegate.textController.text != textController.text;
  }
}
