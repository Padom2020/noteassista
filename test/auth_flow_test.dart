import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:noteassista/firebase_options.dart';
import 'package:noteassista/screens/auth_wrapper.dart';
import 'package:noteassista/screens/login_screen.dart';
import 'package:noteassista/screens/home_screen.dart';
import 'package:noteassista/screens/add_note_screen.dart';
import 'package:noteassista/screens/edit_note_screen.dart';
import 'package:noteassista/services/firestore_service.dart';
import 'package:noteassista/models/note_model.dart';

void main() {
  // Setup Firebase for testing
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

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

  group('Authentication Flow Tests', () {
    testWidgets('Signup → Auto-login → HomeScreen navigation', (
      WidgetTester tester,
    ) async {
      // Initialize Firebase for this test
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {'/home': (context) => const HomeScreen()},
        ),
      );
      await tester.pumpAndSettle();

      // Verify we start at LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Login'), findsWidgets);

      // Navigate to SignupScreen
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      // Verify we're on SignupScreen
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign Up'), findsWidgets);

      // Generate unique email for this test
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_$timestamp@example.com';
      final testPassword = 'password123';

      // Fill in signup form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        testEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        testPassword,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        testPassword,
      );
      await tester.pumpAndSettle();

      // Submit signup form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));

      // Wait for async operations and navigation
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation to HomeScreen after successful signup
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      expect(user?.email, testEmail);
    });

    testWidgets('Login with valid credentials', (WidgetTester tester) async {
      // Initialize Firebase for this test
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase already initialized
        debugPrint('Firebase already initialized: $e');
      }

      // First, create a test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_login_$timestamp@example.com';
      final testPassword = 'password123';

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error creating test user: $e');
      }

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {'/home': (context) => const HomeScreen()},
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're on LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Fill in login form with valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        testEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        testPassword,
      );
      await tester.pumpAndSettle();

      // Submit login form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      // Wait for async operations and navigation
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      expect(user?.email, testEmail);
    });

    testWidgets('Login with invalid credentials shows error', (
      WidgetTester tester,
    ) async {
      // Initialize Firebase for this test
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase already initialized
        debugPrint('Firebase already initialized: $e');
      }

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {'/home': (context) => const HomeScreen()},
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're on LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Fill in login form with invalid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpassword',
      );
      await tester.pumpAndSettle();

      // Submit login form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify error message is displayed
      expect(
        find.text('Invalid email or password'),
        findsOneWidget,
        reason: 'Error message should be displayed for invalid credentials',
      );

      // Verify we're still on LoginScreen (no navigation occurred)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);

      // Verify user is NOT authenticated
      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNull);
    });
  });

  group('Note CRUD Operations Tests', () {
    late String testUserId;
    late FirestoreService firestoreService;

    // Helper function to create a test user and login
    Future<void> setupTestUser(WidgetTester tester) async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase already initialized: $e');
      }

      // Create test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_notes_$timestamp@example.com';
      final testPassword = 'password123';

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          );
      testUserId = userCredential.user!.uid;

      // Initialize FirestoreService after Firebase is initialized
      firestoreService = FirestoreService();

      // Create user document in Firestore
      await firestoreService.createUser(testUserId, testEmail);
    }

    testWidgets('Create note → verify appears in list', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
          routes: {'/add': (context) => const AddNoteScreen()},
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're on HomeScreen
      expect(find.text('NoteAssista'), findsOneWidget);
      expect(find.text('No active notes yet'), findsOneWidget);

      // Tap FAB to navigate to AddNoteScreen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify we're on AddNoteScreen
      expect(find.text('Add Note'), findsOneWidget);
      expect(find.byType(AddNoteScreen), findsOneWidget);

      // Fill in note form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Note Title',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Test Note Description',
      );
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Note'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation back to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify note appears in the list
      expect(find.text('Test Note Title'), findsOneWidget);
      expect(find.text('Test Note Description'), findsOneWidget);
      expect(find.text('No active notes yet'), findsNothing);
    });

    testWidgets('Edit note → verify changes persist', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Create a test note first
      await firestoreService.createNote(
        testUserId,
        NoteModel(
          id: '',
          title: 'Original Title',
          description: 'Original Description',
          timestamp: '12:00',
          categoryImageIndex: 0,
          isDone: false,
        ),
      );

      // Build the app
      await tester.pumpWidget(MaterialApp(home: const HomeScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify original note is displayed
      expect(find.text('Original Title'), findsOneWidget);
      expect(find.text('Original Description'), findsOneWidget);

      // Tap on note to edit
      await tester.tap(find.text('Original Title'));
      await tester.pumpAndSettle();

      // Verify we're on EditNoteScreen
      expect(find.text('Edit Note'), findsOneWidget);
      expect(find.byType(EditNoteScreen), findsOneWidget);

      // Verify form is pre-populated
      expect(find.text('Original Title'), findsOneWidget);
      expect(find.text('Original Description'), findsOneWidget);

      // Update note fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Updated Title',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Updated Description',
      );
      await tester.pumpAndSettle();

      // Submit update
      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Note'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation back to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify updated note appears in the list
      expect(find.text('Updated Title'), findsOneWidget);
      expect(find.text('Updated Description'), findsOneWidget);
      expect(find.text('Original Title'), findsNothing);
      expect(find.text('Original Description'), findsNothing);
    });

    testWidgets('Delete note → verify removal from list', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Create a test note first
      await firestoreService.createNote(
        testUserId,
        NoteModel(
          id: '',
          title: 'Note to Delete',
          description: 'This note will be deleted',
          timestamp: '12:00',
          categoryImageIndex: 0,
          isDone: false,
        ),
      );

      // Build the app
      await tester.pumpWidget(MaterialApp(home: const HomeScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify note is displayed
      expect(find.text('Note to Delete'), findsOneWidget);
      expect(find.text('This note will be deleted'), findsOneWidget);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify note is removed from list
      expect(find.text('Note to Delete'), findsNothing);
      expect(find.text('This note will be deleted'), findsNothing);
      expect(find.text('No active notes yet'), findsOneWidget);
    });

    testWidgets('Toggle completion → verify section change', (
      WidgetTester tester,
    ) async {
      await setupTestUser(tester);

      // Create a test note first
      await firestoreService.createNote(
        testUserId,
        NoteModel(
          id: '',
          title: 'Task to Complete',
          description: 'This task will be marked as done',
          timestamp: '12:00',
          categoryImageIndex: 0,
          isDone: false,
        ),
      );

      // Build the app
      await tester.pumpWidget(MaterialApp(home: const HomeScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify note is in "Not Done" section
      expect(find.text('Task to Complete'), findsOneWidget);
      expect(find.text('No active notes yet'), findsNothing);
      expect(find.text('No completed notes yet'), findsOneWidget);

      // Find and tap the checkbox
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsWidgets);

      await tester.tap(checkboxFinder.first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify note moved to "Done" section
      // Note should still be visible but in the done section
      expect(find.text('Task to Complete'), findsOneWidget);
      expect(find.text('No active notes yet'), findsOneWidget);
      expect(find.text('No completed notes yet'), findsNothing);
    });
  });
}
