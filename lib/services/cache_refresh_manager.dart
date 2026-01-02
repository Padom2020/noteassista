import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a cache refresh operation
class CacheRefreshResult {
  final bool success;
  final String message;
  final int attemptCount;
  final Duration totalDuration;

  CacheRefreshResult({
    required this.success,
    required this.message,
    required this.attemptCount,
    required this.totalDuration,
  });
}

/// Service for managing PostgREST schema cache refresh
class CacheRefreshManager {
  static CacheRefreshManager? _instance;
  late final SupabaseClient _supabase;

  // Configuration
  static const int maxRetries = 3;
  static const Duration initialDelay = Duration(milliseconds: 500);
  static const Duration maxDelay = Duration(seconds: 5);

  CacheRefreshManager._internal() {
    _supabase = Supabase.instance.client;
  }

  /// Singleton instance
  static CacheRefreshManager get instance {
    _instance ??= CacheRefreshManager._internal();
    return _instance!;
  }

  // ==================== Cache Refresh ====================

  /// Attempt to refresh PostgREST schema cache
  Future<CacheRefreshResult> refreshSchemaCache() async {
    final startTime = DateTime.now();
    int attemptCount = 0;

    try {
      debugPrint('🔄 Starting schema cache refresh...');

      // Try to refresh cache by making a request that forces cache validation
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        attemptCount = attempt + 1;

        try {
          // Make a simple query to trigger cache refresh
          await _supabase.from('notes').select('id').limit(1).count();

          final duration = DateTime.now().difference(startTime);
          debugPrint(
            '✅ Schema cache refresh successful (attempt $attemptCount)',
          );

          return CacheRefreshResult(
            success: true,
            message: 'Schema cache refreshed successfully',
            attemptCount: attemptCount,
            totalDuration: duration,
          );
        } catch (e) {
          debugPrint('⚠️ Cache refresh attempt $attemptCount failed: $e');

          if (attempt < maxRetries) {
            // Calculate exponential backoff delay
            final delay = _calculateBackoffDelay(attempt);
            debugPrint('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
            await Future.delayed(delay);
          }
        }
      }

      // All retries failed
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ Schema cache refresh failed after $attemptCount attempts');

      return CacheRefreshResult(
        success: false,
        message: 'Failed to refresh schema cache after $attemptCount attempts',
        attemptCount: attemptCount,
        totalDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ Schema cache refresh error: $e');

      return CacheRefreshResult(
        success: false,
        message: 'Schema cache refresh error: $e',
        attemptCount: attemptCount,
        totalDuration: duration,
      );
    }
  }

  /// Wait for schema cache to be ready
  Future<bool> waitForCacheRefresh({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        // Try a simple query to check if cache is ready
        await _supabase.from('notes').select('id').limit(1).count();
        debugPrint('✅ Schema cache is ready');
        return true;
      } catch (e) {
        debugPrint('⏳ Waiting for schema cache... ($e)');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    debugPrint('❌ Schema cache not ready after timeout');
    return false;
  }

  /// Retry an operation with cache refresh on failure
  Future<T> retryWithCacheRefresh<T>(
    Future<T> Function() operation, {
    String operationName = 'operation',
  }) async {
    try {
      debugPrint('🔄 Attempting $operationName...');
      return await operation();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint('⚠️ PGRST205 error detected. Attempting cache refresh...');

        // Try to refresh cache
        final refreshResult = await refreshSchemaCache();

        if (refreshResult.success) {
          debugPrint('🔄 Retrying $operationName after cache refresh...');
          return await operation();
        } else {
          debugPrint('❌ Cache refresh failed, rethrowing original error');
          rethrow;
        }
      }

      // Not a cache error, rethrow
      rethrow;
    }
  }

  // ==================== Helper Methods ====================

  /// Calculate exponential backoff delay
  Duration _calculateBackoffDelay(int attemptNumber) {
    // Exponential backoff: 500ms, 1s, 2s, etc.
    final exponentialDelay = initialDelay * (1 << attemptNumber);

    // Cap at maxDelay
    if (exponentialDelay > maxDelay) {
      return maxDelay;
    }

    return exponentialDelay;
  }

  /// Get cache refresh configuration
  Map<String, dynamic> getConfiguration() {
    return {
      'maxRetries': maxRetries,
      'initialDelay': initialDelay.inMilliseconds,
      'maxDelay': maxDelay.inMilliseconds,
    };
  }
}
