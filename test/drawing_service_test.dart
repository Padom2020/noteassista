import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/drawing_service.dart';

void main() {
  group('DrawingService Tests', () {
    late DrawingService drawingService;

    setUp(() {
      drawingService = DrawingService();
    });

    group('URL Validation', () {
      test('should validate Firebase Storage URLs', () async {
        const validUrl =
            'https://firebasestorage.googleapis.com/v0/b/project/o/image.png?alt=media';
        final result = await drawingService.validateDrawingUrl(validUrl);
        expect(result, isTrue);
      });

      test('should reject non-Firebase URLs', () async {
        const invalidUrl = 'https://example.com/image.png';
        final result = await drawingService.validateDrawingUrl(invalidUrl);
        expect(result, isFalse);
      });

      test('should reject non-image URLs', () async {
        const invalidUrl =
            'https://firebasestorage.googleapis.com/v0/b/project/o/document.pdf?alt=media';
        final result = await drawingService.validateDrawingUrl(invalidUrl);
        expect(result, isFalse);
      });

      test('should reject malformed URLs', () async {
        const invalidUrl = 'not-a-url';
        final result = await drawingService.validateDrawingUrl(invalidUrl);
        expect(result, isFalse);
      });
    });

    group('Cache Management', () {
      test('should initialize with empty cache', () {
        expect(drawingService.getCacheSize(), equals(0));
      });

      test('should clear cache', () {
        drawingService.clearCache();
        expect(drawingService.getCacheSize(), equals(0));
      });
    });

    group('Drawing Load Result', () {
      test('should create successful result', () {
        final result = DrawingLoadResult(
          success: true,
          originalSize: const Size(100, 100),
        );

        expect(result.success, isTrue);
        expect(result.originalSize.width, equals(100));
        expect(result.originalSize.height, equals(100));
        expect(result.errorMessage, isNull);
      });

      test('should create error result', () {
        final result = DrawingLoadResult(
          success: false,
          errorMessage: 'Test error',
          originalSize: Size.zero,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Test error'));
        expect(result.originalSize, equals(Size.zero));
      });
    });
  });
}
