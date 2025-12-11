import 'dart:io';
import 'package:flutter/material.dart';
import '../screens/full_screen_image_viewer.dart';

/// Widget that displays a grid of image thumbnails
class ImageThumbnailGrid extends StatelessWidget {
  final List<String> imageUrls;
  final bool isLocalPath;
  final VoidCallback? onRemove;

  const ImageThumbnailGrid({
    super.key,
    required this.imageUrls,
    this.isLocalPath = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Images',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${imageUrls.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
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
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return _ImageThumbnail(
              imageUrl: imageUrls[index],
              isLocalPath: isLocalPath,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FullScreenImageViewer(
                          imageUrls: imageUrls,
                          initialIndex: index,
                          isLocalPath: isLocalPath,
                        ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imageUrl;
  final bool isLocalPath;
  final VoidCallback onTap;

  const _ImageThumbnail({
    required this.imageUrl,
    required this.isLocalPath,
    required this.onTap,
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
              isLocalPath
                  ? Image.file(
                    File(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorPlaceholder();
                    },
                  )
                  : Image.network(
                    imageUrl,
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
