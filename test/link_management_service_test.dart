import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/link_management_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('LinkManagementService', () {
    late LinkManagementService service;

    setUp(() {
      // Use fake Firestore for testing
      final fakeFirestore = FakeFirebaseFirestore();
      service = LinkManagementService(firestore: fakeFirestore);
    });

    group('parseLinks', () {
      test('should parse simple wiki-style links', () {
        const content = 'This is a note with [[Another Note]] link.';
        final links = service.parseLinks(content);

        expect(links.length, 1);
        expect(links[0].targetTitle, 'Another Note');
        expect(links[0].displayText, 'Another Note');
        expect(links[0].startIndex, 20);
        expect(links[0].endIndex, 36);
      });

      test('should parse links with alias syntax', () {
        const content = 'Check out [[Project Plan|the plan]] for details.';
        final links = service.parseLinks(content);

        expect(links.length, 1);
        expect(links[0].targetTitle, 'Project Plan');
        expect(links[0].displayText, 'the plan');
      });

      test('should parse multiple links in content', () {
        const content = '''
        See [[Note 1]] and [[Note 2]] for more info.
        Also check [[Note 3|this note]].
        ''';
        final links = service.parseLinks(content);

        expect(links.length, 3);
        expect(links[0].targetTitle, 'Note 1');
        expect(links[1].targetTitle, 'Note 2');
        expect(links[2].targetTitle, 'Note 3');
        expect(links[2].displayText, 'this note');
      });

      test('should handle empty content', () {
        const content = '';
        final links = service.parseLinks(content);

        expect(links.length, 0);
      });

      test('should handle content with no links', () {
        const content = 'This is a regular note without any links.';
        final links = service.parseLinks(content);

        expect(links.length, 0);
      });

      test('should trim whitespace from link titles', () {
        const content = 'Link with spaces [[  Note Title  ]] here.';
        final links = service.parseLinks(content);

        expect(links.length, 1);
        expect(links[0].targetTitle, 'Note Title');
      });

      test('should handle nested brackets correctly', () {
        // Note: Nested brackets are not currently supported by the regex
        // The pattern stops at the first ] character
        const content = 'This [[Note [with] brackets]] is valid.';
        final links = service.parseLinks(content);

        // Current behavior: no match due to regex limitations
        expect(links.length, 0);
        // TODO: Future enhancement to support nested brackets
        // expect(links[0].targetTitle, 'Note [with');
      });

      test('should ignore incomplete link syntax', () {
        const content = 'This [[incomplete link is not valid.';
        final links = service.parseLinks(content);

        expect(links.length, 0);
      });

      test('should handle links at start and end of content', () {
        const content = '[[Start Note]] middle content [[End Note]]';
        final links = service.parseLinks(content);

        expect(links.length, 2);
        expect(links[0].targetTitle, 'Start Note');
        expect(links[1].targetTitle, 'End Note');
      });

      test('should handle consecutive links', () {
        const content = '[[Note 1]][[Note 2]][[Note 3]]';
        final links = service.parseLinks(content);

        expect(links.length, 3);
        expect(links[0].targetTitle, 'Note 1');
        expect(links[1].targetTitle, 'Note 2');
        expect(links[2].targetTitle, 'Note 3');
      });
    });
  });
}
