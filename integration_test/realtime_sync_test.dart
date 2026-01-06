import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:noteassista/main.dart' as app;
import 'package:noteassista/screens/login_screen.dart';
import 'package:noteassista/screens/home_screen.dart';
import 'package:noteassista/services/supabase_service.dart';
import 'package:noteassista/models/note_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real-time Synchronization Tests', () {
    late SupabaseService supabaseService;

    // Clean up after each test
    tearDown(() async {
      try {
        final supabase = Supabase.instance.client;
        if (supabase.auth.currentUser != null) {
          await supabase.auth.signOut();
        }
      } catch (e) {
        debugPrint('Error during teardown: $e');
      }
    });

    // Helper function to create a test user and login
    Future<void> setupTestUser(WidgetTester tester) async {
      // Start the app to initialize Supabase
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait a bit more for Supabase to fully initialize
      await Future.delayed(const Duration(seconds: 2));

      // Create test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_sync_$timestamp@example.com';
      final testPassword = 'password123';

      final response = await Supabase.instance.client.auth.signUp(
        email: testEmail,
        password: testPassword,
      );

      if (response.user != null) {
        // Test user created successfully
      } else {
        throw Exception('Failed to create test user');
      }

      // Initialize SupabaseService
      supabaseService = SupabaseService.instance;

      // Wait for auth state to propagate
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('StreamBuilder updates on Supabase changes', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Verify we're on HomeScreen (already authenticated)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify initial empty state
      expect(find.text('No active notes yet'), findsOneWidget);
      expect(find.text('No completed notes yet'), findsOneWidget);

      // Create a note directly in Supabase (simulating external change)
      final noteResult = await supabaseService.createNote(
        NoteModel(
          id: '',
          title: 'Real-time Note',
          description: 'This note was added externally',
          timestamp: '14:30',
          categoryImageIndex: 1,
          isDone: false,
        ),
      );

      // Wait for StreamBuilder to receive the update
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify the note appears in the UI automatically
      expect(find.text('Real-time Note'), findsOneWidget);
      expect(find.text('This note was added externally'), findsOneWidget);
      expect(find.text('No active notes yet'), findsNothing);

      if (noteResult.success && noteResult.data != null) {
        final noteId = noteResult.data!;

        // Update the note directly in Supabase
        await supabaseService.updateNote(
          noteId,
          NoteModel(
            id: noteId,
            title: 'Updated Real-time Note',
            description: 'This note was updated externally',
            timestamp: '15:00',
            categoryImageIndex: 1,
            isDone: false,
          ),
        );

        // Wait for StreamBuilder to receive the update
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify the updated note appears in the UI
        expect(find.text('Updated Real-time Note'), findsOneWidget);
        expect(find.text('This note was updated externally'), findsOneWidget);
        expect(find.text('Real-time Note'), findsNothing);

        // Toggle note status directly in Supabase
        await supabaseService.toggleNoteStatus(noteId, true);

        // Wait for StreamBuilder to receive the update
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify note moved to done section
        expect(find.text('Updated Real-time Note'), findsOneWidget);
        expect(find.text('No active notes yet'), findsOneWidget);
        expect(find.text('No completed notes yet'), findsNothing);

        // Delete the note directly in Supabase
        await supabaseService.deleteNote(noteId);

        // Wait for StreamBuilder to receive the update
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify note is removed from UI
        expect(find.text('Updated Real-time Note'), findsNothing);
        expect(find.text('No completed notes yet'), findsOneWidget);
      }
    });

    testWidgets('Auth state changes trigger navigation', (
      WidgetTester tester,
    ) async {
      // Ensure we start logged out
      await Supabase.instance.client.auth.signOut();

      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify we start at LoginScreen (not authenticated)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Create and sign in a test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_auth_state_$timestamp@example.com';
      final testPassword = 'password123';

      await Supabase.instance.client.auth.signUp(
        email: testEmail,
        password: testPassword,
      );

      // Wait for auth state change to propagate through StreamBuilder
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation to HomeScreen (authenticated)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Sign out the user
      await Supabase.instance.client.auth.signOut();

      // Wait for auth state change to propagate through StreamBuilder
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation back to LoginScreen (not authenticated)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
