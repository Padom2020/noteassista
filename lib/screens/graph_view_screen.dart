import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/link_management_service.dart';
import '../services/graph_navigation_service.dart';
import '../services/auth_service.dart';
import '../utils/performance_utils.dart';
import '../utils/graph_coordinate_system.dart';

/// Screen that displays an interactive graph visualization of note connections
class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({super.key});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen>
    with TickerProviderStateMixin, DebounceMixin {
  final LinkManagementService _linkService = LinkManagementService();
  final GraphNavigationService _navigationService = GraphNavigationService();
  final AuthService _authService = AuthService();
  final TransformationController _transformationController =
      TransformationController();

  GraphData? _graphData;
  bool _isLoading = true;
  String? _error;
  String? _selectedNodeId;
  String _searchQuery = '';
  bool _showLocalGraph = false;
  Set<String> _highlightedNodeIds = {};

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadGraph();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGraph() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final graphData = await _linkService.buildNoteGraph(user.uid);

      // Initialize node positions using force-directed layout
      _initializeNodePositions(graphData);

      // Run force simulation
      _runForceSimulation(graphData);

      setState(() {
        _graphData = graphData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Initialize node positions randomly within the viewport
  void _initializeNodePositions(GraphData graphData) {
    final random = math.Random();
    const double spread = 500.0;

    for (final node in graphData.nodes) {
      node.x = (random.nextDouble() - 0.5) * spread;
      node.y = (random.nextDouble() - 0.5) * spread;
      node.vx = 0;
      node.vy = 0;
    }
  }

  /// Run force-directed layout simulation
  void _runForceSimulation(GraphData graphData, {int iterations = 100}) {
    const double repulsionStrength = 5000.0;
    const double attractionStrength = 0.01;
    const double damping = 0.8;
    const double minDistance = 50.0;

    for (int i = 0; i < iterations; i++) {
      // Apply repulsion between all nodes
      for (int j = 0; j < graphData.nodes.length; j++) {
        for (int k = j + 1; k < graphData.nodes.length; k++) {
          final node1 = graphData.nodes[j];
          final node2 = graphData.nodes[k];

          final dx = node2.x - node1.x;
          final dy = node2.y - node1.y;
          final distance = math.sqrt(dx * dx + dy * dy);

          if (distance > 0 && distance < 500) {
            final force = repulsionStrength / (distance * distance);
            final fx = (dx / distance) * force;
            final fy = (dy / distance) * force;

            node1.vx -= fx;
            node1.vy -= fy;
            node2.vx += fx;
            node2.vy += fy;
          }
        }
      }

      // Apply attraction along edges
      for (final edge in graphData.edges) {
        final source = graphData.nodes.firstWhere((n) => n.id == edge.sourceId);
        final target = graphData.nodes.firstWhere((n) => n.id == edge.targetId);

        final dx = target.x - source.x;
        final dy = target.y - source.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance > minDistance) {
          final force = (distance - minDistance) * attractionStrength;
          final fx = (dx / distance) * force;
          final fy = (dy / distance) * force;

          source.vx += fx;
          source.vy += fy;
          target.vx -= fx;
          target.vy -= fy;
        }
      }

      // Update positions and apply damping
      for (final node in graphData.nodes) {
        node.x += node.vx;
        node.y += node.vy;
        node.vx *= damping;
        node.vy *= damping;
      }
    }
  }

  void _onNodeTap(String nodeId) {
    // Input validation
    if (!GraphCoordinateSystem.validateNodeId(nodeId, 'onNodeTap')) {
      debugPrint('GraphViewScreen._onNodeTap: Invalid node ID: $nodeId');
      return;
    }

    // Validate that the node exists in the graph data
    if (_graphData == null ||
        !_graphData!.nodes.any((node) => node.id == nodeId)) {
      debugPrint(
        'GraphViewScreen._onNodeTap: Node not found in graph data: $nodeId',
      );
      return;
    }

    try {
      setState(() {
        if (_selectedNodeId == nodeId) {
          _selectedNodeId = null;
          _highlightedNodeIds.clear();
        } else {
          _selectedNodeId = nodeId;
          _highlightedNodeIds = _getConnectedNodes(nodeId);
        }
      });
    } catch (e) {
      debugPrint('GraphViewScreen._onNodeTap: Error updating state: $e');
    }
  }

  void _onNodeDoubleTap(String nodeId) async {
    // Input validation
    if (!GraphCoordinateSystem.validateNodeId(nodeId, 'onNodeDoubleTap')) {
      debugPrint('GraphViewScreen._onNodeDoubleTap: Invalid node ID: $nodeId');
      return;
    }

    // Validate that the node exists in the graph data
    if (_graphData == null ||
        !_graphData!.nodes.any((node) => node.id == nodeId)) {
      debugPrint(
        'GraphViewScreen._onNodeDoubleTap: Node not found in graph data: $nodeId',
      );
      return;
    }

    // Validate context is still mounted
    if (!mounted) {
      debugPrint(
        'GraphViewScreen._onNodeDoubleTap: Widget not mounted, aborting navigation',
      );
      return;
    }

    try {
      // Use the navigation service for robust navigation handling
      final success = await _navigationService.navigateToNote(context, nodeId);

      // If navigation was successful, close the graph view
      if (success && mounted) {
        Navigator.pop(context, nodeId);
      }
    } catch (e) {
      debugPrint(
        'GraphViewScreen._onNodeDoubleTap: Error during navigation: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open note: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _handleTap(TapUpDetails details) {
    // Input validation
    if (!GraphCoordinateSystem.validateGestureInput(
      details.localPosition,
      'handleTap',
    )) {
      debugPrint('GraphViewScreen._handleTap: Invalid tap details');
      return;
    }

    try {
      final nodeId = _getNodeAtPosition(details.localPosition);
      if (nodeId != null) {
        _onNodeTap(nodeId);
      } else {
        // Handle empty space tap - clear selection and provide visual feedback
        _handleEmptySpaceTap(details.localPosition);
      }
    } catch (e) {
      debugPrint('GraphViewScreen._handleTap: Error handling tap: $e');
    }
  }

  void _handleDoubleTap() {
    // Double-tap handling will be done through onDoubleTapDown for position detection
    // This callback is required for proper gesture recognition
    debugPrint('GraphViewScreen._handleDoubleTap: Double-tap gesture detected');
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    // Input validation
    if (!GraphCoordinateSystem.validateGestureInput(
      details.localPosition,
      'handleDoubleTapDown',
    )) {
      debugPrint(
        'GraphViewScreen._handleDoubleTapDown: Invalid double-tap details',
      );
      return;
    }

    try {
      final nodeId = _getNodeAtPosition(details.localPosition);
      if (nodeId != null) {
        debugPrint(
          'GraphViewScreen._handleDoubleTapDown: Double-tap on node: $nodeId',
        );
        _onNodeDoubleTap(nodeId);
      } else {
        // Handle empty space double-tap - ensure it doesn't interfere with zoom/pan
        _handleEmptySpaceDoubleTap(details.localPosition);
      }
    } catch (e) {
      debugPrint(
        'GraphViewScreen._handleDoubleTapDown: Error handling double-tap: $e',
      );
    }
  }

  /// Handles taps on empty space (outside of node boundaries)
  void _handleEmptySpaceTap(Offset position) {
    // Input validation
    if (!GraphCoordinateSystem.validateGestureInput(
      position,
      'handleEmptySpaceTap',
    )) {
      debugPrint('GraphViewScreen._handleEmptySpaceTap: Invalid position');
      return;
    }

    try {
      // Clear selection and highlighted nodes
      final hadSelection =
          _selectedNodeId != null || _highlightedNodeIds.isNotEmpty;

      setState(() {
        _selectedNodeId = null;
        _highlightedNodeIds.clear();

        // If we were in local graph mode and had a selection, exit local mode
        if (_showLocalGraph && hadSelection) {
          _showLocalGraph = false;
        }
      });

      // Provide visual feedback if there was a selection to clear
      if (hadSelection) {
        debugPrint('GraphViewScreen._handleEmptySpaceTap: Cleared selection');

        // Optional: Show a brief visual indication that selection was cleared
        if (mounted) {
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
    } catch (e) {
      debugPrint(
        'GraphViewScreen._handleEmptySpaceTap: Error handling empty space tap: $e',
      );
    }
  }

  /// Handles double-taps on empty space (outside of node boundaries)
  void _handleEmptySpaceDoubleTap(Offset position) {
    // Input validation
    if (!GraphCoordinateSystem.validateGestureInput(
      position,
      'handleEmptySpaceDoubleTap',
    )) {
      debugPrint(
        'GraphViewScreen._handleEmptySpaceDoubleTap: Invalid position',
      );
      return;
    }

    try {
      debugPrint(
        'GraphViewScreen._handleEmptySpaceDoubleTap: Double-tap on empty space',
      );

      // For empty space double-taps, we don't want to interfere with zoom/pan gestures
      // The InteractiveViewer should handle double-tap-to-zoom functionality
      // We just ensure our selection state is cleared
      setState(() {
        _selectedNodeId = null;
        _highlightedNodeIds.clear();

        // Exit local graph mode if active
        if (_showLocalGraph) {
          _showLocalGraph = false;
        }
      });

      // Note: We don't show a snackbar for double-tap as it might interfere with zoom feedback
    } catch (e) {
      debugPrint(
        'GraphViewScreen._handleEmptySpaceDoubleTap: Error handling empty space double-tap: $e',
      );
    }
  }

  String? _getNodeAtPosition(Offset position) {
    // Input validation
    if (!GraphCoordinateSystem.validateGestureInput(
      position,
      'getNodeAtPosition',
    )) {
      debugPrint('GraphViewScreen._getNodeAtPosition: Invalid position input');
      return null;
    }

    // Validate graph data
    if (_graphData == null) {
      debugPrint('GraphViewScreen._getNodeAtPosition: No graph data available');
      return null;
    }

    if (_graphData!.nodes.isEmpty) {
      debugPrint('GraphViewScreen._getNodeAtPosition: No nodes in graph data');
      return null;
    }

    try {
      // Get the current render box to determine canvas size
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        debugPrint(
          'GraphViewScreen._getNodeAtPosition: Unable to get render box',
        );
        return null;
      }

      final canvasSize = renderBox.size;

      // Validate canvas size
      if (canvasSize.width <= 0 || canvasSize.height <= 0) {
        debugPrint(
          'GraphViewScreen._getNodeAtPosition: Invalid canvas size: $canvasSize',
        );
        return null;
      }

      // Get the transformation matrix from the InteractiveViewer
      final transformation = _transformationController.value;

      // Validate transformation controller
      if (!GraphCoordinateSystem.isValidTransformationMatrix(transformation)) {
        debugPrint(
          'GraphViewScreen._getNodeAtPosition: Invalid transformation matrix',
        );
        return null;
      }

      // Determine which nodes are visible (for local graph mode filtering)
      final visibleNodeIds = _showLocalGraph ? _highlightedNodeIds : null;

      // Validate visible node IDs if filtering is enabled
      if (_showLocalGraph &&
          (visibleNodeIds == null || visibleNodeIds.isEmpty)) {
        debugPrint(
          'GraphViewScreen._getNodeAtPosition: Local graph mode enabled but no visible nodes',
        );
        return null;
      }

      // Use the GraphCoordinateSystem utility to find the node at the position
      return GraphCoordinateSystem.getNodeAtPosition(
        position,
        _graphData!,
        transformation,
        canvasSize,
        visibleNodeIds: visibleNodeIds,
      );
    } catch (e) {
      debugPrint(
        'GraphViewScreen._getNodeAtPosition: Error finding node at position: $e',
      );
      return null;
    }
  }

  Set<String> _getConnectedNodes(String nodeId, {int degrees = 1}) {
    // Input validation
    if (!GraphCoordinateSystem.validateNodeId(nodeId, 'getConnectedNodes')) {
      debugPrint(
        'GraphViewScreen._getConnectedNodes: Invalid node ID: $nodeId',
      );
      return {};
    }

    if (degrees < 0) {
      debugPrint(
        'GraphViewScreen._getConnectedNodes: Invalid degrees: $degrees',
      );
      return {};
    }

    if (_graphData == null) {
      debugPrint('GraphViewScreen._getConnectedNodes: No graph data available');
      return {};
    }

    // Validate that the starting node exists
    if (!_graphData!.nodes.any((node) => node.id == nodeId)) {
      debugPrint(
        'GraphViewScreen._getConnectedNodes: Starting node not found: $nodeId',
      );
      return {};
    }

    try {
      final connected = <String>{nodeId};
      final toProcess = <String>[nodeId];
      final processed = <String>{};

      for (int d = 0; d < degrees; d++) {
        final currentLevel = List<String>.from(toProcess);
        toProcess.clear();

        for (final currentId in currentLevel) {
          if (processed.contains(currentId)) continue;
          processed.add(currentId);

          // Find outgoing edges
          for (final edge in _graphData!.edges) {
            // Validate edge data
            if (edge.sourceId.isEmpty || edge.targetId.isEmpty) {
              debugPrint(
                'GraphViewScreen._getConnectedNodes: Found edge with empty ID, skipping',
              );
              continue;
            }

            if (edge.sourceId == currentId &&
                !connected.contains(edge.targetId)) {
              connected.add(edge.targetId);
              toProcess.add(edge.targetId);
            }
            if (edge.targetId == currentId &&
                !connected.contains(edge.sourceId)) {
              connected.add(edge.sourceId);
              toProcess.add(edge.sourceId);
            }
          }
        }
      }

      return connected;
    } catch (e) {
      debugPrint(
        'GraphViewScreen._getConnectedNodes: Error finding connected nodes: $e',
      );
      return {};
    }
  }

  void _applySearchFilter(String query) {
    // Input validation
    if (query.length > 1000) {
      debugPrint(
        'GraphViewScreen._applySearchFilter: Query too long, truncating',
      );
      query = query.substring(0, 1000);
    }

    try {
      setState(() {
        _searchQuery = query.toLowerCase();
        if (_searchQuery.isEmpty) {
          _highlightedNodeIds.clear();
        } else {
          if (_graphData == null) {
            debugPrint(
              'GraphViewScreen._applySearchFilter: No graph data available',
            );
            _highlightedNodeIds.clear();
            return;
          }

          _highlightedNodeIds =
              _graphData!.nodes
                  .where((node) {
                    // Validate node data
                    if (node.id.isEmpty) {
                      debugPrint(
                        'GraphViewScreen._applySearchFilter: Found node with empty ID, skipping',
                      );
                      return false;
                    }

                    try {
                      return node.title.toLowerCase().contains(_searchQuery) ||
                          node.tags.any(
                            (tag) => tag.toLowerCase().contains(_searchQuery),
                          );
                    } catch (e) {
                      debugPrint(
                        'GraphViewScreen._applySearchFilter: Error filtering node ${node.id}: $e',
                      );
                      return false;
                    }
                  })
                  .map((node) => node.id)
                  .toSet();
        }
      });
    } catch (e) {
      debugPrint(
        'GraphViewScreen._applySearchFilter: Error applying search filter: $e',
      );
    }
  }

  void _toggleGraphMode() {
    try {
      setState(() {
        _showLocalGraph = !_showLocalGraph;
        if (_showLocalGraph && _selectedNodeId != null) {
          // Validate selected node ID before getting connections
          if (GraphCoordinateSystem.validateNodeId(
            _selectedNodeId!,
            'toggleGraphMode',
          )) {
            _highlightedNodeIds = _getConnectedNodes(
              _selectedNodeId!,
              degrees: 2,
            );
          } else {
            debugPrint(
              'GraphViewScreen._toggleGraphMode: Invalid selected node ID: $_selectedNodeId',
            );
            _highlightedNodeIds.clear();
            _selectedNodeId = null;
          }
        } else {
          _highlightedNodeIds.clear();
        }
      });
    } catch (e) {
      debugPrint(
        'GraphViewScreen._toggleGraphMode: Error toggling graph mode: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph View'),
        actions: [
          IconButton(
            icon: Icon(_showLocalGraph ? Icons.public : Icons.location_on),
            onPressed: _selectedNodeId != null ? _toggleGraphMode : null,
            tooltip: _showLocalGraph ? 'Show Full Graph' : 'Show Local Graph',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGraph,
            tooltip: 'Refresh',
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
          // Help banner
          if (!_isLoading && _graphData != null && _graphData!.nodes.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tap a node to highlight connections. Double-tap to open note. Pinch to zoom.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // Graph canvas
          Expanded(child: _buildGraphContent()),
        ],
      ),
    );
  }

  Widget _buildGraphContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadGraph, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_graphData == null || _graphData!.nodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notes to display'),
            SizedBox(height: 8),
            Text(
              'Create notes with [[links]] to see them here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 4.0,
      child: GestureDetector(
        onTapUp: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onDoubleTapDown: _handleDoubleTapDown,
        child: CustomPaint(
          painter: GraphPainter(
            graphData: _graphData!,
            selectedNodeId: _selectedNodeId,
            highlightedNodeIds: _highlightedNodeIds,
            showLocalGraph: _showLocalGraph,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Custom painter for rendering the graph
class GraphPainter extends CustomPainter {
  final GraphData graphData;
  final String? selectedNodeId;
  final Set<String> highlightedNodeIds;
  final bool showLocalGraph;

  GraphPainter({
    required this.graphData,
    this.selectedNodeId,
    required this.highlightedNodeIds,
    required this.showLocalGraph,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw edges first (so they appear behind nodes)
    _drawEdges(canvas, centerX, centerY);

    // Draw nodes
    _drawNodes(canvas, centerX, centerY);
  }

  void _drawEdges(Canvas canvas, double centerX, double centerY) {
    final edgePaint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    final highlightedEdgePaint =
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.6)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

    for (final edge in graphData.edges) {
      final source = graphData.nodes.firstWhere((n) => n.id == edge.sourceId);
      final target = graphData.nodes.firstWhere((n) => n.id == edge.targetId);

      // Skip if in local graph mode and nodes aren't highlighted
      if (showLocalGraph &&
          !highlightedNodeIds.contains(source.id) &&
          !highlightedNodeIds.contains(target.id)) {
        continue;
      }

      final isHighlighted =
          highlightedNodeIds.contains(source.id) &&
          highlightedNodeIds.contains(target.id);

      canvas.drawLine(
        Offset(centerX + source.x, centerY + source.y),
        Offset(centerX + target.x, centerY + target.y),
        isHighlighted ? highlightedEdgePaint : edgePaint,
      );
    }
  }

  void _drawNodes(Canvas canvas, double centerX, double centerY) {
    for (final node in graphData.nodes) {
      // Skip if in local graph mode and node isn't highlighted
      if (showLocalGraph && !highlightedNodeIds.contains(node.id)) {
        continue;
      }

      final isSelected = node.id == selectedNodeId;
      final isHighlighted = highlightedNodeIds.contains(node.id);

      // Calculate node size based on connection count
      final baseSize = 20.0;
      final sizeMultiplier = 1.0 + (node.connectionCount * 0.2);
      final nodeSize = baseSize * sizeMultiplier.clamp(1.0, 3.0);

      // Determine node color
      Color nodeColor;
      if (isSelected) {
        nodeColor = Colors.blue;
      } else if (isHighlighted) {
        nodeColor = Colors.lightBlue;
      } else {
        // Color by tag (use first tag if available)
        nodeColor = _getColorForTag(
          node.tags.isNotEmpty ? node.tags.first : '',
        );
      }

      // Draw node circle
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
      _drawNodeLabel(canvas, node, center, nodeSize);
    }
  }

  void _drawNodeLabel(
    Canvas canvas,
    GraphNode node,
    Offset center,
    double nodeSize,
  ) {
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

    // Draw background for text
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy + nodeSize + 4,
    );

    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        textOffset.dx - 4,
        textOffset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );

    final backgroundPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;

    canvas.drawRRect(backgroundRect, backgroundPaint);

    textPainter.paint(canvas, textOffset);
  }

  Color _getColorForTag(String tag) {
    if (tag.isEmpty) return Colors.grey;

    // Generate a consistent color based on tag hash
    final hash = tag.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) {
    return oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.highlightedNodeIds != highlightedNodeIds ||
        oldDelegate.showLocalGraph != showLocalGraph;
  }
}
