import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;
import '../services/link_management_service.dart';

/// Utility class for handling coordinate transformations in the graph view
/// Provides accurate coordinate conversions between screen space and graph space
class GraphCoordinateSystem {
  /// Converts screen coordinates to graph coordinates using the transformation matrix
  ///
  /// [screenPosition] - The position in screen coordinates (from gesture events)
  /// [transformation] - The current transformation matrix from InteractiveViewer
  /// [canvasSize] - The size of the canvas/viewport
  ///
  /// Returns the position in graph coordinate space
  static Offset screenToGraph(
    Offset screenPosition,
    Matrix4 transformation,
    Size canvasSize,
  ) {
    // Input validation
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      debugPrint(
        'GraphCoordinateSystem.screenToGraph: Invalid canvas size: $canvasSize',
      );
      return Offset.zero;
    }

    // Validate screen position
    if (!isValidPosition(screenPosition)) {
      debugPrint(
        'GraphCoordinateSystem.screenToGraph: Invalid screen position: $screenPosition',
      );
      return Offset.zero;
    }

    // Validate transformation matrix
    if (!isValidTransformationMatrix(transformation)) {
      debugPrint(
        'GraphCoordinateSystem.screenToGraph: Invalid transformation matrix',
      );
      return screenPosition;
    }

