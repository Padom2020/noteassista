import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/firestore_service.dart';
import 'package:noteassista/models/template_model.dart';

void main() {
  group('Template Sharing Tests', () {
    late FirestoreService firestoreService;
    late TemplateModel testTemplate;

    setUp(() {
      firestoreService = FirestoreService();
      testTemplate = TemplateModel(
        id: 'test-id',
        name: 'Test Template',
        description: 'A test template for sharing',
        content: '''# {{title}}

This is a test template with variables:
- {{variable1}}
- {{variable2}}

## Notes
{{notes}}''',
        variables: [
          TemplateVariable(
            name: 'title',
            placeholder: 'Enter title',
            required: true,
          ),
          TemplateVariable(
            name: 'variable1',
            placeholder: 'First variable',
            required: false,
          ),
          TemplateVariable(
            name: 'variable2',
            placeholder: 'Second variable',
            required: false,
          ),
          TemplateVariable(
            name: 'notes',
            placeholder: 'Additional notes',
            required: false,
          ),
        ],
        isCustom: true,
      );
    });

    test('should export template to JSON format', () {
      // Act
      final jsonString = firestoreService.exportTemplate(testTemplate);

      // Assert
      expect(jsonString, isNotEmpty);
      expect(jsonString, contains('"version":"1.0"'));
      expect(jsonString, contains('"name":"Test Template"'));
      expect(
        jsonString,
        contains('"description":"A test template for sharing"'),
      );
      expect(jsonString, contains('"variables"'));
      expect(jsonString, contains('"exportedAt"'));
    });

    test('should validate correct template JSON', () {
      // Arrange
      final jsonString = firestoreService.exportTemplate(testTemplate);

      // Act
      final result = firestoreService.validateImportedTemplate(jsonString);

      // Assert
      expect(result, isNotNull);
      expect(result!['template']['name'], equals('Test Template'));
      expect(
        result['template']['description'],
        equals('A test template for sharing'),
      );
      expect(result['template']['variables'], isA<List>());
    });

    test('should reject invalid JSON format', () {
      // Arrange
      const invalidJson = 'invalid json string';

      // Act & Assert
      expect(
        () => firestoreService.validateImportedTemplate(invalidJson),
        throwsA(isA<Exception>()),
      );
    });

    test('should reject template without required fields', () {
      // Arrange
      const incompleteTemplate = '''
      {
        "version": "1.0",
        "template": {
          "name": "Test"
        }
      }
      ''';

      // Act & Assert
      expect(
        () => firestoreService.validateImportedTemplate(incompleteTemplate),
        throwsA(isA<Exception>()),
      );
    });

    test('should reject template with empty name', () {
      // Arrange
      const emptyNameTemplate = '''
      {
        "version": "1.0",
        "template": {
          "name": "",
          "description": "Test description",
          "content": "Test content"
        }
      }
      ''';

      // Act & Assert
      expect(
        () => firestoreService.validateImportedTemplate(emptyNameTemplate),
        throwsA(isA<Exception>()),
      );
    });

    test('should validate template with variables', () {
      // Arrange
      const templateWithVariables = '''
      {
        "version": "1.0",
        "template": {
          "name": "Test Template",
          "description": "Test description",
          "content": "Test content with {{variable}}",
          "variables": [
            {
              "name": "variable",
              "placeholder": "Enter value",
              "required": true
            }
          ]
        }
      }
      ''';

      // Act
      final result = firestoreService.validateImportedTemplate(
        templateWithVariables,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!['template']['variables'], hasLength(1));
      expect(result['template']['variables'][0]['name'], equals('variable'));
    });

    test('should reject template with invalid variables', () {
      // Arrange
      const invalidVariablesTemplate = '''
      {
        "version": "1.0",
        "template": {
          "name": "Test Template",
          "description": "Test description",
          "content": "Test content",
          "variables": [
            {
              "name": "variable"
            }
          ]
        }
      }
      ''';

      // Act & Assert
      expect(
        () =>
            firestoreService.validateImportedTemplate(invalidVariablesTemplate),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle template without variables', () {
      // Arrange
      const templateWithoutVariables = '''
      {
        "version": "1.0",
        "template": {
          "name": "Simple Template",
          "description": "A simple template",
          "content": "Simple content without variables"
        }
      }
      ''';

      // Act
      final result = firestoreService.validateImportedTemplate(
        templateWithoutVariables,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!['template']['name'], equals('Simple Template'));
    });

    test('should export and validate round trip', () {
      // Act
      final exported = firestoreService.exportTemplate(testTemplate);
      final validated = firestoreService.validateImportedTemplate(exported);

      // Assert
      expect(validated, isNotNull);
      expect(validated!['template']['name'], equals(testTemplate.name));
      expect(
        validated['template']['description'],
        equals(testTemplate.description),
      );
      expect(validated['template']['content'], equals(testTemplate.content));
      expect(
        validated['template']['variables'],
        hasLength(testTemplate.variables.length),
      );
    });
  });
}
