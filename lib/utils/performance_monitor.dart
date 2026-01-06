import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../config/debug_config.dart';

/// Performance monitoring utility for tracking operation timing and metrics
class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  
  /// Private constructor for singleton pattern
  PerformanceMonitor._internal();

  /// Singleton instance
  static PerformanceMonitor get instance {
    _instance ??= PerformanceMonitor._internal();
    return _instance!;
  }

  /// Queue to store performance logs with limited size
  final Queue<PerformanceLog> _performanceLogs = Queue<PerformanceLog>();

  /// Map to track ongoing operations
  final Map<String, OperationTimer> _activeOperations = <String, OperationTimer>{};

  /// Start timing an operation
  String startOperation(String operationName, [Map<String, dynamic>? parameters]) {
    if (!DebugConfig.instance.isOperationTimingEnabled) {
      return '';
    }

    final operationId = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
    final timer = OperationTimer(
      operationId: operationId,
      operationName: operationName,
      startTime: DateTime.now(),
      parameters: parameters,
    );

    _activeOperations[operationId] = timer;

    if (DebugConfig.instance.isVerboseLoggingEnabled) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] ⏱️ Starting operation: $operationName (ID: $operationId)');
      
      if (parameters != null && DebugConfig.instance.shouldLogOperationParameters) {
        debugPrint('  Parameters: $parameters');
      }
    }

    return operationId;
  }

  /// End timing an operation and log performance metrics
  void endOperation(String operationId, {bool success = true, String? error}) {
    if (!DebugConfig.instance.isOperationTimingEnabled || operationId.isEmpty) {
      return;
    }

    final timer = _activeOperations.remove(operationId);
    if (timer == null) {
      if (DebugConfig.instance.isVerboseLoggingEnabled) {
        debugPrint('⚠️ Warning: Attempted to end unknown operation: $operationId');
      }
      return;
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(timer.startTime);
    final durationMs = duration.inMilliseconds;

    // Create performance log entry
    final performanceLog = PerformanceLog(
      operationId: operationId,
      operationName: timer.operationName,
      startTime: timer.startTime,
      endTime: endTime,
      duration: duration,
      success: success,
      error: error,
      parameters: timer.parameters,
    );

    // Add to performance logs queue
    _addPerformanceLog(performanceLog);

    // Log performance information
    if (DebugConfig.instance.isVerboseLoggingEnabled) {
      final timestamp = endTime.toIso8601String();
      final statusIcon = success ? '✅' : '❌';
      debugPrint('[$timestamp] $statusIcon Completed operation: ${timer.operationName} (${durationMs}ms)');

      // Log performance warning if operation took too long
      if (durationMs > DebugConfig.instance.performanceWarningThreshold) {
        debugPrint('  ⚠️ Performance Warning: Operation took ${durationMs}ms (threshold: ${DebugConfig.instance.performanceWarningThreshold}ms)');
      }

      if (!success && error != null) {
        debugPrint('  Error: $error');
      }
    }

    // Log performance metrics if monitoring is enabled
    if (DebugConfig.instance.isPerformanceMonitoringEnabled) {
      _logPerformanceMetrics(performanceLog);
    }
  }

  /// Add performance log to queue with size limit
  void _addPerformanceLog(PerformanceLog log) {
    _performanceLogs.add(log);
    
    // Maintain queue size limit
    while (_performanceLogs.length > DebugConfig.instance.maxLogEntries) {
      _performanceLogs.removeFirst();
    }
  }

  /// Log detailed performance metrics
  void _logPerformanceMetrics(PerformanceLog log) {
    if (!DebugConfig.instance.isPerformanceMonitoringEnabled) {
      return;
    }

    final durationMs = log.duration.inMilliseconds;
    debugPrint('📊 Performance Metrics for ${log.operationName}:');
    debugPrint('  Duration: ${durationMs}ms');
    debugPrint('  Success: ${log.success}');
    debugPrint('  Start: ${log.startTime.toIso8601String()}');
    debugPrint('  End: ${log.endTime.toIso8601String()}');
    
    if (log.parameters != null && DebugConfig.instance.shouldLogOperationParameters) {
      debugPrint('  Parameters: ${log.parameters}');
    }
  }

  /// Get performance statistics for a specific operation
  OperationStats? getOperationStats(String operationName) {
    final logs = _performanceLogs.where((log) => log.operationName == operationName).toList();
    
    if (logs.isEmpty) {
      return null;
    }

    final durations = logs.map((log) => log.duration.inMilliseconds).toList();
    final successCount = logs.where((log) => log.success).length;
    final failureCount = logs.length - successCount;

    durations.sort();
    final minDuration = durations.first;
    final maxDuration = durations.last;
    final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
    final medianDuration = durations[durations.length ~/ 2];

    return OperationStats(
      operationName: operationName,
      totalOperations: logs.length,
      successCount: successCount,
      failureCount: failureCount,
      minDurationMs: minDuration,
      maxDurationMs: maxDuration,
      avgDurationMs: avgDuration.round(),
      medianDurationMs: medianDuration,
      lastExecuted: logs.last.endTime,
    );
  }

  /// Get all performance logs
  List<PerformanceLog> getAllLogs() {
    return List.unmodifiable(_performanceLogs);
  }

  /// Get recent performance logs (last N entries)
  List<PerformanceLog> getRecentLogs([int count = 10]) {
    final logs = _performanceLogs.toList();
    if (logs.length <= count) {
      return logs;
    }
    return logs.sublist(logs.length - count);
  }

  /// Clear all performance logs
  void clearLogs() {
    _performanceLogs.clear();
    if (DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('🗑️ Performance logs cleared');
    }
  }

  /// Get summary of all operations
  Map<String, OperationStats> getAllOperationStats() {
    final statsMap = <String, OperationStats>{};
    final operationNames = _performanceLogs.map((log) => log.operationName).toSet();
    
    for (final operationName in operationNames) {
      final stats = getOperationStats(operationName);
      if (stats != null) {
        statsMap[operationName] = stats;
      }
    }
    
    return statsMap;
  }

  /// Print performance summary to debug console
  void printPerformanceSummary() {
    if (!DebugConfig.instance.isPerformanceMonitoringEnabled) {
      debugPrint('Performance monitoring is disabled');
      return;
    }

    final stats = getAllOperationStats();
    if (stats.isEmpty) {
      debugPrint('📊 No performance data available');
      return;
    }

    debugPrint('📊 Performance Summary:');
    debugPrint('=' * 50);
    
    for (final stat in stats.values) {
      debugPrint('Operation: ${stat.operationName}');
      debugPrint('  Total: ${stat.totalOperations} | Success: ${stat.successCount} | Failures: ${stat.failureCount}');
      debugPrint('  Duration: Min=${stat.minDurationMs}ms | Max=${stat.maxDurationMs}ms | Avg=${stat.avgDurationMs}ms | Median=${stat.medianDurationMs}ms');
      debugPrint('  Last executed: ${stat.lastExecuted.toIso8601String()}');
      debugPrint('-' * 30);
    }
  }
}

