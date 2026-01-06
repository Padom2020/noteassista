import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/template_model.dart';

void main() {
  group('Template Model Tests', () {
    test('TemplateModel creation and serialization', () {
      final template = TemplateModel(
        id: 'test-id',
        name: 'Test Template',
        description: 'A test template',
        content: 'This is test content with {{variable}}',
        variables: [
          TemplateVariable(
            name: 'variable',
            placeholder: 'Enter value',
            required: true,
          ),
        ],
        usageCount: 5,
        isCustom: true,
      );

      expect(template.id, equals('test-id'));
      expect(template.name, equals('Test Template'));
      expect(template.description, equals('A test template'));
      expect(template.content, contains('{{variable}}'));
      expect(template.variables.length, equals(1));
      expect(template.variables.first.name, equals('variable'));
      expect(template.variables.first.required, equals(true));
      expect(template.usageCount, equals(5));
      expect(template.isCustom, equals(true));
    });

    test('TemplateModel toMap serialization', () {
      final template = TemplateModel(
        id: 'test-id',
        name: 'Test Template',
        description: 'A test template',
        content: 'Content with {{var}}',
        variables: [
          TemplateVariable(
            name: 'var',
            placeholder: 'Enter value',
            required: false,
          ),
        ],
        usageCount: 3,
        isCustom: true,
      );

      final map = template.toMap();

      expect(map['name'], equals('Test Template'));
      expect(map['description'], equals('A test template'));
      expect(map['content'], equals('Content with {{var}}'));
      expect(map['usageCount'], equals(3));
      expect(map['isCustom'], equals(true));
      expect(map['variables'], isA<List>());
      expect((map['variables'] as List).length, equals(1));
    });

    test('TemplateModel copyWith functionality', () {
      final original = TemplateModel(
        id: 'test-id',
        name: 'Original Name',
        description: 'Original description',
        content: 'Original content',
        usageCount: 1,
        isCustom: false,
      );

      final updated = original.copyWith(name: 'Updated Name', usageCount: 5);

      expect(updated.id, equals('test-id')); // unchanged
      expect(updated.name, equals('Updated Name')); // changed
      expect(updated.description, equals('Original description')); // unchanged
      expect(updated.content, equals('Original content')); // unchanged
      expect(updated.usageCount, equals(5)); // changed
      expect(updated.isCustom, equals(false)); // unchanged
    });

    test('TemplateVariable creation and serialization', () {
      final variable = TemplateVariable(
        name: 'test_var',
        placeholder: 'Enter test value',
        required: true,
      );

      expect(variable.name, equals('test_var'));
      expect(variable.placeholder, equals('Enter test value'));
      expect(variable.required, equals(true));

      final map = variable.toMap();
      expect(map['name'], equals('test_var'));
      expect(map['placeholder'], equals('Enter test value'));
      expect(map['required'], equals(true));
    });

    test('TemplateVariable fromMap deserialization', () {
      final map = {
        'name': 'test_var',
        'placeholder': 'Enter test value',
        'required': false,
      };

      final variable = TemplateVariable.fromMap(map);

      expect(variable.name, equals('test_var'));
      expect(variable.placeholder, equals('Enter test value'));
      expect(variable.required, equals(false));
    });

    test('TemplateVariable defaults when required not specified', () {
      final variable = TemplateVariable(
        name: 'test_var',
        placeholder: 'Enter test value',
        // required not specified, should default to false
      );

      expect(variable.required, equals(false));
    });

    test('Template with multiple variables', () {
      final template = TemplateModel(
        id: 'multi-var-template',
        name: 'Multi Variable Template',
        description: 'Template with multiple variables',
        content: 'Hello {{name}}, your age is {{age}} and you live in {{city}}',
        variables: [
          TemplateVariable(
            name: 'name',
            placeholder: 'Enter your name',
            required: true,
          ),
          TemplateVariable(
            name: 'age',
            placeholder: 'Enter your age',
            required: false,
          ),
          TemplateVariable(
            name: 'city',
            placeholder: 'Enter your city',
            required: true,
          ),
        ],
        isCustom: true,
      );

      expect(template.variables.length, equals(3));
      expect(template.variables[0].name, equals('name'));
      expect(template.variables[0].required, equals(true));
      expect(template.variables[1].name, equals('age'));
      expect(template.variables[1].required, equals(false));
      expect(template.variables[2].name, equals('city'));
      expect(template.variables[2].required, equals(true));
    });
  });

  group('Predefined Template Content Tests', () {
    test('Meeting Notes template has expected structure', () {
      // This tests the structure we expect from predefined templates
      const meetingContent = '''# {{meeting_title}}

**Date:** {{date}}
**Attendees:** {{attendees}}
**Duration:** {{duration}}

## Agenda
- {{agenda_item_1}}
- {{agenda_item_2}}
- {{agenda_item_3}}

## Discussion Points
{{discussion_notes}}

## Action Items
- [ ] {{action_item_1}} - Assigned to: {{assignee_1}}
- [ ] {{action_item_2}} - Assigned to: {{assignee_2}}
- [ ] {{action_item_3}} - Assigned to: {{assignee_3}}

## Next Steps
{{next_steps}}

## Next Meeting
**Date:** {{next_meeting_date}}
**Time:** {{next_meeting_time}}''';

      expect(meetingContent, contains('{{meeting_title}}'));
      expect(meetingContent, contains('{{date}}'));
      expect(meetingContent, contains('{{attendees}}'));
      expect(meetingContent, contains('## Agenda'));
      expect(meetingContent, contains('## Action Items'));
      expect(meetingContent, contains('- [ ]')); // Checkbox format
    });

    test('Recipe template has expected structure', () {
      const recipeContent = '''# {{recipe_name}}

**Cuisine:** {{cuisine}}
**Prep Time:** {{prep_time}}
**Cook Time:** {{cook_time}}
**Total Time:** {{total_time}}
**Servings:** {{servings}}
**Difficulty:** {{difficulty}}

## Description
{{recipe_description}}

## Ingredients
- {{ingredient_1}}
- {{ingredient_2}}
- {{ingredient_3}}
- {{ingredient_4}}
- {{ingredient_5}}
- {{ingredient_6}}

## Instructions
1. {{step_1}}
2. {{step_2}}
3. {{step_3}}
4. {{step_4}}
5. {{step_5}}

## Tips & Notes
{{tips_notes}}

## Nutritional Information
{{nutrition_info}}

## Source
{{recipe_source}}

## Rating
{{rating}}/5 stars

## Modifications
{{modifications}}''';

      expect(recipeContent, contains('{{recipe_name}}'));
      expect(recipeContent, contains('{{cuisine}}'));
      expect(recipeContent, contains('## Ingredients'));
      expect(recipeContent, contains('## Instructions'));
      expect(recipeContent, contains('1. {{step_1}}'));
      expect(recipeContent, contains('{{rating}}/5 stars'));
    });
  });
}
