import 'package:flutter/material.dart';
import '../services/collaboration_service.dart';

/// Widget that displays cursor indicators for other collaborators
/// Shows colored markers at cursor positions with user names
class CursorIndicator extends StatelessWidget {
  final String noteId;
  final CollaborationService collaborationService;
  final TextEditingController textController;
  final ScrollController? scrollController;

  const CursorIndicator({
    super.key,
    required this.noteId,
    required this.collaborationService,
    required this.textController,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Collaborator>>(
      stream: collaborationService.getActiveCollaborators(noteId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final collaborators =
            snapshot.data!
                .where(
                  (c) =>
                      c.cursorPosition != null &&
                      c.status == PresenceStatus.editing,
                )
                .toList();

        if (collaborators.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          children:
              collaborators.map((collaborator) {
                return _buildCursorMarker(context, collaborator);
              }).toList(),
        );
      },
    );
  }

  Widget _buildCursorMarker(BuildContext context, Collaborator collaborator) {
    // Calculate cursor position in the text field
    // This is a simplified implementation
    // In a real app, you'd need to calculate the exact pixel position

    return Positioned(
      left: 0,
      top: 0,
      child: CustomPaint(
        painter: _CursorPainter(
          color: collaborator.cursorColor,
          displayName: collaborator.displayName,
        ),
      ),
    );
  }
}

/// Custom painter for drawing cursor indicators
class _CursorPainter extends CustomPainter {
  final Color color;
  final String displayName;

  _CursorPainter({required this.color, required this.displayName});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    // Draw cursor line
    canvas.drawLine(const Offset(0, 0), const Offset(0, 20), paint);

    // Draw name label
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw label background
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        2,
        -textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(labelRect, Paint()..color = color);

    // Draw text
    textPainter.paint(canvas, Offset(6, -textPainter.height - 2));
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.displayName != displayName;
  }
}

/// Widget that shows "who is typing" indicator
class TypingIndicator extends StatelessWidget {
  final String noteId;
  final CollaborationService collaborationService;

  const TypingIndicator({
    super.key,
    required this.noteId,
    required this.collaborationService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Collaborator>>(
      stream: collaborationService.getActiveCollaborators(noteId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final typingCollaborators =
            snapshot.data!
                .where((c) => c.status == PresenceStatus.editing)
                .toList();

        if (typingCollaborators.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypingAnimation(),
              const SizedBox(width: 8),
              Text(
                _getTypingText(typingCollaborators),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingAnimation() {
    return SizedBox(
      width: 24,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TypingDot(delay: 0),
          _TypingDot(delay: 200),
          _TypingDot(delay: 400),
        ],
      ),
    );
  }

  String _getTypingText(List<Collaborator> collaborators) {
    if (collaborators.length == 1) {
      return '${collaborators[0].displayName} is typing...';
    } else if (collaborators.length == 2) {
      return '${collaborators[0].displayName} and ${collaborators[1].displayName} are typing...';
    } else {
      return '${collaborators[0].displayName} and ${collaborators.length - 1} others are typing...';
    }
  }
}

/// Animated dot for typing indicator
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
