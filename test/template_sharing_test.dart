import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/supabase_service.dart';
import 'package:noteassista/models/template_model.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupSupabaseMocks();
  });

  tearDownAll(() {
    tearDownSupabaseMocks();
  });
  group('Template Sharing Tests', () {
    late SupabaseService supabaseService;
    late TemplateModel testTemplate;

    setUp(() {
      supabaseService = SupabaseService.instance;
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
      final result = supabaseService.exportTemplate(testTemplate);

      // Assert
      expect(result.success, isTrue);
      expect(result.data, isNotEmpty);
      expect(result.data!, contains('"version":"1.0"'));
      expect(result.data!, contains('"name":"Test Template"'));
      expect(
        result.data!,
        contains('"description":"A test template for sharing"'),
      );
      expect(result.data!, contains('"variables"'));
      expect(result.data!, contains('"exportedAt"'));
    });

    test('should validate correct template JSON', () {
      // Arrange
      final exportResult = supabaseService.exportTemplate(testTemplate);
      expect(exportResult.success, isTrue);

      // Act
      final result = supabaseService.validateImportedTemplate(
        exportResult.data!,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!['template']['name'], equals('Test Template'));
      expect(
        result.data!['template']['description'],
        equals('A test template for sharing'),
      );
      expect(result.data!['template']['variables'], isA<List>());
    });

    test('should reject invalid JSON format', () {
      // Arrange
      const invalidJson = 'invalid json string';

      // Act
      final result = supabaseService.validateImportedTemplate(invalidJson);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
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

      // Act
      final result = supabaseService.validateImportedTemplate(
        incompleteTemplate,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
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

      // Act
      final result = supabaseService.validateImportedTemplate(
        emptyNameTemplate,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
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
      final result = supabaseService.validateImportedTemplate(
        templateWithVariables,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!['template']['variables'], hasLength(1));
      expect(
        result.data!['template']['variables'][0]['name'],
        equals('variable'),
      );
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

      // Act
      final result = supabaseService.validateImportedTemplate(
        invalidVariablesTemplate,
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
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
      final result = supabaseService.validateImportedTemplate(
        templateWithoutVariables,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!['template']['name'], equals('Simple Template'));
    });

    test('should export and validate round trip', () {
      // Act
      final exportResult = supabaseService.exportTemplate(testTemplate);
      expect(exportResult.success, isTrue);

      final validationResult = supabaseService.validateImportedTemplate(
        exportResult.data!,
      );

      // Assert
      expect(validationResult.success, isTrue);
      expect(validationResult.data, isNotNull);
      expect(
        validationResult.data!['template']['name'],
        equals(testTemplate.name),
      );
      expect(
        validationResult.data!['template']['description'],
        equals(testTemplate.description),
      );
      expect(
        validationResult.data!['template']['content'],
        equals(testTemplate.content),
      );
      expect(
        validationResult.data!['template']['variables'],
        hasLength(testTemplate.variables.length),
      );
    });
  });
}