    try {
      // Create inverse transformation matrix to convert from screen to graph space
      final Matrix4 inverse = Matrix4.inverted(transformation);

      // Transform the screen position to graph space
      final Vector3 transformed = inverse.transform3(
        Vector3(screenPosition.dx, screenPosition.dy, 0),
      );

      final result = Offset(transformed.x, transformed.y);

      // Validate the result
      if (!isValidPosition(result)) {
        debugPrint(
          'GraphCoordinateSystem.screenToGraph: Invalid transformation result: $result',
        );
        return screenPosition;
      }

      return result;
    } catch (e) {
      // If transformation fails (e.g., singular matrix), return original position
      debugPrint(
        'GraphCoordinateSystem.screenToGraph: Transformation failed: $e',
      );
      return screenPosition;
    }
  }

  /// Converts graph coordinates to screen coordinates using the transformation matrix
  ///
  /// [graphPosition] - The position in graph coordinates
  /// [transformation] - The current transformation matrix from InteractiveViewer
  /// [canvasSize] - The size of the canvas/viewport
  ///
  /// Returns the position in screen coordinate space
  static Offset graphToScreen(
    Offset graphPosition,
    Matrix4 transformation,
    Size canvasSize,
  ) {
    // Input validation
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      debugPrint(
        'GraphCoordinateSystem.graphToScreen: Invalid canvas size: $canvasSize',
      );
      return Offset.zero;
    }

    // Validate graph position
    if (!isValidPosition(graphPosition)) {
      debugPrint(
        'GraphCoordinateSystem.graphToScreen: Invalid graph position: $graphPosition',
      );
      return Offset.zero;
    }

    // Validate transformation matrix
    if (!isValidTransformationMatrix(transformation)) {
      debugPrint(
        'GraphCoordinateSystem.graphToScreen: Invalid transformation matrix',
      );
      return graphPosition;
    }

    try {
      // Transform the graph position to screen space
      final Vector3 transformed = transformation.transform3(
        Vector3(graphPosition.dx, graphPosition.dy, 0),
      );

      final result = Offset(transformed.x, transformed.y);

      // Validate the result
      if (!isValidPosition(result)) {
        debugPrint(
          'GraphCoordinateSystem.graphToScreen: Invalid transformation result: $result',
        );
        return graphPosition;
      }

      return result;
    } catch (e) {
      // If transformation fails, return original position
      debugPrint(
        'GraphCoordinateSystem.graphToScreen: Transformation failed: $e',
      );
      return graphPosition;
    }
  }

  /// Checks if a point in graph coordinates is within a node's boundaries
  ///
  /// [graphPosition] - The position to check in graph coordinates
  /// [node] - The graph node to check against
  /// [canvasSize] - The size of the canvas (used for center calculations)
  /// [scaleFactor] - Optional scale factor for dynamic sizing adjustments
  ///
  /// Returns true if the point is within the node's boundaries
  static bool isPointInNode(
    Offset graphPosition,
    GraphNode node,
    Size canvasSize, {
    double scaleFactor = 1.0,
  }) {
    // Input validation
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      debugPrint(
        'GraphCoordinateSystem.isPointInNode: Invalid canvas size: $canvasSize',
      );
      return false;
    }

    // Validate graph position
    if (!isValidPosition(graphPosition)) {
      debugPrint(
        'GraphCoordinateSystem.isPointInNode: Invalid graph position: $graphPosition',
      );
      return false;
    }

    // Validate node coordinates
    if (!node.x.isFinite || !node.y.isFinite) {
      debugPrint(
        'GraphCoordinateSystem.isPointInNode: Invalid node position: (${node.x}, ${node.y})',
      );
      return false;
    }

    // Validate scale factor
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      debugPrint(
        'GraphCoordinateSystem.isPointInNode: Invalid scale factor: $scaleFactor, using default',
      );
      scaleFactor = 1.0;
    }

    // Calculate the center of the canvas
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    // The node's position is already in graph coordinates relative to the center
    // So the node's actual position in graph space is (centerX + node.x, centerY + node.y)
    final nodeCenter = Offset(centerX + node.x, centerY + node.y);

    // Calculate the distance between the point and the node center
    final distance = (graphPosition - nodeCenter).distance;

    // Calculate the node's radius with dynamic sizing
    final nodeRadius = calculateDynamicNodeRadius(node, scaleFactor);

    // Check if the point is within the node's radius
    return distance <= nodeRadius;
  }

  /// Calculates the radius of a node based on its connection count
  ///
  /// [node] - The graph node to calculate radius for
  ///
  /// Returns the radius of the node in pixels
  static double calculateNodeRadius(GraphNode node) {
    // Input validation
    if (node.connectionCount < 0) {
      debugPrint(
        'GraphCoordinateSystem.calculateNodeRadius: Invalid connection count: ${node.connectionCount}',
      );
      return 20.0; // Return base size for invalid input
    }

    const double baseSize = 20.0;
    const double maxSizeMultiplier = 3.0;
    const double connectionMultiplier = 0.2;

    // Calculate size multiplier based on connection count
    final sizeMultiplier = 1.0 + (node.connectionCount * connectionMultiplier);

    // Clamp the multiplier to prevent nodes from becoming too large
    final clampedMultiplier = sizeMultiplier.clamp(1.0, maxSizeMultiplier);

    return baseSize * clampedMultiplier;
  }

  /// Calculates the radius of a node with dynamic scaling
  ///
  /// [node] - The graph node to calculate radius for
  /// [scaleFactor] - Scale factor to apply to the radius
  ///
  /// Returns the scaled radius of the node in pixels
  static double calculateDynamicNodeRadius(GraphNode node, double scaleFactor) {
    // Input validation
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      debugPrint(
        'GraphCoordinateSystem.calculateDynamicNodeRadius: Invalid scale factor: $scaleFactor',
      );
      scaleFactor = 1.0;
    }

    final baseRadius = calculateNodeRadius(node);
    final scaledRadius = baseRadius * scaleFactor;

    // Ensure the scaled radius is within reasonable bounds
    const double minRadius = 5.0;
    const double maxRadius = 100.0;

    return scaledRadius.clamp(minRadius, maxRadius);
  }

  /// Finds the node at a given screen position
  ///
  /// [screenPosition] - The position in screen coordinates
  /// [graphData] - The graph data containing all nodes
  /// [transformation] - The current transformation matrix
  /// [canvasSize] - The size of the canvas
  /// [visibleNodeIds] - Optional set of node IDs that should be considered (for filtering)
  ///
  /// Returns the ID of the node at the position, or null if no node is found
  static String? getNodeAtPosition(
    Offset screenPosition,
    GraphData graphData,
    Matrix4 transformation,
    Size canvasSize, {
    Set<String>? visibleNodeIds,
  }) {
    // Input validation
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      debugPrint(
        'GraphCoordinateSystem.getNodeAtPosition: Invalid canvas size: $canvasSize',
      );
      return null;
    }

    // Validate screen position
    if (!isValidPosition(screenPosition)) {
      debugPrint(
        'GraphCoordinateSystem.getNodeAtPosition: Invalid screen position: $screenPosition',
      );
      return null;
    }

    // Validate graph data
    if (graphData.nodes.isEmpty) {
      debugPrint(
        'GraphCoordinateSystem.getNodeAtPosition: No nodes in graph data',
      );
      return null;
    }

    // Validate transformation matrix
    if (!isValidTransformationMatrix(transformation)) {
      debugPrint(
        'GraphCoordinateSystem.getNodeAtPosition: Invalid transformation matrix',
      );
      return null;
    }

    // Convert screen position to graph coordinates
    final graphPosition = screenToGraph(
      screenPosition,
      transformation,
      canvasSize,
    );

    // If conversion failed, return null
    if (graphPosition == Offset.zero && screenPosition != Offset.zero) {
      debugPrint(
        'GraphCoordinateSystem.getNodeAtPosition: Failed to convert screen to graph coordinates',
      );
      return null;
    }

    // Check each node to see if the position is within its bounds
    for (final node in graphData.nodes) {
      // Validate node ID
      if (node.id.isEmpty) {
        debugPrint(
          'GraphCoordinateSystem.getNodeAtPosition: Found node with empty ID, skipping',
        );
        continue;
      }

      // Skip nodes that are not in the visible set (if filtering is enabled)
      if (visibleNodeIds != null && !visibleNodeIds.contains(node.id)) {
        continue;
      }

      // Check if the point is within this node
      if (isPointInNode(graphPosition, node, canvasSize)) {
        return node.id;
      }
    }

    return null;
  }

  /// Validates that coordinates are within reasonable bounds
  ///
  /// [position] - The position to validate
  /// [bounds] - The bounds to check against (optional)
  ///
  /// Returns true if the position is within valid bounds
  static bool isValidPosition(Offset position, [Rect? bounds]) {
    // Check for NaN or infinite values
    if (!position.dx.isFinite || !position.dy.isFinite) {
      return false;
    }

    // If bounds are provided, check if position is within them
    if (bounds != null) {
      return bounds.contains(position);
    }

    // Default bounds check - reasonable coordinate range
    const double maxCoordinate = 1000000.0; // 1 million pixels
    return position.dx.abs() <= maxCoordinate &&
        position.dy.abs() <= maxCoordinate;
  }

  /// Clamps a position to be within specified bounds
  ///
  /// [position] - The position to clamp
  /// [bounds] - The bounds to clamp to
  ///
  /// Returns the clamped position
  static Offset clampPosition(Offset position, Rect bounds) {
    return Offset(
      position.dx.clamp(bounds.left, bounds.right),
      position.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  /// Gets the current scale factor from the transformation matrix
  ///
  /// [transformation] - The transformation matrix
  ///
  /// Returns the current scale factor
  static double getScaleFactor(Matrix4 transformation) {
    // Validate transformation matrix
    if (!isValidTransformationMatrix(transformation)) {
      debugPrint(
        'GraphCoordinateSystem.getScaleFactor: Invalid transformation matrix',
      );
      return 1.0;
    }

    try {
      // Extract scale from the transformation matrix
      // The scale is the length of the first column vector (ignoring translation)
      final scaleX = math.sqrt(
        transformation.entry(0, 0) * transformation.entry(0, 0) +
            transformation.entry(1, 0) * transformation.entry(1, 0) +
            transformation.entry(2, 0) * transformation.entry(2, 0),
      );

      // Validate the result
      if (!scaleX.isFinite || scaleX <= 0) {
        debugPrint(
          'GraphCoordinateSystem.getScaleFactor: Invalid scale factor: $scaleX',
        );
        return 1.0;
      }

      return scaleX;
    } catch (e) {
      debugPrint(
        'GraphCoordinateSystem.getScaleFactor: Error extracting scale: $e',
      );
      return 1.0;
    }
  }

  /// Gets the current translation offset from the transformation matrix
  ///
  /// [transformation] - The transformation matrix
  ///
  /// Returns the current translation offset
  static Offset getTranslationOffset(Matrix4 transformation) {
    // Validate transformation matrix
    if (!isValidTransformationMatrix(transformation)) {
      debugPrint(
        'GraphCoordinateSystem.getTranslationOffset: Invalid transformation matrix',
      );
      return Offset.zero;
    }

    try {
      final offset = Offset(
        transformation.entry(0, 3),
        transformation.entry(1, 3),
      );

      // Validate the result
      if (!isValidPosition(offset)) {
        debugPrint(
          'GraphCoordinateSystem.getTranslationOffset: Invalid translation offset: $offset',
        );
        return Offset.zero;
      }

      return offset;
    } catch (e) {
      debugPrint(
        'GraphCoordinateSystem.getTranslationOffset: Error extracting translation: $e',
      );
      return Offset.zero;
    }
  }

  /// Validates that a transformation matrix is valid for coordinate transformations
  ///
  /// [transformation] - The transformation matrix to validate
  ///
  /// Returns true if the matrix is valid
  static bool isValidTransformationMatrix(Matrix4 transformation) {
    try {
      // Check for null or invalid matrix entries
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          final entry = transformation.entry(i, j);
          if (!entry.isFinite) {
            return false;
          }
        }
      }

      // Check if the matrix is invertible (determinant != 0)
      final determinant = transformation.determinant();
      if (!determinant.isFinite || determinant.abs() < 1e-10) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint(
        'GraphCoordinateSystem.isValidTransformationMatrix: Error validating matrix: $e',
      );
      return false;
    }
  }

  /// Validates input parameters for gesture callbacks
  ///
  /// [position] - The position to validate
  /// [context] - Optional context for additional validation
  ///
  /// Returns true if parameters are valid for gesture processing
  static bool validateGestureInput(Offset? position, [String? context]) {
    if (position == null) {
      debugPrint(
        'GraphCoordinateSystem.validateGestureInput: Null position${context != null ? ' in $context' : ''}',
      );
      return false;
    }

    if (!isValidPosition(position)) {
      debugPrint(
        'GraphCoordinateSystem.validateGestureInput: Invalid position $position${context != null ? ' in $context' : ''}',
      );
      return false;
    }

    return true;
  }

  /// Validates node data for gesture processing
  ///
  /// [nodeId] - The node ID to validate
  /// [context] - Optional context for additional validation
  ///
  /// Returns true if the node ID is valid
  static bool validateNodeId(String? nodeId, [String? context]) {
    if (nodeId == null || nodeId.isEmpty || nodeId.trim().isEmpty) {
      debugPrint(
        'GraphCoordinateSystem.validateNodeId: Invalid node ID${context != null ? ' in $context' : ''}',
      );
      return false;
    }

    return true;
  }
}
