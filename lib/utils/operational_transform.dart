import '../services/collaboration_service.dart';

/// Operational Transform (OT) utility class for resolving concurrent edits
/// in collaborative editing scenarios.
///
/// This implementation follows the OT algorithm to transform operations
/// so that they can be applied in any order while maintaining consistency.
class OperationalTransform {
  /// Transform two concurrent operations against each other
  ///
  /// Given two operations that were created concurrently (at the same document state),
  /// this method transforms them so they can be applied sequentially while
  /// maintaining the intended effect of both operations.
  ///
  /// Returns a pair of transformed operations: (op1', op2')
  /// where op1' can be applied after op2, and op2' can be applied after op1
  static TransformResult transform(Operation op1, Operation op2) {
    // Handle insert vs insert
    if (op1.type == OperationType.insert && op2.type == OperationType.insert) {
      return _transformInsertInsert(op1, op2);
    }

    // Handle insert vs delete
    if (op1.type == OperationType.insert && op2.type == OperationType.delete) {
      return _transformInsertDelete(op1, op2);
    }

    // Handle delete vs insert
    if (op1.type == OperationType.delete && op2.type == OperationType.insert) {
      final result = _transformInsertDelete(op2, op1);
      return TransformResult(result.op2Prime, result.op1Prime);
    }

    // Handle delete vs delete
    if (op1.type == OperationType.delete && op2.type == OperationType.delete) {
      return _transformDeleteDelete(op1, op2);
    }

    // Handle retain operations (no transformation needed)
    return TransformResult(op1, op2);
  }

  /// Transform two concurrent insert operations
  static TransformResult _transformInsertInsert(Operation op1, Operation op2) {
    if (op1.position < op2.position) {
      // op1 is before op2, so op2's position needs to shift right
      return TransformResult(
        op1,
        Operation(
          type: op2.type,
          position: op2.position + (op1.text?.length ?? 0),
          text: op2.text,
          userId: op2.userId,
          timestamp: op2.timestamp,
        ),
      );
    } else if (op1.position > op2.position) {
      // op2 is before op1, so op1's position needs to shift right
      return TransformResult(
        Operation(
          type: op1.type,
          position: op1.position + (op2.text?.length ?? 0),
          text: op1.text,
          userId: op1.userId,
          timestamp: op1.timestamp,
        ),
        op2,
      );
    } else {
      // Same position - use timestamp or userId as tiebreaker
      if (op1.timestamp.isBefore(op2.timestamp) ||
          (op1.timestamp == op2.timestamp &&
              op1.userId.compareTo(op2.userId) < 0)) {
        // op1 wins, op2 shifts right
        return TransformResult(
          op1,
          Operation(
            type: op2.type,
            position: op2.position + (op1.text?.length ?? 0),
            text: op2.text,
            userId: op2.userId,
            timestamp: op2.timestamp,
          ),
        );
      } else {
        // op2 wins, op1 shifts right
        return TransformResult(
          Operation(
            type: op1.type,
            position: op1.position + (op2.text?.length ?? 0),
            text: op1.text,
            userId: op1.userId,
            timestamp: op1.timestamp,
          ),
          op2,
        );
      }
    }
  }

  /// Transform an insert operation against a delete operation
  static TransformResult _transformInsertDelete(
    Operation insert,
    Operation delete,
  ) {
    final deleteEnd = delete.position + (delete.length ?? 0);

    if (insert.position <= delete.position) {
      // Insert is before the delete range, delete position shifts right
      return TransformResult(
        insert,
        Operation(
          type: delete.type,
          position: delete.position + (insert.text?.length ?? 0),
          length: delete.length,
          userId: delete.userId,
          timestamp: delete.timestamp,
        ),
      );
    } else if (insert.position >= deleteEnd) {
      // Insert is after the delete range, insert position shifts left
      return TransformResult(
        Operation(
          type: insert.type,
          position: insert.position - (delete.length ?? 0),
          text: insert.text,
          userId: insert.userId,
          timestamp: insert.timestamp,
        ),
        delete,
      );
    } else {
      // Insert is within the delete range, insert at delete start
      return TransformResult(
        Operation(
          type: insert.type,
          position: delete.position,
          text: insert.text,
          userId: insert.userId,
          timestamp: insert.timestamp,
        ),
        Operation(
          type: delete.type,
          position: delete.position + (insert.text?.length ?? 0),
          length: delete.length,
          userId: delete.userId,
          timestamp: delete.timestamp,
        ),
      );
    }
  }

