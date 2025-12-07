import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/link_management_service.dart';

/// Screen that displays an interactive graph visualization of note connections
class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({super.key});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen>
    with TickerProviderStateMixin {
  final LinkManagementService _linkService = LinkManagementService();
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
      final user = FirebaseAuth.instance.currentUser;
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

  void _onNodeDoubleTap(String nodeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Find the note and navigate to it
    final node = _graphData?.nodes.firstWhere((n) => n.id == nodeId);
    if (node != null && mounted) {
      Navigator.pop(context, nodeId);
    }
  }

  Set<String> _getConnectedNodes(String nodeId, {int degrees = 1}) {
    if (_graphData == null) return {};

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
  }

  void _applySearchFilter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _highlightedNodeIds.clear();
      } else {
        _highlightedNodeIds =
            _graphData?.nodes
                .where(
                  (node) =>
                      node.title.toLowerCase().contains(_searchQuery) ||
                      node.tags.any(
                        (tag) => tag.toLowerCase().contains(_searchQuery),
                      ),
                )
                .map((node) => node.id)
                .toSet() ??
            {};
      }
    });
  }

  void _toggleGraphMode() {
    setState(() {
      _showLocalGraph = !_showLocalGraph;
      if (_showLocalGraph && _selectedNodeId != null) {
        _highlightedNodeIds = _getConnectedNodes(_selectedNodeId!, degrees: 2);
      } else {
        _highlightedNodeIds.clear();
      }
    });
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
      child: CustomPaint(
        painter: GraphPainter(
          graphData: _graphData!,
          selectedNodeId: _selectedNodeId,
          highlightedNodeIds: _highlightedNodeIds,
          showLocalGraph: _showLocalGraph,
          onNodeTap: _onNodeTap,
          onNodeDoubleTap: _onNodeDoubleTap,
        ),
        size: Size.infinite,
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
  final Function(String) onNodeTap;
  final Function(String) onNodeDoubleTap;

  GraphPainter({
    required this.graphData,
    this.selectedNodeId,
    required this.highlightedNodeIds,
    required this.showLocalGraph,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
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
          ..color = Colors.grey.withOpacity(0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    final highlightedEdgePaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.6)
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
          ..color = Colors.white.withOpacity(0.9)
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