/// Class to track timing for an ongoing operation
class OperationTimer {
  final String operationId;
  final String operationName;
  final DateTime startTime;
  final Map<String, dynamic>? parameters;

  OperationTimer({
    required this.operationId,
    required this.operationName,
    required this.startTime,
    this.parameters,
  });
}

/// Class to store performance log data
class PerformanceLog {
  final String operationId;
  final String operationName;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final bool success;
  final String? error;
  final Map<String, dynamic>? parameters;

  PerformanceLog({
    required this.operationId,
    required this.operationName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.success,
    this.error,
    this.parameters,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'operationName': operationName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'success': success,
      'error': error,
      'parameters': parameters,
    };
  }
}

/// Class to store operation statistics
class OperationStats {
  final String operationName;
  final int totalOperations;
  final int successCount;
  final int failureCount;
  final int minDurationMs;
  final int maxDurationMs;
  final int avgDurationMs;
  final int medianDurationMs;
  final DateTime lastExecuted;

  OperationStats({
    required this.operationName,
    required this.totalOperations,
    required this.successCount,
    required this.failureCount,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.avgDurationMs,
    required this.medianDurationMs,
    required this.lastExecuted,
  });

  double get successRate => totalOperations > 0 ? (successCount / totalOperations) * 100 : 0;
  double get failureRate => totalOperations > 0 ? (failureCount / totalOperations) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'operationName': operationName,
      'totalOperations': totalOperations,
      'successCount': successCount,
      'failureCount': failureCount,
      'successRate': successRate,
      'failureRate': failureRate,
      'minDurationMs': minDurationMs,
      'maxDurationMs': maxDurationMs,
      'avgDurationMs': avgDurationMs,
      'medianDurationMs': medianDurationMs,
      'lastExecuted': lastExecuted.toIso8601String(),
    };
  }
}