  /// Transform two concurrent delete operations
  static TransformResult _transformDeleteDelete(Operation op1, Operation op2) {
    final op1End = op1.position + (op1.length ?? 0);
    final op2End = op2.position + (op2.length ?? 0);

    // No overlap - deletes are independent
    if (op1End <= op2.position) {
      // op1 is completely before op2
      return TransformResult(
        op1,
        Operation(
          type: op2.type,
          position: op2.position - (op1.length ?? 0),
          length: op2.length,
          userId: op2.userId,
          timestamp: op2.timestamp,
        ),
      );
    } else if (op2End <= op1.position) {
      // op2 is completely before op1
      return TransformResult(
        Operation(
          type: op1.type,
          position: op1.position - (op2.length ?? 0),
          length: op1.length,
          userId: op1.userId,
          timestamp: op1.timestamp,
        ),
        op2,
      );
    }

    // Overlapping deletes - need to adjust both
    // Calculate the overlap
    final overlapStart =
        op1.position > op2.position ? op1.position : op2.position;
    final overlapEnd = op1End < op2End ? op1End : op2End;
    final overlapLength = overlapEnd - overlapStart;

    Operation op1Prime;
    Operation op2Prime;

    if (op1.position < op2.position) {
      // op1 starts first
      if (op1End <= op2End) {
        // op1 is contained within or ends before op2
        op1Prime = op1;
        op2Prime = Operation(
          type: op2.type,
          position: op1.position,
          length: (op2.length ?? 0) - overlapLength,
          userId: op2.userId,
          timestamp: op2.timestamp,
        );
      } else {
        // op1 extends beyond op2
        op1Prime = Operation(
          type: op1.type,
          position: op1.position,
          length: (op1.length ?? 0) - overlapLength,
          userId: op1.userId,
          timestamp: op1.timestamp,
        );
        op2Prime = Operation(
          type: op2.type,
          position: op1.position,
          length: (op2.length ?? 0) - overlapLength,
          userId: op2.userId,
          timestamp: op2.timestamp,
        );
      }
    } else {
      // op2 starts first or at same position
      if (op2End <= op1End) {
        // op2 is contained within or ends before op1
        op1Prime = Operation(
          type: op1.type,
          position: op2.position,
          length: (op1.length ?? 0) - overlapLength,
          userId: op1.userId,
          timestamp: op1.timestamp,
        );
        op2Prime = op2;
      } else {
        // op2 extends beyond op1
        op1Prime = Operation(
          type: op1.type,
          position: op2.position,
          length: (op1.length ?? 0) - overlapLength,
          userId: op1.userId,
          timestamp: op1.timestamp,
        );
        op2Prime = Operation(
          type: op2.type,
          position: op2.position,
          length: (op2.length ?? 0) - overlapLength,
          userId: op2.userId,
          timestamp: op2.timestamp,
        );
      }
    }

    return TransformResult(op1Prime, op2Prime);
  }

  /// Compose two sequential operations into a single operation
  ///
  /// This combines two operations that are applied one after another
  /// into a single equivalent operation.
  static Operation? compose(Operation op1, Operation op2) {
    // Insert followed by insert at adjacent positions
    if (op1.type == OperationType.insert &&
        op2.type == OperationType.insert &&
        op1.position + (op1.text?.length ?? 0) == op2.position) {
      return Operation(
        type: OperationType.insert,
        position: op1.position,
        text: (op1.text ?? '') + (op2.text ?? ''),
        userId: op1.userId,
        timestamp: op1.timestamp,
      );
    }

    // Delete followed by delete at same position
    if (op1.type == OperationType.delete &&
        op2.type == OperationType.delete &&
        op1.position == op2.position) {
      return Operation(
        type: OperationType.delete,
        position: op1.position,
        length: (op1.length ?? 0) + (op2.length ?? 0),
        userId: op1.userId,
        timestamp: op1.timestamp,
      );
    }

    // Insert followed by delete at same position (they cancel out)
    if (op1.type == OperationType.insert &&
        op2.type == OperationType.delete &&
        op1.position == op2.position &&
        op1.text?.length == op2.length) {
      return null; // Operations cancel out
    }

    // Cannot compose these operations
    return null;
  }

  /// Invert an operation for undo functionality
  ///
  /// Returns the inverse operation that undoes the effect of the given operation.
  static Operation invert(Operation op, String originalText) {
    switch (op.type) {
      case OperationType.insert:
        // Inverse of insert is delete
        return Operation(
          type: OperationType.delete,
          position: op.position,
          length: op.text?.length ?? 0,
          userId: op.userId,
          timestamp: op.timestamp,
        );

      case OperationType.delete:
        // Inverse of delete is insert (need the deleted text)
        final deletedText = originalText.substring(
          op.position,
          op.position + (op.length ?? 0),
        );
        return Operation(
          type: OperationType.insert,
          position: op.position,
          text: deletedText,
          userId: op.userId,
          timestamp: op.timestamp,
        );

      case OperationType.retain:
        // Retain is its own inverse
        return op;
    }
  }

  /// Apply a list of operations to text
  ///
  /// Applies operations in sequence, returning the final text.
  static String applyOperations(String text, List<Operation> operations) {
    String result = text;

    for (final op in operations) {
      result = applyOperation(result, op);
    }

    return result;
  }

  /// Apply a single operation to text
  static String applyOperation(String text, Operation op) {
    switch (op.type) {
      case OperationType.insert:
        if (op.text != null && op.position >= 0 && op.position <= text.length) {
          return text.substring(0, op.position) +
              op.text! +
              text.substring(op.position);
        }
        return text;

      case OperationType.delete:
        if (op.length != null &&
            op.position >= 0 &&
            op.position + op.length! <= text.length) {
          return text.substring(0, op.position) +
              text.substring(op.position + op.length!);
        }
        return text;

      case OperationType.retain:
        // Retain operations don't modify the text
        return text;
    }
  }

  /// Transform a list of operations against another list
  ///
  /// This is useful when multiple operations need to be transformed
  /// against multiple concurrent operations.
  static List<Operation> transformList(
    List<Operation> ops1,
    List<Operation> ops2,
  ) {
    List<Operation> result = List.from(ops1);

    for (final op2 in ops2) {
      final List<Operation> transformed = [];
      for (final op1 in result) {
        final transformResult = transform(op1, op2);
        transformed.add(transformResult.op1Prime);
      }
      result = transformed;
    }

    return result;
  }
}

/// Result of transforming two operations
class TransformResult {
  final Operation op1Prime;
  final Operation op2Prime;

  TransformResult(this.op1Prime, this.op2Prime);
}
