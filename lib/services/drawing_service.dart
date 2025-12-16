import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../widgets/drawing_canvas.dart';

/// Service for handling drawing creation, editing, and URL loading functionality
class DrawingService {
  static final DrawingService _instance = DrawingService._internal();
  factory DrawingService() => _instance;
  DrawingService._internal();

  final Map<String, ui.Image> _imageCache = {};

  /// Load existing drawing from Firebase Storage URL or local file
  Future<DrawingLoadResult> loadDrawingFromUrl(String drawingUrl) async {
    try {
      // Check cache first
      if (_imageCache.containsKey(drawingUrl)) {
        final cachedImage = _imageCache[drawingUrl]!;
        return DrawingLoadResult(
          image: cachedImage,
          success: true,
          originalSize: Size(
            cachedImage.width.toDouble(),
            cachedImage.height.toDouble(),
          ),
        );
      }

      // Validate URL format
      if (!await validateDrawingUrl(drawingUrl)) {
        return DrawingLoadResult(
          success: false,
          errorMessage: 'Invalid drawing URL format',
          originalSize: Size.zero,
        );
      }

      Uint8List bytes;

      // Handle local file URLs
      if (drawingUrl.startsWith('file://')) {
        final filePath = drawingUrl.substring(7); // Remove 'file://' prefix
        final file = File(filePath);

        if (!await file.exists()) {
          return DrawingLoadResult(
            success: false,
            errorMessage: 'Local drawing file not found',
            originalSize: Size.zero,
          );
        }

        bytes = await file.readAsBytes();
      } else {
        // Download image from Firebase Storage
        final response = await http.get(Uri.parse(drawingUrl));
        if (response.statusCode != 200) {
          return DrawingLoadResult(
            success: false,
            errorMessage:
                'Failed to download image: HTTP ${response.statusCode}',
            originalSize: Size.zero,
          );
        }
        bytes = response.bodyBytes;
      }

      // Convert bytes to ui.Image
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Cache the image
      await cacheDrawingImage(drawingUrl, image);

      return DrawingLoadResult(
        image: image,
        success: true,
        originalSize: Size(image.width.toDouble(), image.height.toDouble()),
      );
    } catch (e) {
      debugPrint('Error loading drawing from URL: $e');
      return DrawingLoadResult(
        success: false,
        errorMessage: 'Failed to load drawing: $e',
        originalSize: Size.zero,
      );
    }
  }

  /// Cache drawing image locally for performance
  Future<void> cacheDrawingImage(String drawingUrl, ui.Image image) async {
    try {
      _imageCache[drawingUrl] = image;

      // Also cache to disk for persistence across app restarts
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/drawing_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Create a filename from the URL hash
      final filename = drawingUrl.hashCode.abs().toString();
      final file = File('${cacheDir.path}/$filename.png');

      // Convert ui.Image to bytes and save
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        await file.writeAsBytes(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Error caching drawing image: $e');
    }
  }

  /// Get cached drawing image if available
  Future<ui.Image?> getCachedDrawingImage(String drawingUrl) async {
    try {
      // Check memory cache first
      if (_imageCache.containsKey(drawingUrl)) {
        return _imageCache[drawingUrl];
      }

      // Check disk cache
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/drawing_cache');
      final filename = drawingUrl.hashCode.abs().toString();
      final file = File('${cacheDir.path}/$filename.png');

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        // Store in memory cache
        _imageCache[drawingUrl] = image;
        return image;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting cached drawing image: $e');
      return null;
    }
  }

  /// Composite background image with new drawing paths
  Future<ui.Image> compositeDrawingLayers(
    ui.Image? backgroundImage,
    List<DrawingPath> paths,
    Size canvasSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background image if provided
    if (backgroundImage != null) {
      final scaledImage = scaleImageToCanvas(backgroundImage, canvasSize);
      canvas.drawImage(scaledImage, Offset.zero, Paint());
    } else {
      // Draw white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.white,
      );
    }

    // Draw all paths on top
    for (final path in paths) {
      _drawPathOnCanvas(canvas, path);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
  }

  /// Scale image to fit canvas while maintaining aspect ratio
  ui.Image scaleImageToCanvas(ui.Image image, Size canvasSize) {
    // For now, return the original image
    // In a full implementation, we would create a scaled version
    // This is a simplified version that assumes the image fits
    return image;
  }

  /// Validate drawing URL format and accessibility
  Future<bool> validateDrawingUrl(String url) async {
    try {
      // Check if it's a valid URL
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Handle local file URLs
      if (uri.scheme == 'file') {
        final file = File(uri.path);
        return await file.exists();
      }

      // Check if it's HTTPS protocol for remote URLs
      if (uri.scheme != 'https') {
        return false;
      }

      // Check if it's a Firebase Storage URL
      if (!url.contains('firebasestorage.googleapis.com')) {
        return false;
      }

      // Check if it's an image file
      final lowercaseUrl = url.toLowerCase();
      if (!lowercaseUrl.contains('.png') &&
          !lowercaseUrl.contains('.jpg') &&
          !lowercaseUrl.contains('.jpeg')) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error validating drawing URL: $e');
      return false;
    }
  }

  /// Helper method to draw a path on canvas
  void _drawPathOnCanvas(Canvas canvas, DrawingPath drawingPath) {
    if (drawingPath.points.isEmpty) return;

    if (drawingPath.tool == DrawingTool.line) {
      if (drawingPath.points.length >= 2) {
        canvas.drawLine(
          drawingPath.points.first.point,
          drawingPath.points.last.point,
          drawingPath.points.first.paint,
        );
      }
    } else if (drawingPath.tool == DrawingTool.rectangle) {
      if (drawingPath.points.length >= 2) {
        final rect = Rect.fromPoints(
          drawingPath.points.first.point,
          drawingPath.points.last.point,
        );
        canvas.drawRect(rect, drawingPath.points.first.paint);
      }
    } else if (drawingPath.tool == DrawingTool.circle) {
      if (drawingPath.points.length >= 2) {
        final center = drawingPath.points.first.point;
        final edge = drawingPath.points.last.point;
        final radius = (edge - center).distance;
        canvas.drawCircle(center, radius, drawingPath.points.first.paint);
      }
    } else {
      // Draw freehand path (pen, highlighter, eraser)
      final path = Path();
      path.moveTo(
        drawingPath.points.first.point.dx,
        drawingPath.points.first.point.dy,
      );

      for (int i = 1; i < drawingPath.points.length; i++) {
        path.lineTo(
          drawingPath.points[i].point.dx,
          drawingPath.points[i].point.dy,
        );
      }

      canvas.drawPath(path, drawingPath.points.first.paint);
    }
  }

  /// Clear the image cache
  void clearCache() {
    _imageCache.clear();
  }

  /// Get cache size for debugging
  int getCacheSize() {
    return _imageCache.length;
  }
}

/// Result class for drawing loading operations
class DrawingLoadResult {
  final ui.Image? image;
  final bool success;
  final String? errorMessage;
  final Size originalSize;

  DrawingLoadResult({
    this.image,
    required this.success,
    this.errorMessage,
    required this.originalSize,
  });
}
