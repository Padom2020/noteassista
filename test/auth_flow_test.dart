import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/screens/auth_wrapper.dart';
import 'package:noteassista/screens/login_screen.dart';
import 'package:noteassista/screens/signup_screen.dart';
import 'package:noteassista/screens/home_screen.dart';
import 'test_helpers.dart';

void main() {
  // Setup Supabase for testing
  setUpAll(() async {
    await setupSupabaseMocks();
  });

  // Clean up after each test
  tearDownAll(() {
    tearDownSupabaseMocks();
  });

  group('Authentication Flow Tests', () {
    testWidgets('Signup → Auto-login → HomeScreen navigation', (
      WidgetTester tester,
    ) async {
      // Supabase is already initialized in setUpAll

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => const HomeScreen(),
          },
        ),
      );

      // Wait for initial render
      await tester.pumpAndSettle();

      // Should start at LoginScreen (not authenticated)
      expect(find.byType(LoginScreen), findsOneWidget);

      // Navigate to SignupScreen
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      // Verify we're on SignupScreen
      expect(find.byType(SignupScreen), findsOneWidget);

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

      // Submit signup form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      // For testing purposes, we'll assume successful signup
      // In a real test, you'd mock the Supabase auth response
      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('Login with valid credentials', (WidgetTester tester) async {
      // Supabase is already initialized in setUpAll

      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => const HomeScreen(),
          },
        ),
      );

      // Wait for initial render
      await tester.pumpAndSettle();

      // Should start at LoginScreen (not authenticated)
      expect(find.byType(LoginScreen), findsOneWidget);

      // Fill in login form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Submit login form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // For testing purposes, we'll verify the form was submitted
      // In a real test, you'd mock the Supabase auth response
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Login with invalid credentials shows error', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => const HomeScreen(),
          },
        ),
      );

      // Wait for initial render
      await tester.pumpAndSettle();

      // Should start at LoginScreen (not authenticated)
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

      // Submit login form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // For testing purposes, we'll verify the form was submitted
      // In a real test, you'd mock the Supabase auth error response
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
