import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/utils/graph_coordinate_system.dart';
import 'package:noteassista/services/link_management_service.dart';

void main() {
  group('Graph Coordinate System Integration Tests', () {
    testWidgets(
      'coordinate transformations work correctly at various zoom levels',
      (WidgetTester tester) async {
        // Test Requirements: 1.5, 4.2

        const canvasSize = Size(800, 600);
        final testPositions = [
          const Offset(100, 100),
          const Offset(400, 300), // Center
          const Offset(700, 500),
          const Offset(0, 0), // Edge cases
          const Offset(800, 600),
        ];

        // Test at different zoom levels
        final zoomLevels = [0.5, 1.0, 2.0, 4.0];

        for (final zoom in zoomLevels) {
          final transformation = Matrix4.identity()..scale(zoom);

          for (final screenPos in testPositions) {
            // Test screen to graph conversion
            final graphPos = GraphCoordinateSystem.screenToGraph(
              screenPos,
              transformation,
              canvasSize,
            );

            // Test round-trip conversion
            final backToScreen = GraphCoordinateSystem.graphToScreen(
              graphPos,
              transformation,
              canvasSize,
            );

            // Verify round-trip accuracy (within reasonable tolerance)
            expect(
              (backToScreen - screenPos).distance,
              lessThan(1.0),
              reason:
                  'Round-trip conversion failed at zoom $zoom for position $screenPos',
            );
          }
        }
      },
    );

    testWidgets('node hit detection works correctly with transformations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.3, 1.4

      const canvasSize = Size(800, 600);

      // Create test nodes at various positions
      final testNodes = [
        GraphNode(
          id: 'node1',
          title: 'Test Node 1',
          x: 0,
          y: 0,
          connectionCount: 1,
          tags: [],
        ),
        GraphNode(
          id: 'node2',
          title: 'Test Node 2',
          x: 100,
          y: 100,
          connectionCount: 3,
          tags: [],
        ),
        GraphNode(
          id: 'node3',
          title: 'Test Node 3',
          x: -50,
          y: 50,
          connectionCount: 0,
          tags: [],
        ),
      ];

      for (final node in testNodes) {
        // Test hit detection at node center
        final nodeCenter = Offset(
          canvasSize.width / 2 + node.x,
          canvasSize.height / 2 + node.y,
        );

        expect(
          GraphCoordinateSystem.isPointInNode(nodeCenter, node, canvasSize),
          isTrue,
          reason: 'Hit detection failed at node center for ${node.id}',
        );

        // Test hit detection just outside node radius
        final nodeRadius = GraphCoordinateSystem.calculateNodeRadius(node);
        final outsidePoint = Offset(
          nodeCenter.dx + nodeRadius + 1,
          nodeCenter.dy,
        );

        expect(
          GraphCoordinateSystem.isPointInNode(outsidePoint, node, canvasSize),
          isFalse,
          reason:
              'Hit detection incorrectly detected hit outside node ${node.id}',
        );
      }
    });

    testWidgets('getNodeAtPosition works with various graph configurations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.3, 1.4, 2.1

      const canvasSize = Size(800, 600);
      final transformation = Matrix4.identity();

      // Test with empty graph
      final emptyGraph = GraphData(nodes: [], edges: []);

      final resultEmpty = GraphCoordinateSystem.getNodeAtPosition(
        const Offset(400, 300),
        emptyGraph,
        transformation,
        canvasSize,
      );

      expect(resultEmpty, isNull, reason: 'Should return null for empty graph');

      // Test with single node
      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'single',
            title: 'Single Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      // Test hit at center (where node should be)
      GraphCoordinateSystem.getNodeAtPosition(
        const Offset(400, 300), // Center of canvas
        singleNodeGraph,
        transformation,
        canvasSize,
      );

      // Test miss (away from center)
      final resultMiss = GraphCoordinateSystem.getNodeAtPosition(
        const Offset(100, 100),
        singleNodeGraph,
        transformation,
        canvasSize,
      );

      expect(
        resultMiss,
        isNull,
        reason: 'Should miss node when clicking away from it',
      );
    });

    testWidgets('coordinate validation works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 4.3

      // Test valid positions
      expect(
        GraphCoordinateSystem.isValidPosition(const Offset(100, 200)),
        isTrue,
      );

      expect(GraphCoordinateSystem.isValidPosition(const Offset(0, 0)), isTrue);

      // Test invalid positions
      expect(
        GraphCoordinateSystem.isValidPosition(const Offset(double.nan, 100)),
        isFalse,
      );

      expect(
        GraphCoordinateSystem.isValidPosition(
          const Offset(100, double.infinity),
        ),
        isFalse,
      );

      // Test bounds validation
      const bounds = Rect.fromLTWH(0, 0, 800, 600);

      expect(
        GraphCoordinateSystem.isValidPosition(const Offset(400, 300), bounds),
        isTrue,
      );

      expect(
        GraphCoordinateSystem.isValidPosition(const Offset(900, 300), bounds),
        isFalse,
      );
    });

    testWidgets('transformation matrix validation works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 4.2, 4.3

      // Test valid transformation matrix
      final validMatrix = Matrix4.identity();
      expect(
        GraphCoordinateSystem.isValidTransformationMatrix(validMatrix),
        isTrue,
      );

      // Test scaled matrix
      final scaledMatrix = Matrix4.identity()..scale(2.0);
      expect(
        GraphCoordinateSystem.isValidTransformationMatrix(scaledMatrix),
        isTrue,
      );

      // Test translated matrix
      final translatedMatrix = Matrix4.identity()..translate(100.0, 200.0);
      expect(
        GraphCoordinateSystem.isValidTransformationMatrix(translatedMatrix),
        isTrue,
      );

      // Test matrix with NaN values (invalid)
      final invalidMatrix = Matrix4.identity();
      invalidMatrix.setEntry(0, 0, double.nan);
      expect(
        GraphCoordinateSystem.isValidTransformationMatrix(invalidMatrix),
        isFalse,
      );
    });

    testWidgets('gesture input validation works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 4.3

      // Test valid gesture inputs
      expect(
        GraphCoordinateSystem.validateGestureInput(const Offset(100, 200)),
        isTrue,
      );

      expect(
        GraphCoordinateSystem.validateGestureInput(const Offset(0, 0)),
        isTrue,
      );

      // Test invalid gesture inputs
      expect(GraphCoordinateSystem.validateGestureInput(null), isFalse);

      expect(
        GraphCoordinateSystem.validateGestureInput(
          const Offset(double.nan, 100),
        ),
        isFalse,
      );

      // Test node ID validation
      expect(GraphCoordinateSystem.validateNodeId('valid-node-id'), isTrue);

      expect(GraphCoordinateSystem.validateNodeId(''), isFalse);

      expect(GraphCoordinateSystem.validateNodeId(null), isFalse);

      expect(GraphCoordinateSystem.validateNodeId('   '), isFalse);
    });

    testWidgets('scale and translation extraction works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 4.2

      // Test scale extraction
      final scaledMatrix = Matrix4.identity()..scale(2.5);
      final extractedScale = GraphCoordinateSystem.getScaleFactor(scaledMatrix);
      expect(extractedScale, closeTo(2.5, 0.01));

      // Test translation extraction
      final translatedMatrix = Matrix4.identity()..translate(150.0, 250.0);
      final extractedTranslation = GraphCoordinateSystem.getTranslationOffset(
        translatedMatrix,
      );
      expect(extractedTranslation.dx, closeTo(150.0, 0.01));
      expect(extractedTranslation.dy, closeTo(250.0, 0.01));

      // Test combined transformation
      final combinedMatrix =
          Matrix4.identity()
            ..translate(100.0, 200.0)
            ..scale(1.5);

      final combinedScale = GraphCoordinateSystem.getScaleFactor(
        combinedMatrix,
      );
      final combinedTranslation = GraphCoordinateSystem.getTranslationOffset(
        combinedMatrix,
      );

      expect(combinedScale, closeTo(1.5, 0.01));
      expect(combinedTranslation.dx, closeTo(100.0, 0.01));
      expect(combinedTranslation.dy, closeTo(200.0, 0.01));
    });

    testWidgets('node radius calculation works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.3, 1.4

      // Test base node (no connections)
      final baseNode = GraphNode(
        id: 'base',
        title: 'Base Node',
        x: 0,
        y: 0,
        connectionCount: 0,
        tags: [],
      );

      final baseRadius = GraphCoordinateSystem.calculateNodeRadius(baseNode);
      expect(baseRadius, equals(20.0)); // Base size

      // Test node with connections
      final connectedNode = GraphNode(
        id: 'connected',
        title: 'Connected Node',
        x: 0,
        y: 0,
        connectionCount: 5,
        tags: [],
      );

      final connectedRadius = GraphCoordinateSystem.calculateNodeRadius(
        connectedNode,
      );
      expect(connectedRadius, greaterThan(baseRadius));
      expect(connectedRadius, lessThanOrEqualTo(60.0)); // Max size (20 * 3)

      // Test dynamic radius with scale factor
      final dynamicRadius = GraphCoordinateSystem.calculateDynamicNodeRadius(
        connectedNode,
        2.0,
      );
      expect(dynamicRadius, equals(connectedRadius * 2.0));

      // Test bounds clamping
      final extremeRadius = GraphCoordinateSystem.calculateDynamicNodeRadius(
        connectedNode,
        10.0, // Very large scale
      );
      expect(extremeRadius, lessThanOrEqualTo(100.0)); // Max radius
    });
  });
}
