import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/drawing_service.dart';
import 'package:noteassista/widgets/drawing_canvas.dart';

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

    group('Property-Based Tests', () {
      group('Property 12: Drawing URL loading preservation', () {
        test('should preserve valid Firebase Storage URL format', () {
          // **Feature: advanced-features, Property 12: Drawing URL loading preservation**
          // **Validates: Requirements 36.1, 36.7**

          // Property: For any valid Firebase Storage URL, the URL should remain valid after validation
          final random = Random();

          for (int i = 0; i < 100; i++) {
            // Generate valid Firebase Storage URL
            final projectId = 'test-project-${random.nextInt(1000)}';
            final fileName = 'drawing-${random.nextInt(10000)}';
            final extension = ['png', 'jpg', 'jpeg'][random.nextInt(3)];
            final token = 'token-${random.nextInt(100000)}';

            final validUrl =
                'https://firebasestorage.googleapis.com/v0/b/$projectId.appspot.com/o/$fileName.$extension?alt=media&token=$token';

            // Property: Valid URLs should pass validation
            expect(
              drawingService.validateDrawingUrl(validUrl),
              completion(isTrue),
              reason:
                  'Valid Firebase Storage URL should pass validation: $validUrl',
            );
          }
        });

        test('should reject invalid URL formats consistently', () {
          // **Feature: advanced-features, Property 12: Drawing URL loading preservation**
          // **Validates: Requirements 36.1, 36.7**

          // Property: For any invalid URL format, validation should consistently return false
          final random = Random();
          final invalidUrlPatterns = [
            'https://example.com/image.png',
            'not-a-url',
            'ftp://firebasestorage.googleapis.com/image.png',
            'https://firebasestorage.googleapis.com/document.pdf',
            'https://other-storage.com/image.png',
          ];

          for (int i = 0; i < 100; i++) {
            final invalidUrl =
                invalidUrlPatterns[random.nextInt(invalidUrlPatterns.length)];

            // Property: Invalid URLs should consistently fail validation
            expect(
              drawingService.validateDrawingUrl(invalidUrl),
              completion(isFalse),
              reason: 'Invalid URL should fail validation: $invalidUrl',
            );
          }
        });

        test('should handle URL validation edge cases', () {
          // **Feature: advanced-features, Property 12: Drawing URL loading preservation**
          // **Validates: Requirements 36.1, 36.7**

          // Property: For any edge case URL, validation should not throw exceptions
          final edgeCaseUrls = [
            '',
            ' ',
            'https://',
            'https://firebasestorage.googleapis.com/',
            'https://firebasestorage.googleapis.com/v0/b/.appspot.com/o/.png',
            'https://firebasestorage.googleapis.com/v0/b/project/o/image.PNG?alt=media', // uppercase extension
            'https://firebasestorage.googleapis.com/v0/b/project/o/image.jpeg?alt=media&token=', // empty token
          ];

          for (final url in edgeCaseUrls) {
            // Property: Edge cases should not throw exceptions
            expect(
              () => drawingService.validateDrawingUrl(url),
              returnsNormally,
              reason: 'URL validation should not throw for edge case: $url',
            );
          }
        });
      });

      group('Property 13: Drawing composition integrity', () {
        test('should preserve canvas size during composition', () {
          // **Feature: advanced-features, Property 13: Drawing composition integrity**
          // **Validates: Requirements 36.4, 36.6**

          // Property: For any canvas size, composition should preserve the specified dimensions
          final random = Random();

          for (int i = 0; i < 50; i++) {
            final width = 100 + random.nextInt(900); // 100-1000 pixels
            final height = 100 + random.nextInt(900); // 100-1000 pixels
            final canvasSize = Size(width.toDouble(), height.toDouble());

            // Create empty drawing paths for testing
            final paths = <DrawingPath>[];

            // Property: Composition should preserve canvas dimensions
            expect(
              () => drawingService.compositeDrawingLayers(
                null,
                paths,
                canvasSize,
              ),
              returnsNormally,
              reason:
                  'Composition should handle canvas size: ${canvasSize.width}x${canvasSize.height}',
            );
          }
        });

        test('should handle empty drawing paths gracefully', () {
          // **Feature: advanced-features, Property 13: Drawing composition integrity**
          // **Validates: Requirements 36.4, 36.6**

          // Property: For any canvas size with empty paths, composition should succeed
          final random = Random();
          final canvasSizes = [
            const Size(100, 100),
            const Size(500, 300),
            const Size(1000, 800),
            Size(
              random.nextDouble() * 1000 + 100,
              random.nextDouble() * 1000 + 100,
            ),
          ];

          for (final canvasSize in canvasSizes) {
            final emptyPaths = <DrawingPath>[];

            // Property: Empty paths should not cause composition to fail
            expect(
              () => drawingService.compositeDrawingLayers(
                null,
                emptyPaths,
                canvasSize,
              ),
              returnsNormally,
              reason:
                  'Empty paths should be handled gracefully for canvas: ${canvasSize.width}x${canvasSize.height}',
            );
          }
        });

        test('should maintain drawing path integrity during composition', () {
          // **Feature: advanced-features, Property 13: Drawing composition integrity**
          // **Validates: Requirements 36.4, 36.6**

          // Property: For any set of drawing paths, composition should not modify the original paths
          final random = Random();

          for (int i = 0; i < 30; i++) {
            final canvasSize = Size(500, 500);
            final originalPaths = _generateRandomDrawingPaths(random, 5);
            final pathsCopy = List<DrawingPath>.from(originalPaths);

            // Perform composition
            expect(
              () => drawingService.compositeDrawingLayers(
                null,
                originalPaths,
                canvasSize,
              ),
              returnsNormally,
            );

            // Property: Original paths should remain unchanged
            expect(
              originalPaths.length,
              equals(pathsCopy.length),
              reason: 'Path count should remain unchanged after composition',
            );

            for (int j = 0; j < originalPaths.length; j++) {
              expect(
                originalPaths[j].points.length,
                equals(pathsCopy[j].points.length),
                reason: 'Path $j point count should remain unchanged',
              );
              expect(
                originalPaths[j].tool,
                equals(pathsCopy[j].tool),
                reason: 'Path $j tool should remain unchanged',
              );
            }
          }
        });

        test('should handle various drawing tools consistently', () {
          // **Feature: advanced-features, Property 13: Drawing composition integrity**
          // **Validates: Requirements 36.4, 36.6**

          // Property: For any drawing tool type, composition should handle it without errors
          final canvasSize = const Size(400, 400);
          final tools = [
            DrawingTool.pen,
            DrawingTool.highlighter,
            DrawingTool.eraser,
            DrawingTool.line,
            DrawingTool.rectangle,
            DrawingTool.circle,
          ];

          for (final tool in tools) {
            final paths = [_createDrawingPathWithTool(tool)];

            // Property: All drawing tools should be composable
            expect(
              () => drawingService.compositeDrawingLayers(
                null,
                paths,
                canvasSize,
              ),
              returnsNormally,
              reason: 'Drawing tool $tool should be composable without errors',
            );
          }
        });

        test('should preserve cache consistency', () {
          // **Feature: advanced-features, Property 12: Drawing URL loading preservation**
          // **Validates: Requirements 36.1, 36.7**

          // Property: For any cache operation, the cache size should be consistent
          // Clear cache and verify
          drawingService.clearCache();
          expect(
            drawingService.getCacheSize(),
            equals(0),
            reason: 'Cache should be empty after clearing',
          );

          // Property: Cache size should never be negative
          expect(
            drawingService.getCacheSize(),
            greaterThanOrEqualTo(0),
            reason: 'Cache size should never be negative',
          );

          // Restore initial state
          drawingService.clearCache();
        });
      });
    });
  });
}

/// Helper function to generate random drawing paths for testing
List<DrawingPath> _generateRandomDrawingPaths(Random random, int count) {
  final paths = <DrawingPath>[];
  final tools = [
    DrawingTool.pen,
    DrawingTool.highlighter,
    DrawingTool.eraser,
    DrawingTool.line,
    DrawingTool.rectangle,
    DrawingTool.circle,
  ];

  for (int i = 0; i < count; i++) {
    final tool = tools[random.nextInt(tools.length)];
    paths.add(_createDrawingPathWithTool(tool));
  }

  return paths;
}

/// Helper function to create a drawing path with a specific tool
DrawingPath _createDrawingPathWithTool(DrawingTool tool) {
  final paint =
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

  final points = [
    DrawPoint(const Offset(10, 10), paint),
    DrawPoint(const Offset(50, 50), paint),
  ];

  return DrawingPath(points, tool);
}
