import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/auth_service.dart';
import 'package:noteassista/models/unified_user.dart';
import 'package:noteassista/utils/user_extensions.dart';
import 'package:noteassista/utils/error_handler.dart';

void main() {
  group('Error Handling Tests', () {
    test('AuthService handles null user gracefully', () {
      final authService = AuthService();

      // Should not throw when accessing currentUser
      expect(() => authService.currentUser, returnsNormally);

      // Should return null when no user is authenticated
      expect(authService.currentUser, isNull);
    });

    test('User extensions handle null user safely', () {
      const UnifiedUser? nullUser = null;

      // Should not throw when accessing properties on null user
      expect(() => nullUser.safeUid, returnsNormally);
      expect(() => nullUser.safeEmail, returnsNormally);
      expect(() => nullUser.isAuthenticated, returnsNormally);

      // Should return appropriate values for null user
      expect(nullUser.safeUid, isNull);
      expect(nullUser.safeEmail, isNull);
      expect(nullUser.isAuthenticated, isFalse);
      expect(nullUser.isSafeAnonymous, isTrue);
    });

    test('User extensions provide fallback values', () {
      const UnifiedUser? nullUser = null;

      // Should return fallback values when user is null
      expect(nullUser.getUidOrFallback('fallback-uid'), equals('fallback-uid'));
      expect(
        nullUser.getEmailOrFallback('fallback@example.com'),
        equals('fallback@example.com'),
      );
      expect(
        nullUser.getDisplayNameOrFallback('Fallback Name'),
        equals('Fallback Name'),
      );
    });

    test('User extensions safely convert to map', () {
      const UnifiedUser? nullUser = null;

      // Should return empty map for null user
      final map = nullUser.safeToMap();
      expect(map, isA<Map<String, dynamic>>());
      expect(map.isEmpty, isTrue);
    });

    test('ErrorHandler provides user-friendly auth messages', () {
      // Test various auth error scenarios
      expect(
        ErrorHandler.getAuthErrorMessage('Invalid login credentials'),
        equals('Invalid email or password'),
      );

      expect(
        ErrorHandler.getAuthErrorMessage('Email not confirmed'),
        equals('Please check your email and confirm your account'),
      );

      expect(
        ErrorHandler.getAuthErrorMessage('User already registered'),
        equals('An account with this email already exists'),
      );

      expect(
        ErrorHandler.getAuthErrorMessage(null),
        equals('An unknown authentication error occurred'),
      );
    });

    test('ErrorHandler safely executes operations', () async {
      // Test successful operation
      final result = await ErrorHandler.safeExecute(
        'test',
        () async => 'success',
        fallbackValue: 'fallback',
      );
      expect(result, equals('success'));

      // Test failed operation with fallback
      final failedResult = await ErrorHandler.safeExecute(
        'test',
        () async => throw Exception('test error'),
        fallbackValue: 'fallback',
        logErrors: false, // Don't log during test
      );
      expect(failedResult, equals('fallback'));
    });

    test('AuthServiceException provides proper error information', () {
      const exception = AuthServiceException(
        'Test error message',
        code: 'TEST_CODE',
      );

      expect(exception.message, equals('Test error message'));
      expect(exception.code, equals('TEST_CODE'));
      expect(exception.toString(), contains('Test error message'));
      expect(exception.toString(), contains('TEST_CODE'));
    });
  });
}
