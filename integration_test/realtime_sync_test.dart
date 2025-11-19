import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:noteassista/main.dart' as app;
import 'package:noteassista/screens/login_screen.dart';
import 'package:noteassista/screens/home_screen.dart';
import 'package:noteassista/services/firestore_service.dart';
import 'package:noteassista/models/note_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real-time Synchronization Tests', () {
    late String testUserId;
    late FirestoreService firestoreService;

    // Clean up after each test
    tearDown(() async {
      try {
        final auth = FirebaseAuth.instance;
        if (auth.currentUser != null) {
          await auth.signOut();
        }
      } catch (e) {
        debugPrint('Error during teardown: $e');
      }
    });

    // Helper function to create a test user and login
    Future<void> setupTestUser(WidgetTester tester) async {
      // Start the app to initialize Firebase
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait a bit more for Firebase to fully initialize
      await Future.delayed(const Duration(seconds: 2));

      // Create test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_sync_$timestamp@example.com';
      final testPassword = 'password123';

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          );
      testUserId = userCredential.user!.uid;

      // Initialize FirestoreService
      firestoreService = FirestoreService();

      // Create user document in Firestore
      await firestoreService.createUser(testUserId, testEmail);

      // Wait for auth state to propagate
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('StreamBuilder updates on Firestore changes', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Verify we're on HomeScreen (already authenticated)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify initial empty state
      expect(find.text('No active notes yet'), findsOneWidget);
      expect(find.text('No completed notes yet'), findsOneWidget);

      // Create a note directly in Firestore (simulating external change)
      await firestoreService.createNote(
        testUserId,
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

      // Get the note ID for further testing
      final notesSnapshot =
          await firestoreService.streamNotes(testUserId, false).first;
      final noteId = notesSnapshot.docs.first.id;

      // Update the note directly in Firestore
      await firestoreService.updateNote(
        testUserId,
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

      // Toggle note status directly in Firestore
      await firestoreService.toggleNoteStatus(testUserId, noteId, true);

      // Wait for StreamBuilder to receive the update
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify note moved to done section
      expect(find.text('Updated Real-time Note'), findsOneWidget);
      expect(find.text('No active notes yet'), findsOneWidget);
      expect(find.text('No completed notes yet'), findsNothing);

      // Delete the note directly in Firestore
      await firestoreService.deleteNote(testUserId, noteId);

      // Wait for StreamBuilder to receive the update
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify note is removed from UI
      expect(find.text('Updated Real-time Note'), findsNothing);
      expect(find.text('No completed notes yet'), findsOneWidget);
    });

    testWidgets('Auth state changes trigger navigation', (
      WidgetTester tester,
    ) async {
      // Ensure we start logged out
      await FirebaseAuth.instance.signOut();

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

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
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
      await FirebaseAuth.instance.signOut();

      // Wait for auth state change to propagate through StreamBuilder
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation back to LoginScreen (not authenticated)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
