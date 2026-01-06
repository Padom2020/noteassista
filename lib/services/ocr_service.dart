import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../services/cloudinary_service.dart';

/// Result of OCR text extraction
class OCRResult {
  final String extractedText;
  final double confidence;
  final List<TextBlock> blocks;

  OCRResult({
    required this.extractedText,
    required this.confidence,
    required this.blocks,
  });

  @override
  String toString() {
    return 'OCRResult(text: ${extractedText.substring(0, extractedText.length > 50 ? 50 : extractedText.length)}..., confidence: $confidence, blocks: ${blocks.length})';
  }
}

/// Represents a block of recognized text with its position
class TextBlock {
  final String text;
  final ui.Rect boundingBox;
  final double confidence;

  TextBlock({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });

  @override
  String toString() {
    return 'TextBlock(text: $text, confidence: $confidence)';
  }
}

/// Service for extracting text from images using OCR
class OCRService {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  late TextRecognizer _textRecognizer;
  bool _isInitialized = false;

  OCRService() {
    _initializeRecognizer();
  }

  void _initializeRecognizer() {
    try {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _isInitialized = true;
      debugPrint('TextRecognizer initialized successfully');
    } catch (e) {
      debugPrint('Error initializing TextRecognizer: $e');
      _isInitialized = false;
    }
  }

  /// Extract text from an image file
  Future<OCRResult> extractTextFromImage(String imagePath) async {
    if (!_isInitialized) {
      _initializeRecognizer();
    }

    if (!_isInitialized) {
      return OCRResult(
        extractedText: 'OCR service not available',
        confidence: 0.0,
        blocks: [],
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final blocks = <TextBlock>[];
      double totalConfidence = 0.0;
      int blockCount = 0;

      for (final textBlock in recognizedText.blocks) {
        for (final line in textBlock.lines) {
          for (final element in line.elements) {
            blocks.add(
              TextBlock(
                text: element.text,
                boundingBox: ui.Rect.fromLTWH(
                  element.boundingBox.left.toDouble(),
                  element.boundingBox.top.toDouble(),
                  element.boundingBox.width.toDouble(),
                  element.boundingBox.height.toDouble(),
                ),
                confidence: element.confidence ?? 0.0,
              ),
            );
            totalConfidence += element.confidence ?? 0.0;
            blockCount++;
          }
        }
      }

      final extractedText = recognizedText.text;
      final averageConfidence =
          blockCount > 0 ? totalConfidence / blockCount : 0.0;

      debugPrint(
        'OCR extraction successful: ${extractedText.length} characters, confidence: $averageConfidence',
      );

      return OCRResult(
        extractedText: extractedText,
        confidence: averageConfidence,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      return OCRResult(
        extractedText: 'Error extracting text: $e',
        confidence: 0.0,
        blocks: [],
      );
    }
  }

  /// Extract text from image with specific language support
  Future<OCRResult> extractTextWithLanguage(
    String imagePath,
    String languageCode,
  ) async {
    // Note: Google ML Kit Text Recognition doesn't support language selection
    // It automatically detects the language. This method works the same as extractTextFromImage
    debugPrint(
      'Language parameter ignored - ML Kit auto-detects language. Extracting text...',
    );
    return extractTextFromImage(imagePath);
  }

  /// Optimize image for better OCR accuracy
  Future<String> optimizeImage(String imagePath) async {
    try {
      final originalFile = File(imagePath);

      // Check if file exists
      if (!await originalFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      // Get file size
      final fileSize = await originalFile.length();

      // If file is small enough and likely already optimized, return original
      if (fileSize < 500000) {
        // Less than 500KB
        return imagePath;
      }

      // Create temp directory for optimized image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final optimizedPath = '${tempDir.path}/optimized_$timestamp.jpg';

      // Compress and resize image
      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        optimizedPath,
        quality: 90,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('Image compression failed, using original');
        return imagePath;
      }

      return result.path;
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      // Return original path if optimization fails
      return imagePath;
    }
  }

  /// Upload image to Cloudinary
  Future<String> uploadImage(
    String imagePath,
    String userId,
    String noteId,
  ) async {
    try {
      final file = File(imagePath);

      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ocr_$timestamp.jpg';

      // Upload to Cloudinary
      final result = await _cloudinaryService.uploadImage(
        imageFile: file,
        userId: userId,
        noteId: noteId,
        fileName: fileName,
      );

      if (result.success && result.secureUrl != null) {
        debugPrint('Image uploaded successfully: ${result.secureUrl}');
        return result.secureUrl!;
      } else {
        throw Exception(result.errorMessage ?? 'Upload failed');
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Check if OCR is available on this device
  Future<bool> isAvailable() async {
    return _isInitialized;
  }

  /// Extract handwritten text from a drawing image
  Future<OCRResult> extractHandwrittenText(String imagePath) async {
    // Handwritten text extraction uses the same process as regular text
    return extractTextFromImage(imagePath);
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await _textRecognizer.close();
      _isInitialized = false;
      debugPrint('TextRecognizer disposed');
    } catch (e) {
      debugPrint('Error disposing TextRecognizer: $e');
    }
  }
}
