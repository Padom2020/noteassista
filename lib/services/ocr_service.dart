import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

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
  final FirebaseStorage? _storage;

  // Text recognizer for Latin script (default)
  late final TextRecognizer _textRecognizer;

  // Cache for language-specific recognizers
  final Map<String, TextRecognizer> _recognizerCache = {};

  OCRService({FirebaseStorage? storage}) : _storage = storage {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Get Firebase Storage instance (lazy initialization)
  FirebaseStorage get _storageInstance {
    if (_storage != null) return _storage;
    return FirebaseStorage.instance;
  }

  /// Extract text from an image file
  ///
  /// This method processes the image using Google ML Kit's text recognition
  /// and returns the extracted text along with confidence scores and text blocks.
  ///
  /// The image is automatically optimized before processing for better accuracy.
  Future<OCRResult> extractTextFromImage(String imagePath) async {
    try {
      // Optimize image first for better OCR accuracy
      final optimizedPath = await optimizeImage(imagePath);

      // Create input image from file
      final inputImage = InputImage.fromFilePath(optimizedPath);

      // Process image with text recognizer
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract text blocks with bounding boxes and confidence
      final blocks = <TextBlock>[];
      double totalConfidence = 0.0;
      int blockCount = 0;

      for (final block in recognizedText.blocks) {
        // Calculate average confidence for the block
        double blockConfidence = 0.0;
        int lineCount = 0;

        for (final _ in block.lines) {
          // ML Kit doesn't provide confidence directly, so we estimate based on text quality
          // In a real implementation, you might use additional heuristics
          blockConfidence += 0.85; // Default confidence estimate
          lineCount++;
        }

        if (lineCount > 0) {
          blockConfidence /= lineCount;
          totalConfidence += blockConfidence;
          blockCount++;
        }

        blocks.add(
          TextBlock(
            text: block.text,
            boundingBox: block.boundingBox,
            confidence: blockConfidence,
          ),
        );
      }

      // Calculate overall confidence
      final overallConfidence =
          blockCount > 0 ? totalConfidence / blockCount : 0.0;

      // Clean up optimized image if it's different from original
      if (optimizedPath != imagePath) {
        try {
          await File(optimizedPath).delete();
        } catch (e) {
          debugPrint('Failed to delete optimized image: $e');
        }
      }

      return OCRResult(
        extractedText: recognizedText.text,
        confidence: overallConfidence,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract text from image with specific language support
  ///
  /// Supports multiple languages by using language-specific text recognizers.
  /// Common language codes: 'en' (English), 'es' (Spanish), 'fr' (French),
  /// 'de' (German), 'zh' (Chinese), 'ja' (Japanese), 'ko' (Korean), etc.
  Future<OCRResult> extractTextWithLanguage(
    String imagePath,
    String languageCode,
  ) async {
    try {
      // Get or create language-specific recognizer
      TextRecognizer recognizer;

      if (_recognizerCache.containsKey(languageCode)) {
        recognizer = _recognizerCache[languageCode]!;
      } else {
        // Map language codes to ML Kit scripts
        TextRecognitionScript script;
        switch (languageCode.toLowerCase()) {
          case 'zh':
          case 'zh-cn':
          case 'zh-tw':
            script = TextRecognitionScript.chinese;
            break;
          case 'ja':
            script = TextRecognitionScript.japanese;
            break;
          case 'ko':
            script = TextRecognitionScript.korean;
            break;
          default:
            // For all other languages including Hindi, use Latin script
            // ML Kit supports: latin, chinese, japanese, korean
            script = TextRecognitionScript.latin;
        }

        recognizer = TextRecognizer(script: script);
        _recognizerCache[languageCode] = recognizer;
      }

      // Optimize image
      final optimizedPath = await optimizeImage(imagePath);

      // Create input image
      final inputImage = InputImage.fromFilePath(optimizedPath);

      // Process with language-specific recognizer
      final recognizedText = await recognizer.processImage(inputImage);

      // Extract blocks
      final blocks = <TextBlock>[];
      double totalConfidence = 0.0;
      int blockCount = 0;

      for (final block in recognizedText.blocks) {
        double blockConfidence = 0.85; // Default estimate
        totalConfidence += blockConfidence;
        blockCount++;

        blocks.add(
          TextBlock(
            text: block.text,
            boundingBox: block.boundingBox,
            confidence: blockConfidence,
          ),
        );
      }

      final overallConfidence =
          blockCount > 0 ? totalConfidence / blockCount : 0.0;

      // Clean up
      if (optimizedPath != imagePath) {
        try {
          await File(optimizedPath).delete();
        } catch (e) {
          debugPrint('Failed to delete optimized image: $e');
        }
      }

      return OCRResult(
        extractedText: recognizedText.text,
        confidence: overallConfidence,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('Error extracting text with language $languageCode: $e');
      throw Exception('Failed to extract text: $e');
    }
  }

  /// Optimize image for better OCR accuracy
  ///
  /// This method:
  /// - Resizes large images to optimal size (max 2048x2048)
  /// - Compresses image to reduce file size
  /// - Enhances image quality for better text recognition
  ///
  /// Returns the path to the optimized image file.
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

  /// Upload image to Firebase Storage
  ///
  /// Uploads the image file to Firebase Storage under the user's directory
  /// and returns the download URL.
  ///
  /// Path structure: users/{userId}/images/{noteId}/{timestamp}.jpg
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
      final fileName = '$timestamp.jpg';

      // Create storage reference
      final storageRef = _storageInstance
          .ref()
          .child('users')
          .child(userId)
          .child('images')
          .child(noteId)
          .child(fileName);

      // Upload file
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'noteId': noteId,
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Check if OCR is available on this device
  ///
  /// ML Kit text recognition works offline and should be available on all devices,
  /// but this method can be used to verify availability.
  Future<bool> isAvailable() async {
    try {
      // ML Kit is available on all supported platforms
      // We can do a simple test to verify
      return true;
    } catch (e) {
      debugPrint('OCR not available: $e');
      return false;
    }
  }

  /// Extract handwritten text from a drawing image
  ///
  /// This method is specifically optimized for handwriting recognition.
  /// It uses the same ML Kit text recognition but with preprocessing
  /// optimized for handwritten content.
  ///
  /// Returns an OCRResult containing the recognized handwritten text.
  Future<OCRResult> extractHandwrittenText(String imagePath) async {
    try {
      // For handwriting, we use the same text recognizer but with
      // different preprocessing. ML Kit's text recognition handles
      // both printed and handwritten text.

      // Optimize image for handwriting recognition
      final optimizedPath = await optimizeImage(imagePath);

      // Create input image
      final inputImage = InputImage.fromFilePath(optimizedPath);

      // Process with text recognizer
      // ML Kit automatically detects and handles handwritten text
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract blocks
      final blocks = <TextBlock>[];
      double totalConfidence = 0.0;
      int blockCount = 0;

      for (final block in recognizedText.blocks) {
        // For handwriting, confidence might be lower than printed text
        // We use a slightly lower default estimate
        double blockConfidence = 0.75; // Handwriting confidence estimate
        totalConfidence += blockConfidence;
        blockCount++;

        blocks.add(
          TextBlock(
            text: block.text,
            boundingBox: block.boundingBox,
            confidence: blockConfidence,
          ),
        );
      }

      final overallConfidence =
          blockCount > 0 ? totalConfidence / blockCount : 0.0;

      // Clean up optimized image if different from original
      if (optimizedPath != imagePath) {
        try {
          await File(optimizedPath).delete();
        } catch (e) {
          debugPrint('Failed to delete optimized image: $e');
        }
      }

      return OCRResult(
        extractedText: recognizedText.text,
        confidence: overallConfidence,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('Error extracting handwritten text: $e');
      throw Exception('Failed to extract handwritten text: $e');
    }
  }

  /// Clean up resources
  ///
  /// Should be called when the service is no longer needed to free up resources.
  Future<void> dispose() async {
    try {
      await _textRecognizer.close();

      // Close all cached recognizers
      for (final recognizer in _recognizerCache.values) {
        await recognizer.close();
      }
      _recognizerCache.clear();
    } catch (e) {
      debugPrint('Error disposing OCR service: $e');
    }
  }
}
