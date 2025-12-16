# Design Document

## Overview

This design addresses the functional issues in the graph view's gesture handling system, specifically fixing the double-tap gesture to open notes. The current implementation has problems with gesture detection due to incorrect event handling and coordinate transformation issues.

## Architecture

The graph view system consists of several key components:

1. **GraphViewScreen**: The main screen widget that manages state and user interactions
2. **GestureDetector**: Handles touch events and gesture recognition
3. **InteractiveViewer**: Provides zoom and pan capabilities with transformation matrix
4. **GraphPainter**: Custom painter that renders nodes and edges
5. **Coordinate Transformation System**: Converts screen coordinates to graph coordinates

The current architecture has a flaw in the gesture handling chain where the GestureDetector is not properly configured for double-tap detection, and coordinate transformations are not correctly applied in all scenarios.

## Components and Interfaces

### Enhanced Gesture Handler

```dart
class GraphGestureHandler {
  final TransformationController transformationController;
  final Function(String nodeId) onNodeTap;
  final Function(String nodeId) onNodeDoubleTap;
  
  GraphGestureHandler({
    required this.transformationController,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
  });
  
  String? getNodeAtPosition(Offset position, GraphData graphData, Size canvasSize);
  Offset transformScreenToGraph(Offset screenPosition, Size canvasSize);
}
```

### Improved Coordinate System

```dart
class GraphCoordinateSystem {
  static Offset screenToGraph(
    Offset screenPosition, 
    Matrix4 transformation, 
    Size canvasSize
  );
  
  static bool isPointInNode(
    Offset graphPosition, 
    GraphNode node, 
    Size canvasSize
  );
  
  static double calculateNodeRadius(GraphNode node);
}
```

### Navigation Integration

```dart
class GraphNavigationService {
  static Future<void> openNote(String noteId, BuildContext context);
  static bool validateNoteAccess(String noteId, User? user);
}
```

## Data Models

The existing GraphData, GraphNode, and GraphEdge models are sufficient for this implementation. No changes to the data models are required.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, the following correctness properties have been identified:

### Property 1: Double-tap navigation consistency
*For any* valid node in the graph view, when a user performs a double-tap gesture within the node's boundaries, the system should navigate to the corresponding note and close the graph view
**Validates: Requirements 1.1, 1.2**

### Property 2: Gesture detection accuracy
*For any* node configuration and screen position, the system should accurately detect gestures only within the actual node boundaries
**Validates: Requirements 1.3**

### Property 3: Gesture isolation
*For any* cluster of nodes, a double-tap gesture should only affect the specific node that was tapped, regardless of proximity to other nodes
**Validates: Requirements 1.4**

### Property 4: Coordinate transformation correctness
*For any* zoom level and pan position, coordinate transformations should maintain accuracy so that gestures work correctly at all scales
**Validates: Requirements 1.5, 4.2**

### Property 5: Single vs double-tap distinction
*For any* node, the system should correctly distinguish between single-tap (highlight) and double-tap (navigate) gestures without false positives
**Validates: Requirements 2.1, 2.2**

### Property 6: Empty space gesture handling
*For any* touch position outside of node boundaries, the system should clear selections without triggering node-specific actions
**Validates: Requirements 2.5**

### Property 7: Input validation robustness
*For any* gesture callback invocation, the system should validate input parameters and handle invalid inputs gracefully
**Validates: Requirements 4.3**

## Error Handling

The system will implement comprehensive error handling:

1. **Invalid Node Detection**: Validate node existence before navigation attempts
2. **Authentication Checks**: Verify user authentication before note access
3. **Network Resilience**: Handle offline scenarios gracefully
4. **Gesture Conflicts**: Resolve conflicts between zoom/pan and tap gestures
5. **Coordinate Edge Cases**: Handle extreme zoom levels and coordinate boundaries

## Testing Strategy

### Unit Testing Approach

Unit tests will focus on:
- Coordinate transformation accuracy
- Node hit detection logic
- Gesture event parsing
- Error handling scenarios
- Navigation service integration

### Property-Based Testing Approach

Property-based tests will use the **test** package with custom generators to verify:
- Coordinate transformation properties across various zoom levels and positions
- Gesture detection accuracy with randomly generated node positions and sizes
- Error handling robustness with invalid inputs
- Navigation consistency across different graph states

The property-based testing will use Dart's built-in test framework with custom generators for:
- Random graph configurations
- Various screen sizes and transformation matrices
- Different gesture patterns and timing
- Edge case scenarios (empty graphs, single nodes, overlapping nodes)

Each property-based test will run a minimum of 100 iterations to ensure statistical confidence in the results. Tests will be tagged with comments explicitly referencing the correctness properties:

- **Feature: graph-view-fixes, Property 1: Double-tap gesture accuracy**
- **Feature: graph-view-fixes, Property 2: Coordinate transformation consistency**
- **Feature: graph-view-fixes, Property 3: Gesture isolation**
- **Feature: graph-view-fixes, Property 4: Single vs double-tap distinction**
- **Feature: graph-view-fixes, Property 5: Error handling robustness**