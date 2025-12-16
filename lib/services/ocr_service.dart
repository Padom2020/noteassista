import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Temporarily disabled due to network issues
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
///
/// NOTE: OCR functionality is temporarily disabled due to network issues with ML Kit dependencies.
/// This is a stub implementation that returns placeholder results.
class OCRService {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  OCRService();

  /// Extract text from an image file
  ///
  /// NOTE: OCR functionality is temporarily disabled due to network issues with ML Kit dependencies.
  Future<OCRResult> extractTextFromImage(String imagePath) async {
    debugPrint('OCR is temporarily disabled due to ML Kit dependency issues');
    return OCRResult(
      extractedText: 'OCR temporarily unavailable - please try again later',
      confidence: 0.0,
      blocks: [],
    );
  }

  /// Extract text from image with specific language support
  ///
  /// NOTE: OCR functionality is temporarily disabled due to network issues with ML Kit dependencies.
  Future<OCRResult> extractTextWithLanguage(
    String imagePath,
    String languageCode,
  ) async {
    debugPrint('OCR is temporarily disabled due to ML Kit dependency issues');
    return OCRResult(
      extractedText: 'OCR temporarily unavailable - please try again later',
      confidence: 0.0,
      blocks: [],
    );
  }

  /// Optimize image for better OCR accuracy
  ///
  /// This method still works as it only uses flutter_image_compress
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
  ///
  /// NOTE: OCR functionality is temporarily disabled due to network issues with ML Kit dependencies.
  Future<bool> isAvailable() async {
    return false; // Temporarily disabled
  }

  /// Extract handwritten text from a drawing image
  ///
  /// NOTE: OCR functionality is temporarily disabled due to network issues with ML Kit dependencies.
  Future<OCRResult> extractHandwrittenText(String imagePath) async {
    debugPrint('OCR is temporarily disabled due to ML Kit dependency issues');
    return OCRResult(
      extractedText: 'OCR temporarily unavailable - please try again later',
      confidence: 0.0,
      blocks: [],
    );
  }

  /// Clean up resources
  Future<void> dispose() async {
    // Nothing to dispose when ML Kit is disabled
  }
}
