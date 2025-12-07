import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/utils/operational_transform.dart';
import 'package:noteassista/services/collaboration_service.dart';

void main() {
  group('Operational Transform Tests', () {
    group('Insert vs Insert Operations', () {
      test('insert before insert - positions adjust correctly', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'hello',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'world',
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(op1, op2);

        // op1 stays the same (it's before op2)
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.text, 'hello');

        // op2 position shifts right by length of op1's text
        expect(result.op2Prime.position, 15); // 10 + 5
        expect(result.op2Prime.text, 'world');
      });

      test('insert after insert - positions adjust correctly', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'world',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'hello',
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(op1, op2);

        // op1 position shifts right by length of op2's text
        expect(result.op1Prime.position, 15); // 10 + 5
        expect(result.op1Prime.text, 'world');

        // op2 stays the same (it's before op1)
        expect(result.op2Prime.position, 5);
        expect(result.op2Prime.text, 'hello');
      });

      test('insert at same position - timestamp tiebreaker', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'A',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'B',
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(op1, op2);

        // op1 has earlier timestamp, so it wins
        expect(result.op1Prime.position, 10);
        expect(result.op1Prime.text, 'A');

        // op2 shifts right
        expect(result.op2Prime.position, 11); // 10 + 1
        expect(result.op2Prime.text, 'B');
      });

      test(
        'insert at same position with same timestamp - userId tiebreaker',
        () {
          final timestamp = DateTime(2024, 1, 1, 10, 0, 0);

          final op1 = Operation(
            type: OperationType.insert,
            position: 10,
            text: 'A',
            userId: 'alice',
            timestamp: timestamp,
          );

          final op2 = Operation(
            type: OperationType.insert,
            position: 10,
            text: 'B',
            userId: 'bob',
            timestamp: timestamp,
          );

          final result = OperationalTransform.transform(op1, op2);

          // 'alice' < 'bob' alphabetically, so op1 wins
          expect(result.op1Prime.position, 10);
          expect(result.op1Prime.text, 'A');

          // op2 shifts right
          expect(result.op2Prime.position, 11);
          expect(result.op2Prime.text, 'B');
        },
      );
    });

    group('Insert vs Delete Operations', () {
      test('insert before delete - delete position shifts right', () {
        final insert = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'hello',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete = Operation(
          type: OperationType.delete,
          position: 10,
          length: 3,
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(insert, delete);

        // Insert stays the same
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.text, 'hello');

        // Delete position shifts right by insert length
        expect(result.op2Prime.position, 15); // 10 + 5
        expect(result.op2Prime.length, 3);
      });

      test('insert after delete - insert position shifts left', () {
        final insert = Operation(
          type: OperationType.insert,
          position: 15,
          text: 'hello',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete = Operation(
          type: OperationType.delete,
          position: 5,
          length: 3,
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(insert, delete);

        // Insert position shifts left by delete length
        expect(result.op1Prime.position, 12); // 15 - 3
        expect(result.op1Prime.text, 'hello');

        // Delete stays the same
        expect(result.op2Prime.position, 5);
        expect(result.op2Prime.length, 3);
      });

      test('insert within delete range - insert at delete start', () {
        final insert = Operation(
          type: OperationType.insert,
          position: 7,
          text: 'X',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete = Operation(
          type: OperationType.delete,
          position: 5,
          length: 5, // deletes positions 5-9
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(insert, delete);

        // Insert moves to delete start
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.text, 'X');

        // Delete position shifts right by insert length
        expect(result.op2Prime.position, 6); // 5 + 1
        expect(result.op2Prime.length, 5);
      });
    });

    group('Delete vs Delete Operations', () {
      test('non-overlapping deletes - independent operations', () {
        final delete1 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 3,
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete2 = Operation(
          type: OperationType.delete,
          position: 15,
          length: 2,
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(delete1, delete2);

        // delete1 stays the same
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.length, 3);

        // delete2 position shifts left by delete1 length
        expect(result.op2Prime.position, 12); // 15 - 3
        expect(result.op2Prime.length, 2);
      });

      test('overlapping deletes - adjust for overlap', () {
        final delete1 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 5, // deletes 5-9
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete2 = Operation(
          type: OperationType.delete,
          position: 7,
          length: 5, // deletes 7-11
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(delete1, delete2);

        // Overlap is positions 7-9 (length 3)
        // delete1 stays the same
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.length, 5);

        // delete2 adjusts for overlap
        expect(result.op2Prime.position, 5);
        expect(result.op2Prime.length, 2); // 5 - 3 (overlap)
      });

      test('completely overlapping deletes - one contained in other', () {
        final delete1 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 10, // deletes 5-14
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final delete2 = Operation(
          type: OperationType.delete,
          position: 7,
          length: 3, // deletes 7-9 (contained in delete1)
          userId: 'user2',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final result = OperationalTransform.transform(delete1, delete2);

        // delete1 adjusts for overlap
        expect(result.op1Prime.position, 5);
        expect(result.op1Prime.length, 7); // 10 - 3 (overlap)

        // delete2 moves to delete1 start and adjusts
        expect(result.op2Prime.position, 5);
        expect(result.op2Prime.length, 0); // completely overlapped
      });
    });

    group('Apply Operations', () {
      test('apply insert operation', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.insert,
          position: 5,
          text: ' Beautiful',
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello Beautiful World');
      });

      test('apply delete operation', () {
        final text = 'Hello Beautiful World';
        final op = Operation(
          type: OperationType.delete,
          position: 5,
          length: 10, // delete ' Beautiful'
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('apply retain operation - no change', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.retain,
          position: 5,
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('apply multiple operations in sequence', () {
        final text = 'Hello World';
        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' Beautiful',
            userId: 'user1',
          ),
          Operation(
            type: OperationType.delete,
            position: 0,
            length: 5, // delete 'Hello'
            userId: 'user2',
          ),
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'Goodbye',
            userId: 'user1',
          ),
        ];

        final result = OperationalTransform.applyOperations(text, ops);
        expect(result, 'Goodbye Beautiful World');
      });

      test('apply insert at start of text', () {
        final text = 'World';
        final op = Operation(
          type: OperationType.insert,
          position: 0,
          text: 'Hello ',
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('apply insert at end of text', () {
        final text = 'Hello';
        final op = Operation(
          type: OperationType.insert,
          position: 5,
          text: ' World',
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('apply delete at start of text', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.delete,
          position: 0,
          length: 6, // delete 'Hello '
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'World');
      });

      test('apply delete at end of text', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.delete,
          position: 5,
          length: 6, // delete ' World'
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello');
      });
    });

    group('Compose Operations', () {
      test('compose adjacent inserts', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'Hello',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.insert,
          position: 10, // 5 + 5
          text: ' World',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final composed = OperationalTransform.compose(op1, op2);

        expect(composed, isNotNull);
        expect(composed!.type, OperationType.insert);
        expect(composed.position, 5);
        expect(composed.text, 'Hello World');
      });

      test('compose adjacent deletes', () {
        final op1 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 3,
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 2,
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final composed = OperationalTransform.compose(op1, op2);

        expect(composed, isNotNull);
        expect(composed!.type, OperationType.delete);
        expect(composed.position, 5);
        expect(composed.length, 5);
      });

      test('compose insert then delete at same position - cancel out', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'ABC',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.delete,
          position: 5,
          length: 3,
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final composed = OperationalTransform.compose(op1, op2);

        // Operations cancel out
        expect(composed, isNull);
      });

      test('compose non-adjacent operations - cannot compose', () {
        final op1 = Operation(
          type: OperationType.insert,
          position: 5,
          text: 'Hello',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 0),
        );

        final op2 = Operation(
          type: OperationType.insert,
          position: 20,
          text: 'World',
          userId: 'user1',
          timestamp: DateTime(2024, 1, 1, 10, 0, 1),
        );

        final composed = OperationalTransform.compose(op1, op2);

        expect(composed, isNull);
      });
    });

    group('Invert Operations', () {
      test('invert insert operation', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.insert,
          position: 5,
          text: ' Beautiful',
          userId: 'user1',
        );

        final inverted = OperationalTransform.invert(op, text);

        expect(inverted.type, OperationType.delete);
        expect(inverted.position, 5);
        expect(inverted.length, 10);
      });

      test('invert delete operation', () {
        final text = 'Hello Beautiful World';
        final op = Operation(
          type: OperationType.delete,
          position: 5,
          length: 10,
          userId: 'user1',
        );

        final inverted = OperationalTransform.invert(op, text);

        expect(inverted.type, OperationType.insert);
        expect(inverted.position, 5);
        expect(inverted.text, ' Beautiful');
      });

      test('invert retain operation - stays the same', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.retain,
          position: 5,
          userId: 'user1',
        );

        final inverted = OperationalTransform.invert(op, text);

        expect(inverted.type, OperationType.retain);
        expect(inverted.position, 5);
      });
    });

    group('Transform List', () {
      test('transform list of operations against another list', () {
        final ops1 = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: 'A',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.insert,
            position: 10,
            text: 'B',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final ops2 = [
          Operation(
            type: OperationType.insert,
            position: 7,
            text: 'X',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
        ];

        final transformed = OperationalTransform.transformList(ops1, ops2);

        expect(transformed.length, 2);
        // First operation in ops1 is before ops2, so stays at position 5
        expect(transformed[0].position, 5);
        // Second operation in ops1 needs to account for ops2's insert
        expect(transformed[1].position, 11); // 10 + 1
      });
    });

    group('Edge Cases', () {
      test('insert with empty text', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.insert,
          position: 5,
          text: '',
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('delete with zero length', () {
        final text = 'Hello World';
        final op = Operation(
          type: OperationType.delete,
          position: 5,
          length: 0,
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        expect(result, 'Hello World');
      });

      test('insert at invalid position - beyond text length', () {
        final text = 'Hello';
        final op = Operation(
          type: OperationType.insert,
          position: 100,
          text: 'World',
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        // Should not modify text if position is invalid
        expect(result, 'Hello');
      });

      test('delete at invalid position - beyond text length', () {
        final text = 'Hello';
        final op = Operation(
          type: OperationType.delete,
          position: 100,
          length: 5,
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        // Should not modify text if position is invalid
        expect(result, 'Hello');
      });

      test('delete length exceeds remaining text', () {
        final text = 'Hello';
        final op = Operation(
          type: OperationType.delete,
          position: 3,
          length: 10, // only 2 characters remain after position 3
          userId: 'user1',
        );

        final result = OperationalTransform.applyOperation(text, op);
        // Should not modify text if delete would exceed bounds
        expect(result, 'Hello');
      });
    });
  });
}
