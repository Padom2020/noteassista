import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:noteassista/main.dart' as app;
import 'package:noteassista/screens/login_screen.dart';
import 'package:noteassista/screens/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Tests', () {
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

    testWidgets('Signup → Auto-login → HomeScreen navigation', (
      WidgetTester tester,
    ) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify we start at LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);

      // Navigate to SignupScreen
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      // Verify we're on SignupScreen
      expect(find.text('Create Account'), findsOneWidget);

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
        find.widgetWithText(TextFormField, 'Password').first,
        testPassword,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        testPassword,
      );
      await tester.pumpAndSettle();

      // Submit signup form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation to HomeScreen after successful signup
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify user is authenticated
      final user = Supabase.instance.client.auth.currentUser;
      expect(user, isNotNull);
      expect(user?.email, testEmail);
    });

    testWidgets('Login with valid credentials', (WidgetTester tester) async {
      // First, create a test user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_login_$timestamp@example.com';
      final testPassword = 'password123';

      await Supabase.instance.client.auth.signUp(
        email: testEmail,
        password: testPassword,
      );
      await Supabase.instance.client.auth.signOut();

      // Start the app
      app.main();
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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify navigation to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NoteAssista'), findsOneWidget);

      // Verify user is authenticated
      final user = Supabase.instance.client.auth.currentUser;
      expect(user, isNotNull);
      expect(user?.email, testEmail);
    });

    testWidgets('Login with invalid credentials shows error', (
      WidgetTester tester,
    ) async {
      // Start the app
      app.main();
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
      final user = Supabase.instance.client.auth.currentUser;
      expect(user, isNull);
    });
  });
}
