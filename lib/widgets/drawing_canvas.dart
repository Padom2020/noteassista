import 'package:flutter/material.dart';
import 'dart:ui' as ui;

enum DrawingTool { pen, highlighter, eraser, line, rectangle, circle }

class DrawPoint {
  final Offset point;
  final Paint paint;

  DrawPoint(this.point, this.paint);
}

class DrawingPath {
  final List<DrawPoint> points;
  final DrawingTool tool;

  DrawingPath(this.points, this.tool);
}

class DrawingCanvas extends StatefulWidget {
  final List<DrawingPath> paths;
  final DrawingTool currentTool;
  final Color currentColor;
  final double strokeWidth;
  final bool showGrid;
  final bool showLines;
  final Function(List<DrawingPath>) onPathsChanged;
  final ui.Image? backgroundImage;
  final bool showBackgroundImage;

  const DrawingCanvas({
    super.key,
    required this.paths,
    required this.currentTool,
    required this.currentColor,
    required this.strokeWidth,
    required this.showGrid,
    required this.showLines,
    required this.onPathsChanged,
    this.backgroundImage,
    this.showBackgroundImage = true,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<DrawPoint> _currentPath = [];
  Offset? _shapeStartPoint;

  Paint _createPaint() {
    final paint =
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = widget.strokeWidth;

    if (widget.currentTool == DrawingTool.eraser) {
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.blendMode = BlendMode.clear;
    } else if (widget.currentTool == DrawingTool.highlighter) {
      paint.color = widget.currentColor.withValues(alpha: 0.3);
      paint.style = PaintingStyle.stroke;
    } else {
      paint.color = widget.currentColor;
      paint.style =
          widget.currentTool == DrawingTool.pen
              ? PaintingStyle.stroke
              : PaintingStyle.stroke;
    }

    return paint;
  }

  void _onPanStart(DragStartDetails details) {
    final point = details.localPosition;

    if (_isShapeTool()) {
      _shapeStartPoint = point;
    } else {
      _currentPath = [DrawPoint(point, _createPaint())];
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      final point = details.localPosition;

      if (_isShapeTool()) {
        // For shapes, we just update the end point
        _shapeStartPoint = _shapeStartPoint ?? point;
      } else {
        _currentPath.add(DrawPoint(point, _createPaint()));
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPath.isNotEmpty || _shapeStartPoint != null) {
      final newPaths = List<DrawingPath>.from(widget.paths);
      newPaths.add(DrawingPath(_currentPath, widget.currentTool));
      widget.onPathsChanged(newPaths);
    }

    setState(() {
      _currentPath = [];
      _shapeStartPoint = null;
    });
  }

  bool _isShapeTool() {
    return widget.currentTool == DrawingTool.line ||
        widget.currentTool == DrawingTool.rectangle ||
        widget.currentTool == DrawingTool.circle;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: DrawingPainter(
          paths: widget.paths,
          currentPath: _currentPath,
          currentTool: widget.currentTool,
          shapeStartPoint: _shapeStartPoint,
          currentPaint: _createPaint(),
          showGrid: widget.showGrid,
          showLines: widget.showLines,
          backgroundImage: widget.backgroundImage,
          showBackgroundImage: widget.showBackgroundImage,
        ),
        child: Container(),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<DrawPoint> currentPath;
  final DrawingTool currentTool;
  final Offset? shapeStartPoint;
  final Paint currentPaint;
  final bool showGrid;
  final bool showLines;
  final ui.Image? backgroundImage;
  final bool showBackgroundImage;

  DrawingPainter({
    required this.paths,
    required this.currentPath,
    required this.currentTool,
    required this.shapeStartPoint,
    required this.currentPaint,
    required this.showGrid,
    required this.showLines,
    this.backgroundImage,
    this.showBackgroundImage = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Draw background image if available and enabled
    if (backgroundImage != null && showBackgroundImage) {
      _drawBackgroundImage(canvas, size);
    }

    // Draw grid or lines
    if (showGrid) {
      _drawGrid(canvas, size);
    } else if (showLines) {
      _drawLines(canvas, size);
    }

    // Draw all completed paths
    for (final path in paths) {
      _drawPath(canvas, path);
    }

    // Draw current path being drawn
    if (currentPath.isNotEmpty) {
      _drawCurrentPath(canvas);
    }

    // Draw shape preview
    if (shapeStartPoint != null && currentPath.isNotEmpty) {
      _drawShapePreview(canvas);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.2)
          ..strokeWidth = 1;

    const gridSpacing = 30.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawLines(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 1;

    const lineSpacing = 40.0;

    // Horizontal lines
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawBackgroundImage(Canvas canvas, Size size) {
    if (backgroundImage == null) return;

    // Calculate scaling to fit the image within the canvas while maintaining aspect ratio
    final imageSize = Size(
      backgroundImage!.width.toDouble(),
      backgroundImage!.height.toDouble(),
    );
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate position to center the image
    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;
    final offsetX = (size.width - scaledWidth) / 2;
    final offsetY = (size.height - scaledHeight) / 2;

    // Draw the image with scaling and positioning
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    canvas.drawImage(
      backgroundImage!,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  void _drawPath(Canvas canvas, DrawingPath drawingPath) {
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

  void _drawCurrentPath(Canvas canvas) {
    if (currentPath.isEmpty) return;

    final path = Path();
    path.moveTo(currentPath.first.point.dx, currentPath.first.point.dy);

    for (int i = 1; i < currentPath.length; i++) {
      path.lineTo(currentPath[i].point.dx, currentPath[i].point.dy);
    }

    canvas.drawPath(path, currentPaint);
  }

  void _drawShapePreview(Canvas canvas) {
    if (shapeStartPoint == null || currentPath.isEmpty) return;

    final endPoint = currentPath.last.point;

    if (currentTool == DrawingTool.line) {
      canvas.drawLine(shapeStartPoint!, endPoint, currentPaint);
    } else if (currentTool == DrawingTool.rectangle) {
      final rect = Rect.fromPoints(shapeStartPoint!, endPoint);
      canvas.drawRect(rect, currentPaint);
    } else if (currentTool == DrawingTool.circle) {
      final radius = (endPoint - shapeStartPoint!).distance;
      canvas.drawCircle(shapeStartPoint!, radius, currentPaint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.paths != paths ||
        oldDelegate.currentPath != currentPath ||
        oldDelegate.shapeStartPoint != shapeStartPoint ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLines != showLines ||
        oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.showBackgroundImage != showBackgroundImage;
  }
}
