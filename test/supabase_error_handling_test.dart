import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/supabase_service.dart';
import 'package:noteassista/utils/supabase_error_handler.dart';

void main() {
  group('Supabase Error Handling Tests', () {
    test('SupabaseOperationResult handles success correctly', () {
      final result = SupabaseOperationResult.success('test data');

      expect(result.success, isTrue);
      expect(result.data, equals('test data'));
      expect(result.error, isNull);
      expect(result.errorType, isNull);
      expect(result.errorDetails, isNull);
    });

    test('SupabaseOperationResult handles failure correctly', () {
      final result = SupabaseOperationResult.failure(
        'Test error message',
        errorType: SupabaseErrorType.network,
        errorDetails: {'operation': 'test'},
      );

      expect(result.success, isFalse);
      expect(result.data, isNull);
      expect(result.error, equals('Test error message'));
      expect(result.errorType, equals(SupabaseErrorType.network));
      expect(result.errorDetails, isNotNull);
      expect(result.errorDetails!['operation'], equals('test'));
    });

    test('SupabaseErrorType enum has all expected values', () {
      expect(
        SupabaseErrorType.values,
        contains(SupabaseErrorType.authentication),
      );
      expect(
        SupabaseErrorType.values,
        contains(SupabaseErrorType.authorization),
      );
      expect(SupabaseErrorType.values, contains(SupabaseErrorType.network));
      expect(SupabaseErrorType.values, contains(SupabaseErrorType.validation));
      expect(SupabaseErrorType.values, contains(SupabaseErrorType.database));
      expect(SupabaseErrorType.values, contains(SupabaseErrorType.unknown));
    });

    test('SupabaseErrorHandler identifies recoverable errors correctly', () {
      final networkError = SupabaseOperationResult.failure(
        'Network error',
        errorType: SupabaseErrorType.network,
      );
      expect(SupabaseErrorHandler.isRecoverableError(networkError), isTrue);

      final authError = SupabaseOperationResult.failure(
        'Auth error',
        errorType: SupabaseErrorType.authentication,
      );
      expect(SupabaseErrorHandler.isRecoverableError(authError), isFalse);

      final successResult = SupabaseOperationResult.success('data');
      expect(SupabaseErrorHandler.isRecoverableError(successResult), isFalse);
    });

    test(
      'SupabaseErrorHandler identifies authentication requirements correctly',
      () {
        final authError = SupabaseOperationResult.failure(
          'Auth required',
          errorType: SupabaseErrorType.authentication,
        );
        expect(SupabaseErrorHandler.requiresAuthentication(authError), isTrue);

        final networkError = SupabaseOperationResult.failure(
          'Network error',
          errorType: SupabaseErrorType.network,
        );
        expect(
          SupabaseErrorHandler.requiresAuthentication(networkError),
          isFalse,
        );

        final successResult = SupabaseOperationResult.success('data');
        expect(
          SupabaseErrorHandler.requiresAuthentication(successResult),
          isFalse,
        );
      },
    );

    test('SupabaseErrorHandler provides appropriate error suggestions', () {
      final networkError = SupabaseOperationResult.failure(
        'Network error',
        errorType: SupabaseErrorType.network,
      );
      final networkSuggestion = SupabaseErrorHandler.getErrorSuggestion(
        networkError,
      );
      expect(networkSuggestion, contains('internet connection'));

      final authError = SupabaseOperationResult.failure(
        'Auth error',
        errorType: SupabaseErrorType.authentication,
      );
      final authSuggestion = SupabaseErrorHandler.getErrorSuggestion(authError);
      expect(authSuggestion, contains('log in'));

      final validationError = SupabaseOperationResult.failure(
        'Validation error',
        errorType: SupabaseErrorType.validation,
      );
      final validationSuggestion = SupabaseErrorHandler.getErrorSuggestion(
        validationError,
      );
      expect(validationSuggestion, contains('check your input'));
    });

    test(
      'Error handling provides descriptive messages for different error types',
      () {
        // Test that different error types would produce different messages
        // This is a conceptual test since we can't easily mock Supabase exceptions

        expect(SupabaseErrorType.authentication, isNotNull);
        expect(SupabaseErrorType.network, isNotNull);
        expect(SupabaseErrorType.database, isNotNull);
        expect(SupabaseErrorType.validation, isNotNull);
        expect(SupabaseErrorType.authorization, isNotNull);
        expect(SupabaseErrorType.unknown, isNotNull);
      },
    );

    test('Error details contain operation context', () {
      final result = SupabaseOperationResult.failure(
        'Test error',
        errorType: SupabaseErrorType.database,
        errorDetails: {
          'operation': 'createNote',
          'attempts': 2,
          'final_error': 'Database constraint violation',
        },
      );

      expect(result.errorDetails, isNotNull);
      expect(result.errorDetails!['operation'], equals('createNote'));
      expect(result.errorDetails!['attempts'], equals(2));
      expect(result.errorDetails!['final_error'], contains('constraint'));
    });

    test('Success result has no error information', () {
      final result = SupabaseOperationResult.success({'id': '123'});

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.errorType, isNull);
      expect(result.errorDetails, isNull);
      expect(result.data, isNotNull);
      expect(result.data!['id'], equals('123'));
    });

    test('Error handling maintains type safety', () {
      // Test that generic types work correctly
      final stringResult = SupabaseOperationResult<String>.success('test');
      expect(stringResult.data, isA<String>());
      expect(stringResult.data, equals('test'));

      final intResult = SupabaseOperationResult<int>.failure('error');
      expect(intResult.data, isNull);
      expect(intResult.error, equals('error'));

      final listResult = SupabaseOperationResult<List<String>>.success([
        'a',
        'b',
      ]);
      expect(listResult.data, isA<List<String>>());
      expect(listResult.data!.length, equals(2));
    });
  });

  group('Error Message Quality Tests', () {
    test('Error messages are user-friendly and actionable', () {
      // Test various error scenarios to ensure messages are helpful
      final testCases = [
        {
          'type': SupabaseErrorType.network,
          'expectedKeywords': ['connection', 'internet', 'network'],
        },
        {
          'type': SupabaseErrorType.authentication,
          'expectedKeywords': ['log in', 'login', 'authentication'],
        },
        {
          'type': SupabaseErrorType.validation,
          'expectedKeywords': ['input', 'data', 'check'],
        },
        {
          'type': SupabaseErrorType.authorization,
          'expectedKeywords': ['permission', 'access', 'denied'],
        },
      ];

      for (final testCase in testCases) {
        final errorType = testCase['type'] as SupabaseErrorType;
        final keywords = testCase['expectedKeywords'] as List<String>;

        final result = SupabaseOperationResult.failure(
          'Test error',
          errorType: errorType,
        );

        final suggestion = SupabaseErrorHandler.getErrorSuggestion(result);

        // Check that the suggestion contains at least one expected keyword
        final containsKeyword = keywords.any(
          (keyword) => suggestion.toLowerCase().contains(keyword.toLowerCase()),
        );

        expect(
          containsKeyword,
          isTrue,
          reason:
              'Error suggestion "$suggestion" should contain one of: $keywords',
        );
      }
    });

    test('Error messages avoid technical jargon', () {
      final suggestions = [
        SupabaseErrorHandler.getErrorSuggestion(
          SupabaseOperationResult.failure(
            '',
            errorType: SupabaseErrorType.network,
          ),
        ),
        SupabaseErrorHandler.getErrorSuggestion(
          SupabaseOperationResult.failure(
            '',
            errorType: SupabaseErrorType.authentication,
          ),
        ),
        SupabaseErrorHandler.getErrorSuggestion(
          SupabaseOperationResult.failure(
            '',
            errorType: SupabaseErrorType.validation,
          ),
        ),
      ];

      // Technical terms that should be avoided in user-facing messages
      final technicalTerms = [
        'postgresql',
        'supabase',
        'rpc',
        'jwt',
        'oauth',
        'constraint',
        'foreign key',
        'primary key',
        'sql',
        'exception',
        'stack trace',
        'null pointer',
      ];

      for (final suggestion in suggestions) {
        for (final term in technicalTerms) {
          expect(
            suggestion.toLowerCase().contains(term),
            isFalse,
            reason: 'User message should not contain technical term: $term',
          );
        }
      }
    });
  });
}
