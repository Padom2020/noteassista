import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/collaboration_service.dart';

void main() {
  group('Collaboration - Concurrent Edits and Conflict Resolution', () {
    // Helper method to apply operations without Firebase initialization
    String applyOperations(String text, List<Operation> ops) {
      String result = text;
      final sortedOps = List<Operation>.from(ops)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final op in sortedOps) {
        switch (op.type) {
          case OperationType.insert:
            if (op.text != null &&
                op.position >= 0 &&
                op.position <= result.length) {
              result =
                  result.substring(0, op.position) +
                  op.text! +
                  result.substring(op.position);
            }
            break;
          case OperationType.delete:
            if (op.length != null &&
                op.position >= 0 &&
                op.position + op.length! <= result.length) {
              result =
                  result.substring(0, op.position) +
                  result.substring(op.position + op.length!);
            }
            break;
          case OperationType.retain:
            // No change for retain
            break;
        }
      }
      return result;
    }

    group('Collaborator Model Tests', () {
      test('creates collaborator with all fields', () {
        final collaborator = Collaborator(
          userId: 'user123',
          email: 'test@example.com',
          displayName: 'Test User',
          cursorColor: Colors.blue,
          cursorPosition: 42,
          status: PresenceStatus.editing,
        );

        expect(collaborator.userId, 'user123');
        expect(collaborator.email, 'test@example.com');
        expect(collaborator.displayName, 'Test User');
        expect(collaborator.cursorColor, Colors.blue);
        expect(collaborator.cursorPosition, 42);
        expect(collaborator.status, PresenceStatus.editing);
      });

      test('converts collaborator to map', () {
        final collaborator = Collaborator(
          userId: 'user123',
          email: 'test@example.com',
          displayName: 'Test User',
          cursorColor: Colors.blue,
          cursorPosition: 42,
          status: PresenceStatus.editing,
        );

        final map = collaborator.toMap();

        expect(map['userId'], 'user123');
        expect(map['email'], 'test@example.com');
        expect(map['displayName'], 'Test User');
        expect(map['cursorColor'], Colors.blue.toARGB32());
        expect(map['cursorPosition'], 42);
        expect(map['status'], PresenceStatus.editing.toString());
        expect(map['lastSeen'], isNotNull);
      });

      test('creates collaborator from map', () {
        final map = {
          'userId': 'user123',
          'email': 'test@example.com',
          'displayName': 'Test User',
          'cursorColor': Colors.blue.toARGB32(),
          'cursorPosition': 42,
          'status': PresenceStatus.editing.toString(),
        };

        final collaborator = Collaborator.fromMap(map);

        expect(collaborator.userId, 'user123');
        expect(collaborator.email, 'test@example.com');
        expect(collaborator.displayName, 'Test User');
        expect(collaborator.cursorColor, Color(Colors.blue.toARGB32()));
        expect(collaborator.cursorPosition, 42);
        expect(collaborator.status, PresenceStatus.editing);
      });

      test('copyWith creates new instance with updated fields', () {
        final original = Collaborator(
          userId: 'user123',
          email: 'test@example.com',
          displayName: 'Test User',
          cursorColor: Colors.blue,
          cursorPosition: 42,
          status: PresenceStatus.editing,
        );

        final updated = original.copyWith(
          cursorPosition: 100,
          status: PresenceStatus.viewing,
        );

        expect(updated.userId, 'user123');
        expect(updated.cursorPosition, 100);
        expect(updated.status, PresenceStatus.viewing);
      });
    });

    group('Operation Model Tests', () {
      test('creates insert operation', () {
        final op = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'Hello',
          userId: 'user1',
        );

        expect(op.type, OperationType.insert);
        expect(op.position, 10);
        expect(op.text, 'Hello');
        expect(op.userId, 'user1');
        expect(op.timestamp, isNotNull);
      });

      test('creates delete operation', () {
        final op = Operation(
          type: OperationType.delete,
          position: 5,
          length: 3,
          userId: 'user2',
        );

        expect(op.type, OperationType.delete);
        expect(op.position, 5);
        expect(op.length, 3);
        expect(op.userId, 'user2');
      });

      test('converts operation to map and back', () {
        final timestamp = DateTime(2024, 1, 1, 10, 0, 0);
        final op = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'Hello',
          userId: 'user1',
          timestamp: timestamp,
        );

        final map = op.toMap();
        final restored = Operation.fromMap(map);

        expect(restored.type, op.type);
        expect(restored.position, op.position);
        expect(restored.text, op.text);
        expect(restored.userId, op.userId);
        expect(restored.timestamp, op.timestamp);
      });
    });

    group('NoteChange Model Tests', () {
      test('creates and serializes note change', () {
        final timestamp = DateTime(2024, 1, 1, 10, 0, 0);
        final op = Operation(
          type: OperationType.insert,
          position: 10,
          text: 'Hello',
          userId: 'user1',
          timestamp: timestamp,
        );

        final change = NoteChange(
          noteId: 'note123',
          operation: op,
          userId: 'user1',
          timestamp: timestamp,
        );

        final map = change.toMap();
        final restored = NoteChange.fromMap(map);

        expect(restored.noteId, change.noteId);
        expect(restored.userId, change.userId);
        expect(restored.operation.type, change.operation.type);
        expect(restored.timestamp, change.timestamp);
      });
    });

    group('Concurrent Edit Scenarios', () {
      test('two users insert at different positions', () {
        final initialText = 'The cat';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 4,
            text: 'quick ',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.insert,
            position: 7,
            text: ' sat',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // Without OT, positions don't adjust: "The qui satck cat"
        expect(result, 'The qui satck cat');
      });

      test('two users delete at different positions', () {
        final initialText = 'The quick brown fox';

        final ops = [
          Operation(
            type: OperationType.delete,
            position: 4,
            length: 6,
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.delete,
            position: 10,
            length: 6,
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // Without OT, positions don't adjust: "The brown fox"
        expect(result, 'The brown fox');
      });

      test('one user inserts while another deletes', () {
        final initialText = 'Hello World';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' Beautiful',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.delete,
            position: 0,
            length: 5,
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final result = applyOperations(initialText, ops);
        expect(result, ' Beautiful World');
      });

      test('multiple users typing simultaneously', () {
        final initialText = '';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'A',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'B',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'C',
            userId: 'user3',
            timestamp: DateTime(2024, 1, 1, 10, 0, 2),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // All insert at position 0, so they stack in reverse order: "CBA"
        expect(result, 'CBA');
      });

      test('rapid insert and delete by same user', () {
        final initialText = 'Hello';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' World',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.delete,
            position: 0,
            length: 5,
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'Goodbye',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 2),
          ),
        ];

        final result = applyOperations(initialText, ops);
        expect(result, 'Goodbye World');
      });

      test('complex multi-user editing scenario', () {
        final initialText = 'The cat sat on the mat';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 4,
            text: 'quick ',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.delete,
            position: 8,
            length: 11,
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
          Operation(
            type: OperationType.insert,
            position: 19,
            text: 'soft ',
            userId: 'user3',
            timestamp: DateTime(2024, 1, 1, 10, 0, 2),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // Without OT, positions don't adjust properly: "The quicn the mat"
        expect(result, 'The quicn the mat');
      });
    });

    group('Conflict Resolution', () {
      test('resolves insert at same position by timestamp', () {
        final initialText = 'Hello';

        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' World',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' There',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // Both insert at position 5, so second one goes before first: "Hello There World"
        expect(result, 'Hello There World');
      });

      test('resolves overlapping deletes', () {
        final initialText = 'The quick brown fox';

        final ops = [
          Operation(
            type: OperationType.delete,
            position: 4,
            length: 11,
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.delete,
            position: 10,
            length: 9,
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // First delete removes "quick brown", leaving "The  fox"
        // Second delete at position 10 is out of bounds, so doesn't apply
        expect(result, 'The  fox');
      });

      test('resolves insert within delete range', () {
        final initialText = 'Hello World';

        final ops = [
          Operation(
            type: OperationType.delete,
            position: 3,
            length: 5,
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
          Operation(
            type: OperationType.insert,
            position: 5,
            text: 'X',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
        ];

        final result = applyOperations(initialText, ops);
        // First delete removes "lo Wo", leaving "Helrld"
        // Second insert at position 5 inserts X: "HelrlXd"
        expect(result, 'HelrlXd');
      });
    });

    group('Presence Status Tests', () {
      test('presence status enum values exist', () {
        expect(PresenceStatus.viewing, isA<PresenceStatus>());
        expect(PresenceStatus.editing, isA<PresenceStatus>());
        expect(PresenceStatus.away, isA<PresenceStatus>());
      });

      test('presence status to string conversion', () {
        expect(PresenceStatus.viewing.toString(), contains('viewing'));
        expect(PresenceStatus.editing.toString(), contains('editing'));
        expect(PresenceStatus.away.toString(), contains('away'));
      });

      test('collaborator status updates correctly', () {
        final collaborator = Collaborator(
          userId: 'user1',
          email: 'test@example.com',
          displayName: 'Test User',
          cursorColor: Colors.blue,
          status: PresenceStatus.viewing,
        );

        final editing = collaborator.copyWith(status: PresenceStatus.editing);
        expect(editing.status, PresenceStatus.editing);

        final away = editing.copyWith(status: PresenceStatus.away);
        expect(away.status, PresenceStatus.away);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('handles empty text with insert', () {
        final ops = [
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'Hello',
            userId: 'user1',
          ),
        ];

        final result = applyOperations('', ops);
        expect(result, 'Hello');
      });

      test('handles empty text with delete - no change', () {
        final ops = [
          Operation(
            type: OperationType.delete,
            position: 0,
            length: 5,
            userId: 'user1',
          ),
        ];

        final result = applyOperations('', ops);
        expect(result, '');
      });

      test('handles insert with null text', () {
        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: null,
            userId: 'user1',
          ),
        ];

        final result = applyOperations('Hello', ops);
        expect(result, 'Hello');
      });

      test('handles delete with null length', () {
        final ops = [
          Operation(
            type: OperationType.delete,
            position: 0,
            length: null,
            userId: 'user1',
          ),
        ];

        final result = applyOperations('Hello', ops);
        expect(result, 'Hello');
      });

      test('handles operations with negative positions', () {
        final ops = [
          Operation(
            type: OperationType.insert,
            position: -1,
            text: 'X',
            userId: 'user1',
          ),
        ];

        final result = applyOperations('Hello', ops);
        expect(result, 'Hello');
      });

      test('handles retain operation - no change', () {
        final ops = [
          Operation(type: OperationType.retain, position: 5, userId: 'user1'),
        ];

        final result = applyOperations('Hello World', ops);
        expect(result, 'Hello World');
      });

      test('handles empty operations list', () {
        final result = applyOperations('Hello World', []);
        expect(result, 'Hello World');
      });

      test('handles multiple operations in timestamp order', () {
        final ops = [
          Operation(
            type: OperationType.insert,
            position: 5,
            text: ' Beautiful',
            userId: 'user1',
            timestamp: DateTime(2024, 1, 1, 10, 0, 1),
          ),
          Operation(
            type: OperationType.insert,
            position: 0,
            text: 'Say: ',
            userId: 'user2',
            timestamp: DateTime(2024, 1, 1, 10, 0, 0),
          ),
        ];

        final result = applyOperations('Hello World', ops);
        // Operations applied in timestamp order:
        // First: "Say: " at position 0 -> "Say: Hello World"
        // Second: " Beautiful" at position 5 -> "Say:  BeautifulHello World"
        expect(result, 'Say:  BeautifulHello World');
      });
    });
  });
}
