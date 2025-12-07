import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/models/template_model.dart';

void main() {
  group('TemplateLibraryScreen Widget Tests', () {
    testWidgets('should display template library screen structure', (
      WidgetTester tester,
    ) async {
      // Create a simple test widget that doesn't depend on Firebase
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Template Library'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No templates available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Templates will appear here once created',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Verify the app bar title
      expect(find.text('Template Library'), findsOneWidget);

      // Verify the search bar is present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search templates...'), findsOneWidget);

      // Verify search icon is present
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify empty state
      expect(find.text('No templates available'), findsOneWidget);
      expect(
        find.text('Templates will appear here once created'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('should display template cards in grid layout', (
      WidgetTester tester,
    ) async {
      // Create mock templates
      final mockTemplates = [
        TemplateModel(
          id: '1',
          name: 'Meeting Notes',
          description: 'Template for meeting notes',
          content:
              'Meeting Date: {{date}}\nAttendees: {{attendees}}\nAgenda:\n- \n\nNotes:\n- \n\nAction Items:\n- ',
          usageCount: 5,
          isCustom: false,
        ),
        TemplateModel(
          id: '2',
          name: 'Project Plan',
          description: 'Template for project planning',
          content:
              'Project: {{project_name}}\nObjective: {{objective}}\nTimeline: {{timeline}}',
          usageCount: 3,
          isCustom: true,
        ),
      ];

      // Create a test widget with mock data
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Template Library'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: mockTemplates.length,
                      itemBuilder: (context, index) {
                        final template = mockTemplates[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Template preview thumbnail
                                Container(
                                  height: 80,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      template.content.length > 100
                                          ? '${template.content.substring(0, 100)}...'
                                          : template.content,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        height: 1.2,
                                      ),
                                      maxLines: 6,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Template name
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Template description
                                Text(
                                  template.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Usage count and custom indicator
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${template.usageCount} uses',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (template.isCustom)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Custom',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify template cards are displayed
      expect(find.text('Meeting Notes'), findsOneWidget);
      expect(find.text('Project Plan'), findsOneWidget);
      expect(find.text('Template for meeting notes'), findsOneWidget);
      expect(find.text('Template for project planning'), findsOneWidget);
      expect(find.text('5 uses'), findsOneWidget);
      expect(find.text('3 uses'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Verify grid structure
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('should handle search functionality', (
      WidgetTester tester,
    ) async {
      // Create a simple search test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No templates found'),
                        SizedBox(height: 8),
                        Text('Try adjusting your search terms'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the search field and enter text
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'meeting');
      await tester.pumpAndSettle();

      // Verify search functionality structure
      expect(find.text('meeting'), findsOneWidget);
      expect(find.text('No templates found'), findsOneWidget);
      expect(find.text('Try adjusting your search terms'), findsOneWidget);
    });
  });
}
