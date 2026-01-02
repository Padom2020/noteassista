import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized error handling and logging utility
class ErrorHandler {
  static const String _logPrefix = 'ErrorHandler';

  /// Log an error with context information
  static void logError(
    String context,
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMessage = '$_logPrefix [$timestamp] [$context]: $error';

    debugPrint(errorMessage);

    if (stackTrace != null && kDebugMode) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Log a warning message
  static void logWarning(String context, String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_logPrefix WARNING [$timestamp] [$context]: $message');
  }

  /// Log an info message
  static void logInfo(String context, String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_logPrefix INFO [$timestamp] [$context]: $message');
  }

  /// Show a user-friendly error message in a SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show a user-friendly warning message in a SnackBar
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showErrorSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.orange,
    );
  }

  /// Show a success message in a SnackBar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showErrorSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.green,
    );
  }

  /// Handle authentication errors and return user-friendly messages
  static String getAuthErrorMessage(dynamic error) {
    if (error == null) return 'An unknown authentication error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid login credentials')) {
      return 'Invalid email or password';
    } else if (errorString.contains('email not confirmed')) {
      return 'Please check your email and confirm your account';
    } else if (errorString.contains('user already registered')) {
      return 'An account with this email already exists';
    } else if (errorString.contains(
      'password should be at least 6 characters',
    )) {
      return 'Password must be at least 6 characters long';
    } else if (errorString.contains('signup disabled')) {
      return 'New account registration is currently disabled';
    } else if (errorString.contains('email rate limit exceeded')) {
      return 'Too many requests. Please wait before trying again';
    } else if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again';
    } else {
      return 'Authentication error: ${error.toString()}';
    }
  }

  /// Handle general application errors
  static String getGeneralErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again';
    } else if (errorString.contains('permission')) {
      return 'Permission denied. Please check your access rights';
    } else if (errorString.contains('not found')) {
      return 'The requested resource was not found';
    } else {
      return 'An error occurred: ${error.toString()}';
    }
  }

  /// Safely execute an async operation with error handling
  static Future<T?> safeExecute<T>(
    String context,
    Future<T> Function() operation, {
    T? fallbackValue,
    bool logErrors = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (logErrors) {
        logError(context, error, stackTrace);
      }
      return fallbackValue;
    }
  }

  /// Safely execute a synchronous operation with error handling
  static T? safeExecuteSync<T>(
    String context,
    T Function() operation, {
    T? fallbackValue,
    bool logErrors = true,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      if (logErrors) {
        logError(context, error, stackTrace);
      }
      return fallbackValue;
    }
  }
}
