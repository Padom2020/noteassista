import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Specialized error handler for Supabase operations
/// Provides user-friendly error messages and recovery suggestions
class SupabaseErrorHandler {
  /// Show error message to user with appropriate action buttons
  static void showErrorDialog(
    BuildContext context,
    SupabaseOperationResult result, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) {
    if (!context.mounted || result.success) return;

    final errorType = result.errorType ?? SupabaseErrorType.unknown;
    final defaultTitle = _getErrorTitle(errorType);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title ?? defaultTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.error ?? 'An unknown error occurred'),
                if (errorType == SupabaseErrorType.network) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Troubleshooting tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Check your internet connection'),
                  const Text('• Try switching between WiFi and mobile data'),
                  const Text('• Restart the app if the problem persists'),
                ],
                if (errorType == SupabaseErrorType.authentication) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'What you can do:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Log out and log back in'),
                  const Text('• Check your account status'),
                  const Text('• Contact support if the issue continues'),
                ],
              ],
            ),
            actions: [
              if (onCancel != null)
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              if (errorType == SupabaseErrorType.network && onRetry != null)
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              if (errorType == SupabaseErrorType.authentication)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to login screen
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text('Log In'),
                ),
              if (errorType != SupabaseErrorType.network &&
                  errorType != SupabaseErrorType.authentication)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
            ],
          ),
    );
  }

  /// Show error as a snackbar with action button
  static void showErrorSnackBar(
    BuildContext context,
    SupabaseOperationResult result, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 6),
  }) {
    if (!context.mounted || result.success) return;

    final errorType = result.errorType ?? SupabaseErrorType.unknown;
    final message = result.error ?? 'An unknown error occurred';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _getErrorColor(errorType),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: _getSnackBarAction(context, errorType, onRetry),
      ),
    );
  }

  /// Get appropriate error title based on error type
  static String _getErrorTitle(SupabaseErrorType errorType) {
    return switch (errorType) {
      SupabaseErrorType.authentication => 'Authentication Required',
      SupabaseErrorType.authorization => 'Access Denied',
      SupabaseErrorType.network => 'Connection Problem',
      SupabaseErrorType.validation => 'Invalid Data',
      SupabaseErrorType.database => 'Data Error',
      SupabaseErrorType.unknown => 'Error',
    };
  }

  /// Get appropriate color for error type
  static Color _getErrorColor(SupabaseErrorType errorType) {
    return switch (errorType) {
      SupabaseErrorType.authentication => Colors.orange,
      SupabaseErrorType.authorization => Colors.red,
      SupabaseErrorType.network => Colors.blue,
      SupabaseErrorType.validation => Colors.amber,
      SupabaseErrorType.database => Colors.deepOrange,
      SupabaseErrorType.unknown => Colors.grey,
    };
  }

  /// Get appropriate action for snackbar based on error type
  static SnackBarAction? _getSnackBarAction(
    BuildContext context,
    SupabaseErrorType errorType,
    VoidCallback? onRetry,
  ) {
    return switch (errorType) {
      SupabaseErrorType.network when onRetry != null => SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
      SupabaseErrorType.authentication => SnackBarAction(
        label: 'Log In',
        textColor: Colors.white,
        onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
      ),
      _ => SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    };
  }

  /// Log detailed error information for debugging
  static void logDetailedError(
    String operation,
    SupabaseOperationResult result,
  ) {
    if (!kDebugMode || result.success) return;

    final timestamp = DateTime.now().toIso8601String();
    final errorType = result.errorType ?? SupabaseErrorType.unknown;

    final logMessage = '''
========== SUPABASE OPERATION ERROR ==========
Timestamp: $timestamp
Operation: $operation
Error Type: $errorType
Error Message: ${result.error}
Error Details: ${result.errorDetails}
============================================''';

    debugPrint(logMessage);
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverableError(SupabaseOperationResult result) {
    if (result.success) return false;

    final errorType = result.errorType ?? SupabaseErrorType.unknown;
    return errorType == SupabaseErrorType.network ||
        errorType == SupabaseErrorType.unknown;
  }

  /// Check if error requires authentication
  static bool requiresAuthentication(SupabaseOperationResult result) {
    if (result.success) return false;

    final errorType = result.errorType ?? SupabaseErrorType.unknown;
    return errorType == SupabaseErrorType.authentication;
  }

  /// Get user-friendly suggestion based on error type
  static String getErrorSuggestion(SupabaseOperationResult result) {
    if (result.success) return '';

    final errorType = result.errorType ?? SupabaseErrorType.unknown;

    return switch (errorType) {
      SupabaseErrorType.network =>
        'Check your internet connection and try again.',
      SupabaseErrorType.authentication =>
        'Please log in to continue using the app.',
      SupabaseErrorType.authorization =>
        'You don\'t have permission for this action. Contact support if needed.',
      SupabaseErrorType.validation => 'Please check your input and try again.',
      SupabaseErrorType.database =>
        'A data error occurred. Please try again or contact support.',
      SupabaseErrorType.unknown =>
        'An unexpected error occurred. Please try again.',
    };
  }

  /// Create a standardized error widget for UI
  static Widget buildErrorWidget(
    SupabaseOperationResult result, {
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    if (result.success) return const SizedBox.shrink();

    final errorType = result.errorType ?? SupabaseErrorType.unknown;
    final message = customMessage ?? result.error ?? 'An error occurred';
    final suggestion = getErrorSuggestion(result);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getErrorColor(errorType).withValues(alpha: 0.1),
        border: Border.all(color: _getErrorColor(errorType)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getErrorIcon(errorType),
                color: _getErrorColor(errorType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getErrorTitle(errorType),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getErrorColor(errorType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              suggestion,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          if (onRetry != null && isRecoverableError(result)) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getErrorColor(errorType),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get appropriate icon for error type
  static IconData _getErrorIcon(SupabaseErrorType errorType) {
    return switch (errorType) {
      SupabaseErrorType.authentication => Icons.login,
      SupabaseErrorType.authorization => Icons.lock,
      SupabaseErrorType.network => Icons.wifi_off,
      SupabaseErrorType.validation => Icons.warning,
      SupabaseErrorType.database => Icons.storage,
      SupabaseErrorType.unknown => Icons.error,
    };
  }
}
