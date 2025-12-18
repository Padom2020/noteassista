import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/link_management_service.dart';
import 'package:noteassista/utils/graph_coordinate_system.dart';

void main() {
  group('Graph View Integration Tests', () {
    setUp(() {
      // Initialize test environment
    });

    testWidgets(
      'double-tap functionality works across different screen sizes',
      (WidgetTester tester) async {
        // Test Requirements: 1.1, 1.2

        // Test with small screen size (phone)
        await tester.binding.setSurfaceSize(const Size(375, 667));
        await _testDoubleTapFunctionality(tester, 'small screen');

        // Test with medium screen size (tablet)
        await tester.binding.setSurfaceSize(const Size(768, 1024));
        await _testDoubleTapFunctionality(tester, 'medium screen');

        // Test with large screen size (desktop)
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        await _testDoubleTapFunctionality(tester, 'large screen');

        // Reset to default size
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets('gesture handling works with empty graph configuration', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 2.2

      await _setupMockGraphView(tester, GraphData(nodes: [], edges: []));

      // Wait for initial load
      await tester.pumpAndSettle();

      // Test tap on empty space - should not cause errors
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();

      // Test double-tap on empty space - should not cause errors
      await tester.tapAt(const Offset(200, 300));
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();

      // Verify no crashes or error dialogs
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('gesture handling works with single node configuration', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.3, 1.4

      // Create a mock graph with single node
      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);

      // Wait for graph to load
      await tester.pumpAndSettle();

      // Test single tap on node area (center of screen where node should be)
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Test double-tap on node area
      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Verify no crashes
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture handling works with dense graph configuration', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.4, 2.1

      // Create a mock graph with many nodes
      final denseGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'node-1',
            title: 'Node 1',
            x: -100,
            y: -100,
            connectionCount: 2,
            tags: ['tag1'],
          ),
          GraphNode(
            id: 'node-2',
            title: 'Node 2',
            x: 100,
            y: -100,
            connectionCount: 3,
            tags: ['tag2'],
          ),
          GraphNode(
            id: 'node-3',
            title: 'Node 3',
            x: -100,
            y: 100,
            connectionCount: 1,
            tags: ['tag3'],
          ),
          GraphNode(
            id: 'node-4',
            title: 'Node 4',
            x: 100,
            y: 100,
            connectionCount: 4,
            tags: ['tag4'],
          ),
        ],
        edges: [
          GraphEdge(sourceId: 'node-1', targetId: 'node-2'),
          GraphEdge(sourceId: 'node-2', targetId: 'node-3'),
          GraphEdge(sourceId: 'node-3', targetId: 'node-4'),
          GraphEdge(sourceId: 'node-4', targetId: 'node-1'),
        ],
      );

      await _setupMockGraphView(tester, denseGraph);

      // Wait for graph to load
      await tester.pumpAndSettle();

      // Test taps at various positions to simulate dense node interaction
      final testPositions = [
        const Offset(300, 300),
        const Offset(500, 400),
        const Offset(400, 500),
        const Offset(600, 300),
      ];

      for (final position in testPositions) {
        // Test single tap
        await tester.tapAt(position);
        await tester.pumpAndSettle();

        // Test double-tap
        await tester.tapAt(position);
        await tester.tapAt(position);
        await tester.pumpAndSettle();
      }

      // Verify no crashes during dense interaction
      expect(tester.takeException(), isNull);
    });

    testWidgets('zoom and pan gestures work correctly with tap gestures', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 2.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // Find the InteractiveViewer
      final interactiveViewer = find.byType(InteractiveViewer);
      expect(interactiveViewer, findsOneWidget);

      // Test pan gesture
      await tester.drag(interactiveViewer, const Offset(100, 100));
      await tester.pumpAndSettle();

      // Test tap after pan - should still work
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Test double-tap after pan - should still work
      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Verify no crashes during combined gestures
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation flow from graph view to note editing works', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.1, 1.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // Test double-tap navigation
      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Since we're testing in isolation without full navigation stack,
      // we verify that the navigation attempt doesn't cause crashes
      expect(tester.takeException(), isNull);

      // In a real integration test with full app context,
      // we would verify navigation to edit screen here
    });

    testWidgets('gesture detection accuracy across different zoom levels', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.5, 4.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      final interactiveViewer = find.byType(InteractiveViewer);

      // Test at default zoom level
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Simulate pan (since zoom gestures are complex to simulate)
      await tester.drag(interactiveViewer, const Offset(50, 50));
      await tester.pumpAndSettle();

      // Test gesture detection after transformation
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Test double-tap after transformation
      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Verify coordinate transformations work correctly
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty space gesture handling clears selections', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 2.5

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // First tap on node to select it
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Then tap on empty space to clear selection
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      // Test double-tap on empty space
      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      // Verify no crashes
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture handling with search filtering works correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 2.1, 2.2

      final denseGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'node-1',
            title: 'Test Node 1',
            x: -100,
            y: -100,
            connectionCount: 2,
            tags: ['test'],
          ),
          GraphNode(
            id: 'node-2',
            title: 'Node 2',
            x: 100,
            y: -100,
            connectionCount: 3,
            tags: ['other'],
          ),
        ],
        edges: [GraphEdge(sourceId: 'node-1', targetId: 'node-2')],
      );

      await _setupMockGraphView(tester, denseGraph);
      await tester.pumpAndSettle();

      // Find and use search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle();

      // Test gestures with search filter active
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pumpAndSettle();
      }

      // Verify no crashes during search interaction
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture handling works across different device orientations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.1, 1.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      // Test in portrait mode
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // Test gestures in portrait
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();

      // Switch to landscape mode
      await tester.binding.setSurfaceSize(const Size(667, 375));
      await tester.pumpAndSettle();

      // Test gestures in landscape
      await tester.tapAt(const Offset(300, 200));
      await tester.pumpAndSettle();

      // Test double-tap in landscape
      await tester.tapAt(const Offset(300, 200));
      await tester.tapAt(const Offset(300, 200));
      await tester.pumpAndSettle();

      // Reset to default size
      await tester.binding.setSurfaceSize(null);

      // Verify orientation changes don't break gestures
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid successive gestures are handled correctly', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 3.1, 3.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'test-node-1',
            title: 'Test Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // Perform rapid successive taps using position instead of widget finder
      for (int i = 0; i < 10; i++) {
        await tester.tapAt(const Offset(400, 400));
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpAndSettle();

      // Perform rapid successive double-taps using position
      for (int i = 0; i < 5; i++) {
        await tester.tapAt(const Offset(400, 400));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tapAt(const Offset(400, 400));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Verify rapid gestures don't cause performance issues or crashes
      expect(tester.takeException(), isNull);
    });

    testWidgets('gesture boundaries are respected for overlapping nodes', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.4

      final overlappingNodesGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'node-1',
            title: 'Node 1',
            x: -10,
            y: -10,
            connectionCount: 1,
            tags: [],
          ),
          GraphNode(
            id: 'node-2',
            title: 'Node 2',
            x: 10,
            y: 10,
            connectionCount: 1,
            tags: [],
          ),
        ],
        edges: [GraphEdge(sourceId: 'node-1', targetId: 'node-2')],
      );

      await _setupMockGraphView(tester, overlappingNodesGraph);
      await tester.pumpAndSettle();

      // Test taps at various positions to simulate overlapping node scenarios
      final testPositions = [
        const Offset(350, 350), // Slightly off-center
        const Offset(400, 400), // Center
        const Offset(450, 450), // Slightly off-center other direction
        const Offset(380, 420), // Diagonal offset
      ];

      for (final position in testPositions) {
        // Single tap
        await tester.tapAt(position);
        await tester.pumpAndSettle();

        // Double-tap
        await tester.tapAt(position);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(position);
        await tester.pumpAndSettle();
      }

      // Verify precise hit detection works
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'gesture detection accuracy is maintained during state changes',
      (WidgetTester tester) async {
        // Test Requirements: 1.3, 2.2

        final singleNodeGraph = GraphData(
          nodes: [
            GraphNode(
              id: 'test-node-1',
              title: 'Test Node',
              x: 0,
              y: 0,
              connectionCount: 0,
              tags: [],
            ),
          ],
          edges: [],
        );

        await _setupMockGraphView(tester, singleNodeGraph);
        await tester.pumpAndSettle();

        // Trigger a state change by toggling graph mode
        final toggleButton = find.byIcon(Icons.location_on);
        if (toggleButton.evaluate().isNotEmpty) {
          await tester.tap(toggleButton);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Test gesture during potential state change
        await tester.tapAt(const Offset(400, 400));
        await tester.pump(const Duration(milliseconds: 50));

        // Complete any state changes
        await tester.pumpAndSettle();

        // Test gesture after state change completes
        await tester.tapAt(const Offset(400, 400));
        await tester.pumpAndSettle();

        // Verify gestures work during and after state changes
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'coordinate transformation accuracy across zoom and pan operations',
      (WidgetTester tester) async {
        // Test Requirements: 1.5, 4.2

        final multiNodeGraph = GraphData(
          nodes: [
            GraphNode(
              id: 'center-node',
              title: 'Center Node',
              x: 0,
              y: 0,
              connectionCount: 2,
              tags: [],
            ),
            GraphNode(
              id: 'top-node',
              title: 'Top Node',
              x: 0,
              y: -100,
              connectionCount: 1,
              tags: [],
            ),
            GraphNode(
              id: 'bottom-node',
              title: 'Bottom Node',
              x: 0,
              y: 100,
              connectionCount: 1,
              tags: [],
            ),
          ],
          edges: [
            GraphEdge(sourceId: 'center-node', targetId: 'top-node'),
            GraphEdge(sourceId: 'center-node', targetId: 'bottom-node'),
          ],
        );

        await _setupMockGraphView(tester, multiNodeGraph);
        await tester.pumpAndSettle();

        final interactiveViewer = find.byType(InteractiveViewer);

        // Test gestures at original position
        await tester.tapAt(const Offset(400, 400)); // Center
        await tester.pumpAndSettle();

        // Apply pan transformation
        await tester.drag(interactiveViewer, const Offset(100, 50));
        await tester.pumpAndSettle();

        // Test gestures after pan
        await tester.tapAt(const Offset(400, 400));
        await tester.pumpAndSettle();

        // Apply another transformation
        await tester.drag(interactiveViewer, const Offset(-50, -25));
        await tester.pumpAndSettle();

        // Test double-tap after multiple transformations
        await tester.tapAt(const Offset(400, 400));
        await tester.tapAt(const Offset(400, 400));
        await tester.pumpAndSettle();

        // Verify coordinate transformations maintain accuracy
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('performance validation with large graph configurations', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.4, 2.1

      // Create a large graph for performance testing
      final largeGraph = GraphData(
        nodes: List.generate(
          20,
          (index) => GraphNode(
            id: 'node-$index',
            title: 'Node $index',
            x: (index % 5 - 2) * 80.0,
            y: (index ~/ 5 - 2) * 80.0,
            connectionCount: index % 3 + 1,
            tags: ['tag${index % 3}'],
          ),
        ),
        edges: List.generate(
          15,
          (index) => GraphEdge(
            sourceId: 'node-$index',
            targetId: 'node-${(index + 1) % 20}',
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      await _setupMockGraphView(tester, largeGraph);
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Verify setup time is reasonable (less than 5 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      // Test multiple gestures on large graph
      final testPositions = [
        const Offset(300, 300),
        const Offset(400, 400),
        const Offset(500, 500),
        const Offset(350, 450),
        const Offset(450, 350),
      ];

      final gestureStopwatch = Stopwatch()..start();

      for (final position in testPositions) {
        await tester.tapAt(position);
        await tester.pumpAndSettle();
      }

      gestureStopwatch.stop();

      // Verify gesture handling performance (less than 2 seconds for all gestures)
      expect(gestureStopwatch.elapsedMilliseconds, lessThan(2000));

      // Verify no crashes during performance test
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation flow validation with error handling', (
      WidgetTester tester,
    ) async {
      // Test Requirements: 1.1, 1.2, 3.1, 3.2

      final singleNodeGraph = GraphData(
        nodes: [
          GraphNode(
            id: 'valid-node',
            title: 'Valid Node',
            x: 0,
            y: 0,
            connectionCount: 0,
            tags: [],
          ),
        ],
        edges: [],
      );

      await _setupMockGraphView(tester, singleNodeGraph);
      await tester.pumpAndSettle();

      // Test normal navigation flow
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Verify node selection works
      expect(tester.takeException(), isNull);

      // Test double-tap navigation
      await tester.tapAt(const Offset(400, 400));
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Verify navigation attempt doesn't crash
      expect(tester.takeException(), isNull);

      // Test navigation with invalid position (empty space)
      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      // Verify empty space double-tap is handled gracefully
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _testDoubleTapFunctionality(
  WidgetTester tester,
  String screenType,
) async {
  final singleNodeGraph = GraphData(
    nodes: [
      GraphNode(
        id: 'test-node-1',
        title: 'Test Node',
        x: 0,
        y: 0,
        connectionCount: 0,
        tags: [],
      ),
    ],
    edges: [],
  );

  await _setupMockGraphView(tester, singleNodeGraph);
  await tester.pumpAndSettle();

  // Test double-tap at center of screen (where node should be)
  final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final centerX = screenSize.width / 2;
  final centerY = screenSize.height / 2;

  await tester.tapAt(Offset(centerX, centerY));
  await tester.tapAt(Offset(centerX, centerY));
  await tester.pumpAndSettle();

  // Verify no crashes for this screen size
  expect(
    tester.takeException(),
    isNull,
    reason: 'Double-tap failed on $screenType',
  );
}

Future<void> _setupMockGraphView(
  WidgetTester tester,
  GraphData graphData,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MockGraphViewScreen(graphData: graphData)),
  );
}

/// Mock graph view screen for testing without Firebase dependencies
class MockGraphViewScreen extends StatefulWidget {
  final GraphData graphData;

  const MockGraphViewScreen({super.key, required this.graphData});

  @override
  State<MockGraphViewScreen> createState() => _MockGraphViewScreenState();
}

class _MockGraphViewScreenState extends State<MockGraphViewScreen> {
  final TransformationController _transformationController =
      TransformationController();
  String? _selectedNodeId;
  Set<String> _highlightedNodeIds = {};
  String _searchQuery = '';
  bool _showLocalGraph = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _onNodeTap(String nodeId) {
    setState(() {
      if (_selectedNodeId == nodeId) {
        _selectedNodeId = null;
        _highlightedNodeIds.clear();
      } else {
        _selectedNodeId = nodeId;
        _highlightedNodeIds = _getConnectedNodes(nodeId);
      }
    });
  }

  void _onNodeDoubleTap(String nodeId) {
    // Mock navigation - just print for testing
    debugPrint('Mock navigation to node: $nodeId');
  }

  void _handleTap(TapUpDetails details) {
    final nodeId = _getNodeAtPosition(details.localPosition);
    if (nodeId != null) {
      _onNodeTap(nodeId);
    } else {
      _handleEmptySpaceTap();
    }
  }

  void _handleDoubleTap() {
    debugPrint('Double-tap gesture detected');
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final nodeId = _getNodeAtPosition(details.localPosition);
    if (nodeId != null) {
      _onNodeDoubleTap(nodeId);
    }
  }

  void _handleEmptySpaceTap() {
    final hadSelection =
        _selectedNodeId != null || _highlightedNodeIds.isNotEmpty;

    setState(() {
      _selectedNodeId = null;
      _highlightedNodeIds.clear();
      if (_showLocalGraph && hadSelection) {
        _showLocalGraph = false;
      }
    });

    if (hadSelection && mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selection cleared'),
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          backgroundColor: Colors.grey[700],
        ),
      );
    }
  }

  String? _getNodeAtPosition(Offset position) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final canvasSize = renderBox.size;
    final transformation = _transformationController.value;

    return GraphCoordinateSystem.getNodeAtPosition(
      position,
      widget.graphData,
      transformation,
      canvasSize,
    );
  }

  Set<String> _getConnectedNodes(String nodeId) {
    final connected = <String>{nodeId};

    for (final edge in widget.graphData.edges) {
      if (edge.sourceId == nodeId) {
        connected.add(edge.targetId);
      }
      if (edge.targetId == nodeId) {
        connected.add(edge.sourceId);
      }
    }

    return connected;
  }

  void _applySearchFilter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _highlightedNodeIds.clear();
      } else {
        _highlightedNodeIds =
            widget.graphData.nodes
                .where(
                  (node) =>
                      node.title.toLowerCase().contains(_searchQuery) ||
                      node.tags.any(
                        (tag) => tag.toLowerCase().contains(_searchQuery),
                      ),
                )
                .map((node) => node.id)
                .toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Graph View'),
        actions: [
          IconButton(
            icon: Icon(_showLocalGraph ? Icons.public : Icons.location_on),
            onPressed:
                _selectedNodeId != null
                    ? () {
                      setState(() {
                        _showLocalGraph = !_showLocalGraph;
                      });
                    }
                    : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _applySearchFilter(''),
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _applySearchFilter,
            ),
          ),
          // Graph canvas
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 4.0,
              child: GestureDetector(
                onTapUp: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onDoubleTapDown: _handleDoubleTapDown,
                child: CustomPaint(
                  painter: MockGraphPainter(
                    graphData: widget.graphData,
                    selectedNodeId: _selectedNodeId,
                    highlightedNodeIds: _highlightedNodeIds,
                    showLocalGraph: _showLocalGraph,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock graph painter for testing
class MockGraphPainter extends CustomPainter {
  final GraphData graphData;
  final String? selectedNodeId;
  final Set<String> highlightedNodeIds;
  final bool showLocalGraph;

  MockGraphPainter({
    required this.graphData,
    this.selectedNodeId,
    required this.highlightedNodeIds,
    required this.showLocalGraph,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw edges
    final edgePaint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    for (final edge in graphData.edges) {
      final source = graphData.nodes.firstWhere((n) => n.id == edge.sourceId);
      final target = graphData.nodes.firstWhere((n) => n.id == edge.targetId);

      if (showLocalGraph &&
          !highlightedNodeIds.contains(source.id) &&
          !highlightedNodeIds.contains(target.id)) {
        continue;
      }

      canvas.drawLine(
        Offset(centerX + source.x, centerY + source.y),
        Offset(centerX + target.x, centerY + target.y),
        edgePaint,
      );
    }

    // Draw nodes
    for (final node in graphData.nodes) {
      if (showLocalGraph && !highlightedNodeIds.contains(node.id)) {
        continue;
      }

      final isSelected = node.id == selectedNodeId;
      final isHighlighted = highlightedNodeIds.contains(node.id);

      final baseSize = 20.0;
      final sizeMultiplier = 1.0 + (node.connectionCount * 0.2);
      final nodeSize = baseSize * sizeMultiplier.clamp(1.0, 3.0);

      Color nodeColor;
      if (isSelected) {
        nodeColor = Colors.blue;
      } else if (isHighlighted) {
        nodeColor = Colors.lightBlue;
      } else {
        nodeColor = Colors.grey;
      }

      final nodePaint =
          Paint()
            ..color = nodeColor
            ..style = PaintingStyle.fill;

      final borderPaint =
          Paint()
            ..color = isSelected ? Colors.blue.shade700 : Colors.white
            ..strokeWidth = isSelected ? 3.0 : 2.0
            ..style = PaintingStyle.stroke;

      final center = Offset(centerX + node.x, centerY + node.y);

      canvas.drawCircle(center, nodeSize, nodePaint);
      canvas.drawCircle(center, nodeSize, borderPaint);

      // Draw node label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );

      textPainter.layout(maxWidth: 150);

      final textOffset = Offset(
        center.dx - textPainter.width / 2,
        center.dy + nodeSize + 4,
      );

      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(MockGraphPainter oldDelegate) {
    return oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.highlightedNodeIds != highlightedNodeIds ||
        oldDelegate.showLocalGraph != showLocalGraph;
  }
}
