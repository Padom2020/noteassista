import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';

/// Screen that shows OCR extraction progress and allows user to review/edit extracted text
class OCRProcessingScreen extends StatefulWidget {
  final List<File> images;
  final Function(String extractedText, List<String> imageUrls) onComplete;

  const OCRProcessingScreen({
    super.key,
    required this.images,
    required this.onComplete,
  });

  @override
  State<OCRProcessingScreen> createState() => _OCRProcessingScreenState();
}

class _OCRProcessingScreenState extends State<OCRProcessingScreen> {
  final OCRService _ocrService = OCRService();
  final TextEditingController _extractedTextController =
      TextEditingController();

  bool _isProcessing = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _progress = 0.0;
  int _currentImageIndex = 0;
  final List<String> _imagePaths = [];
  final List<OCRResult> _ocrResults = [];

  @override
  void initState() {
    super.initState();
    _processImages();
  }

  @override
  void dispose() {
    _extractedTextController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _processImages() async {
    setState(() {
      _isProcessing = true;
      _hasError = false;
      _progress = 0.0;
    });

    try {
      final totalImages = widget.images.length;
      final allExtractedText = <String>[];

      for (int i = 0; i < totalImages; i++) {
        setState(() {
          _currentImageIndex = i;
          _progress = (i / totalImages);
        });

        final image = widget.images[i];
        _imagePaths.add(image.path);

        // Extract text from image
        final result = await _ocrService.extractTextFromImage(image.path);
        _ocrResults.add(result);

        if (result.extractedText.isNotEmpty) {
          allExtractedText.add(result.extractedText);
        }

        // Update progress
        setState(() {
          _progress = ((i + 1) / totalImages);
        });
      }

      // Combine all extracted text
      final combinedText = allExtractedText.join('\n\n');
      _extractedTextController.text = combinedText;

      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _hasError = true;
        _errorMessage = 'Failed to extract text: $e';
      });
    }
  }

  void _retryProcessing() {
    _processImages();
  }

  void _completeAndReturn() {
    final extractedText = _extractedTextController.text.trim();
    Navigator.pop(context);
    widget.onComplete(extractedText, _imagePaths);
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text from Images'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body:
          _isProcessing
              ? _buildProcessingView()
              : _hasError
              ? _buildErrorView()
              : _buildReviewView(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing image ${_currentImageIndex + 1} of ${widget.images.length}...',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Extracting text from images...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 24),
            const Text(
              'Text Extraction Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _retryProcessing,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewView() {
    final hasText = _extractedTextController.text.trim().isNotEmpty;

    return Column(
      children: [
        // Image thumbnails
        if (_imagePaths.isNotEmpty)
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePaths[index]),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),

        // Confidence indicator
        if (_ocrResults.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: _getConfidenceColor(_getAverageConfidence()),
                ),
                const SizedBox(width: 8),
                Text(
                  'Confidence: ${(_getAverageConfidence() * 100).toInt()}%',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

        const Divider(),

        // Extracted text editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (!hasText)
                      Text(
                        'No text detected',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Review and correct the extracted text below:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _extractedTextController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText:
                          hasText
                              ? 'Edit extracted text...'
                              : 'No text was detected. You can type manually or cancel.',
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _completeAndReturn,
                  icon: const Icon(Icons.check),
                  label: const Text('Add to Note'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getAverageConfidence() {
    if (_ocrResults.isEmpty) return 0.0;
    final sum = _ocrResults.fold<double>(
      0.0,
      (prev, result) => prev + result.confidence,
    );
    return sum / _ocrResults.length;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
