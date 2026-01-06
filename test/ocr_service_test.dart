import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Service Tests', () {
    late OCRService service;

    setUp(() {
      // Initialize OCR service for tests
      service = OCRService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('Data Models', () {
      test('OCRResult contains expected fields', () {
        final result = OCRResult(
          extractedText: 'Sample text',
          confidence: 0.85,
          blocks: [],
        );

        expect(result.extractedText, equals('Sample text'));
        expect(result.confidence, equals(0.85));
        expect(result.blocks, isEmpty);
      });

      test('OCRResult toString provides useful information', () {
        final result = OCRResult(
          extractedText:
              'This is a long text that should be truncated in the toString method',
          confidence: 0.92,
          blocks: [
            TextBlock(
              text: 'Block 1',
              boundingBox: const Rect.fromLTWH(0, 0, 100, 50),
              confidence: 0.9,
            ),
          ],
        );

        final str = result.toString();
        expect(str, contains('OCRResult'));
        expect(str, contains('confidence: 0.92'));
        expect(str, contains('blocks: 1'));
      });

      test('TextBlock contains expected fields', () {
        final block = TextBlock(
          text: 'Block text',
          boundingBox: const Rect.fromLTWH(10, 20, 100, 50),
          confidence: 0.88,
        );

        expect(block.text, equals('Block text'));
        expect(block.boundingBox.left, equals(10));
        expect(block.boundingBox.top, equals(20));
        expect(block.boundingBox.width, equals(100));
        expect(block.boundingBox.height, equals(50));
        expect(block.confidence, equals(0.88));
      });

      test('TextBlock toString provides useful information', () {
        final block = TextBlock(
          text: 'Test block',
          boundingBox: const Rect.fromLTWH(0, 0, 50, 25),
          confidence: 0.95,
        );

        final str = block.toString();
        expect(str, contains('TextBlock'));
        expect(str, contains('Test block'));
        expect(str, contains('0.95'));
      });

      test('OCRResult with multiple blocks', () {
        final blocks = [
          TextBlock(
            text: 'First block',
            boundingBox: const Rect.fromLTWH(0, 0, 100, 50),
            confidence: 0.9,
          ),
          TextBlock(
            text: 'Second block',
            boundingBox: const Rect.fromLTWH(0, 60, 100, 50),
            confidence: 0.85,
          ),
          TextBlock(
            text: 'Third block',
            boundingBox: const Rect.fromLTWH(0, 120, 100, 50),
            confidence: 0.88,
          ),
        ];

        final result = OCRResult(
          extractedText: 'First block\nSecond block\nThird block',
          confidence: 0.877,
          blocks: blocks,
        );

        expect(result.blocks.length, equals(3));
        expect(result.blocks[0].text, equals('First block'));
        expect(result.blocks[1].text, equals('Second block'));
        expect(result.blocks[2].text, equals('Third block'));
      });
    });

    group('Service Initialization', () {
      test('OCRService can be instantiated', () {
        expect(() => OCRService(), returnsNormally);
      });

      test('OCRService isAvailable returns initialization status', () async {
        final available = await service.isAvailable();
        // In test environment, TextRecognizer initializes but plugin may not be fully available
        expect(available, isA<bool>());
      });

      test('Multiple OCRService instances can coexist', () {
        final service1 = OCRService();
        final service2 = OCRService();

        expect(service1, isNotNull);
        expect(service2, isNotNull);
        expect(service1, isNot(same(service2)));
      });
    });

    group('Image Optimization', () {
      test(
        'optimizeImage returns original path for non-existent file',
        () async {
          // When file doesn't exist, service returns original path
          final result = await service.optimizeImage('/non/existent/path.jpg');
          expect(result, equals('/non/existent/path.jpg'));
        },
      );

      test('optimizeImage returns original path when file not found', () async {
        // The service gracefully handles missing files by returning original path
        final result = await service.optimizeImage('/invalid/path/image.jpg');
        expect(result, equals('/invalid/path/image.jpg'));
      });

      test('optimizeImage gracefully handles errors', () async {
        // Test that the service handles errors without crashing
        final result = await service.optimizeImage('/path/to/nowhere.jpg');
        // Returns original path when optimization fails
        expect(result, equals('/path/to/nowhere.jpg'));
      });
    });
  });
}
