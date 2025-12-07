import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/drawing_canvas.dart';
import '../services/ocr_service.dart';

class DrawingScreen extends StatefulWidget {
  final String userId;
  final String noteId;
  final String? existingDrawingUrl;

  const DrawingScreen({
    super.key,
    required this.userId,
    required this.noteId,
    this.existingDrawingUrl,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final OCRService _ocrService = OCRService();
  List<DrawingPath> _paths = [];
  List<DrawingPath> _undoStack = [];

  DrawingTool _currentTool = DrawingTool.pen;
  Color _currentColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _showGrid = false;
  bool _showLines = false;
  bool _isSaving = false;
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDrawingUrl != null) {
      _loadExistingDrawing();
    }
  }

  Future<void> _loadExistingDrawing() async {
    // TODO: Implement loading existing drawing from URL
    // This would require downloading the image and converting it back to paths
    // For now, we'll just show the image as a background
  }

  void _onPathsChanged(List<DrawingPath> newPaths) {
    setState(() {
      _paths = newPaths;
      _undoStack.clear(); // Clear redo stack when new action is performed
    });
  }

  void _undo() {
    if (_paths.isEmpty) return;

    setState(() {
      _undoStack.add(_paths.last);
      _paths = _paths.sublist(0, _paths.length - 1);
    });
  }

  void _redo() {
    if (_undoStack.isEmpty) return;

    setState(() {
      _paths.add(_undoStack.last);
      _undoStack = _undoStack.sublist(0, _undoStack.length - 1);
    });
  }

  void _clear() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Drawing'),
            content: const Text(
              'Are you sure you want to clear the entire drawing?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _undoStack.addAll(_paths);
                    _paths.clear();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pick a color'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  setState(() {
                    _currentColor = color;
                  });
                },
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  Future<String?> _captureAndSaveDrawing() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Capture the drawing as an image
      final RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(widget.userId)
          .child('drawings')
          .child(
            '${widget.noteId}_${DateTime.now().millisecondsSinceEpoch}.png',
          );

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Clean up temp file
      await file.delete();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error saving drawing: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save drawing: $e')));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveAndReturn() async {
    if (_paths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to save')));
      return;
    }

    final url = await _captureAndSaveDrawing();
    if (url != null && mounted) {
      Navigator.pop(context, url);
    }
  }

  /// Recognize handwriting in the drawing and offer to convert to text
  Future<void> _recognizeHandwriting() async {
    if (_paths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to recognize')));
      return;
    }

    setState(() {
      _isRecognizing = true;
    });

    try {
      // First, capture the drawing as an image
      final RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      // Extract handwritten text using OCR
      final result = await _ocrService.extractHandwrittenText(file.path);

      // Clean up temp file
      await file.delete();

      if (!mounted) return;

      setState(() {
        _isRecognizing = false;
      });

      // Show result dialog with options
      if (result.extractedText.trim().isEmpty) {
        _showNoTextFoundDialog();
      } else {
        _showHandwritingResultDialog(result);
      }
    } catch (e) {
      debugPrint('Error recognizing handwriting: $e');
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to recognize handwriting: $e')),
        );
      }
    }
  }

  void _showNoTextFoundDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No Text Found'),
            content: const Text(
              'Could not detect any handwritten text in the drawing. '
              'Make sure the handwriting is clear and legible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showHandwritingResultDialog(OCRResult result) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Handwriting Recognized'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Recognized Text:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      result.extractedText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Drawing'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, {
                    'type': 'text',
                    'content': result.extractedText,
                  }); // Return text
                },
                child: const Text('Replace with Text'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog
                  // Save drawing and also return text
                  final url = await _captureAndSaveDrawing();
                  if (url != null && mounted) {
                    Navigator.pop(context, {
                      'type': 'both',
                      'drawingUrl': url,
                      'text': result.extractedText,
                    });
                  }
                },
                child: const Text('Keep Both'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _paths.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _undoStack.isEmpty ? null : _redo,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _paths.isEmpty ? null : _clear,
            tooltip: 'Clear',
          ),
          if (_isRecognizing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _paths.isEmpty ? null : _recognizeHandwriting,
              tooltip: 'Recognize Handwriting',
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveAndReturn,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Column(
        children: [
          // Drawing tools toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolButton(
                    icon: Icons.edit,
                    label: 'Pen',
                    tool: DrawingTool.pen,
                  ),
                  _buildToolButton(
                    icon: Icons.highlight,
                    label: 'Highlighter',
                    tool: DrawingTool.highlighter,
                  ),
                  _buildToolButton(
                    icon: Icons.auto_fix_high,
                    label: 'Eraser',
                    tool: DrawingTool.eraser,
                  ),
                  _buildToolButton(
                    icon: Icons.horizontal_rule,
                    label: 'Line',
                    tool: DrawingTool.line,
                  ),
                  _buildToolButton(
                    icon: Icons.crop_square,
                    label: 'Rectangle',
                    tool: DrawingTool.rectangle,
                  ),
                  _buildToolButton(
                    icon: Icons.circle_outlined,
                    label: 'Circle',
                    tool: DrawingTool.circle,
                  ),
                  const SizedBox(width: 16),
                  // Color picker button
                  InkWell(
                    onTap: _showColorPicker,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _currentColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stroke width slider
                  SizedBox(
                    width: 150,
                    child: Row(
                      children: [
                        const Icon(Icons.line_weight, size: 16),
                        Expanded(
                          child: Slider(
                            value: _strokeWidth,
                            min: 1,
                            max: 20,
                            divisions: 19,
                            onChanged: (value) {
                              setState(() {
                                _strokeWidth = value;
                              });
                            },
                          ),
                        ),
                        Text('${_strokeWidth.toInt()}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Background options
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Text('Background: '),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('None'),
                  selected: !_showGrid && !_showLines,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _showGrid = false;
                        _showLines = false;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Grid'),
                  selected: _showGrid,
                  onSelected: (selected) {
                    setState(() {
                      _showGrid = selected;
                      if (selected) _showLines = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Lines'),
                  selected: _showLines,
                  onSelected: (selected) {
                    setState(() {
                      _showLines = selected;
                      if (selected) _showGrid = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Drawing canvas
          Expanded(
            child: Container(
              color: Colors.white,
              child: RepaintBoundary(
                key: _canvasKey,
                child: DrawingCanvas(
                  paths: _paths,
                  currentTool: _currentTool,
                  currentColor: _currentColor,
                  strokeWidth: _strokeWidth,
                  showGrid: _showGrid,
                  showLines: _showLines,
                  onPathsChanged: _onPathsChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required DrawingTool tool,
  }) {
    final isSelected = _currentTool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTool = tool;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
