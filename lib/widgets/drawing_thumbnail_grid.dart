import 'package:flutter/material.dart';
import '../screens/drawing_screen.dart';
import '../screens/full_screen_image_viewer.dart';

/// Widget that displays a grid of drawing thumbnails
class DrawingThumbnailGrid extends StatelessWidget {
  final List<String> drawingUrls;
  final String userId;
  final String noteId;
  final Function(String)? onDrawingAdded;
  final Function(int)? onDrawingRemoved;

  const DrawingThumbnailGrid({
    super.key,
    required this.drawingUrls,
    required this.userId,
    required this.noteId,
    this.onDrawingAdded,
    this.onDrawingRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Drawings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (drawingUrls.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${drawingUrls.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openDrawingScreen(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Drawing'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        if (drawingUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: drawingUrls.length,
            itemBuilder: (context, index) {
              return _DrawingThumbnail(
                drawingUrl: drawingUrls[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FullScreenImageViewer(
                            imageUrls: drawingUrls,
                            initialIndex: index,
                            isLocalPath: false,
                          ),
                    ),
                  );
                },
                onEdit: () => _openDrawingScreen(context, drawingUrls[index]),
                onDelete:
                    onDrawingRemoved != null
                        ? () => _confirmDelete(context, index)
                        : null,
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _openDrawingScreen(
    BuildContext context,
    String? existingDrawingUrl,
  ) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder:
            (context) => DrawingScreen(
              userId: userId,
              noteId: noteId,
              existingDrawingUrl: existingDrawingUrl,
            ),
      ),
    );

    if (result != null && onDrawingAdded != null) {
      // Handle different return types from DrawingScreen
      if (result is String) {
        // Simple drawing URL
        onDrawingAdded!(result);
      } else if (result is Map<String, dynamic>) {
        final type = result['type'] as String?;

        if (type == 'text') {
          // User chose to replace drawing with text
          // In this context, we can't easily add text, so show a message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Text recognized. Please add it manually to the note description.',
                ),
              ),
            );
          }
        } else if (type == 'both') {
          // User chose to keep both drawing and text
          final drawingUrl = result['drawingUrl'] as String;
          onDrawingAdded!(drawingUrl);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Drawing saved. Text recognized - add it manually to the note description.',
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Drawing'),
            content: const Text(
              'Are you sure you want to delete this drawing?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDrawingRemoved?.call(index);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

class _DrawingThumbnail extends StatelessWidget {
  final String drawingUrl;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DrawingThumbnail({
    required this.drawingUrl,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                drawingUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder();
                },
              ),
              // Overlay to indicate it's tappable
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              // Drawing icon indicator
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.brush, size: 16, color: Colors.blue),
                ),
              ),
              // Action buttons
              if (onEdit != null || onDelete != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (onEdit != null && onDelete != null)
                        const SizedBox(width: 4),
                      if (onDelete != null)
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
      ),
    );
  }
}
