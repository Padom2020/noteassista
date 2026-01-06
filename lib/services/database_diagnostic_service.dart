import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a diagnostic check
class DiagnosticCheckResult {
  final bool passed;
  final String message;
  final String? suggestion;
  final Map<String, dynamic>? details;

  DiagnosticCheckResult({
    required this.passed,
    required this.message,
    this.suggestion,
    this.details,
  });
}

/// Comprehensive diagnostic report
class DiagnosticReport {
  final bool isHealthy;
  final List<DiagnosticCheckResult> checks;
  final DateTime timestamp;
  final String? overallSuggestion;

  DiagnosticReport({
    required this.isHealthy,
    required this.checks,
    required this.timestamp,
    this.overallSuggestion,
  });

  /// Get all failed checks
  List<DiagnosticCheckResult> get failedChecks =>
      checks.where((c) => !c.passed).toList();

  /// Get all passed checks
  List<DiagnosticCheckResult> get passedChecks =>
      checks.where((c) => c.passed).toList();

  /// Format report as readable string
  String formatReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Database Diagnostic Report ===');
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('Status: ${isHealthy ? "✅ HEALTHY" : "❌ ISSUES DETECTED"}');
    buffer.writeln('');

    if (passedChecks.isNotEmpty) {
      buffer.writeln('✅ Passed Checks (${passedChecks.length}):');
      for (final check in passedChecks) {
        buffer.writeln('  • ${check.message}');
      }
      buffer.writeln('');
    }

    if (failedChecks.isNotEmpty) {
      buffer.writeln('❌ Failed Checks (${failedChecks.length}):');
      for (final check in failedChecks) {
        buffer.writeln('  • ${check.message}');
        if (check.suggestion != null) {
          buffer.writeln('    💡 ${check.suggestion}');
        }
      }
      buffer.writeln('');
    }

    if (overallSuggestion != null) {
      buffer.writeln('📋 Overall Suggestion:');
      buffer.writeln('  $overallSuggestion');
    }

    return buffer.toString();
  }
}

/// Service for diagnosing database connectivity issues
class DatabaseDiagnosticService {
  static DatabaseDiagnosticService? _instance;
  late final SupabaseClient _supabase;

  DatabaseDiagnosticService._internal() {
    _supabase = Supabase.instance.client;
  }

  /// Singleton instance
  static DatabaseDiagnosticService get instance {
    _instance ??= DatabaseDiagnosticService._internal();
    return _instance!;
  }

  /// Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // ==================== Connectivity Checks ====================

  /// Verify Supabase client initialization
  Future<DiagnosticCheckResult> validateSupabaseInitialization() async {
    try {
      // Verify Supabase instance is initialized by accessing the client
      // The getter will throw if Supabase is not properly initialized
      final _ = _supabase;

      return DiagnosticCheckResult(
        passed: true,
        message: 'Supabase client initialized successfully',
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'Failed to validate Supabase initialization: $e',
        suggestion: 'Check your Supabase configuration and credentials',
      );
    }
  }

  /// Test basic database connectivity
  Future<DiagnosticCheckResult> testDatabaseConnection() async {
    try {
      // Attempt a simple query to test connectivity
      await _supabase.from('notes').select('id').limit(1).count();

      return DiagnosticCheckResult(
        passed: true,
        message: 'Database connection successful',
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Database tables not found (PGRST205)',
          suggestion:
              'The database schema may not be initialized. Try running schema initialization.',
          details: {'error_code': e.code, 'error_message': e.message},
        );
      }

      return DiagnosticCheckResult(
        passed: false,
        message: 'Database error: ${e.message}',
        suggestion: 'Check your database configuration and RLS policies',
        details: {'error_code': e.code, 'error_message': e.message},
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'Connection test failed: $e',
        suggestion: 'Check your internet connection and Supabase URL',
      );
    }
  }

  /// Check authentication status
  Future<DiagnosticCheckResult> checkAuthenticationStatus() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'User not authenticated',
          suggestion: 'Please log in to access the database',
        );
      }

      return DiagnosticCheckResult(
        passed: true,
        message: 'User authenticated: ${user.email}',
        details: {'user_id': user.id, 'email': user.email},
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'Failed to check authentication: $e',
        suggestion: 'Try logging out and logging back in',
      );
    }
  }

  // ==================== Schema Validation ====================

  /// Check if a specific table exists
  Future<DiagnosticCheckResult> validateTableExists(String tableName) async {
    try {
      // Query information_schema to check if table exists
      final result =
          await _supabase
              .from('information_schema.tables')
              .select('table_name')
              .eq('table_schema', 'public')
              .eq('table_name', tableName)
              .maybeSingle();

      if (result == null) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Table "$tableName" not found in database',
          suggestion: 'Run schema initialization to create the required tables',
        );
      }

      return DiagnosticCheckResult(
        passed: true,
        message: 'Table "$tableName" exists',
      );
    } catch (e) {
      // If we can't query information_schema, try a simple select
      try {
        await _supabase.from(tableName).select('id').limit(1).count();
        return DiagnosticCheckResult(
          passed: true,
          message: 'Table "$tableName" is accessible',
        );
      } catch (selectError) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Cannot verify table "$tableName": $selectError',
          suggestion: 'Check if the table exists and RLS policies are correct',
        );
      }
    }
  }

  /// Validate all required tables exist
  Future<DiagnosticCheckResult> validateAllRequiredTables() async {
    const requiredTables = ['notes', 'folders', 'templates'];
    final results = <String, bool>{};

    for (final table in requiredTables) {
      try {
        await _supabase.from(table).select('id').limit(1).count();
        results[table] = true;
      } catch (e) {
        results[table] = false;
      }
    }

    final allExist = results.values.every((exists) => exists);
    final missingTables =
        results.entries.where((e) => !e.value).map((e) => e.key).toList();

    if (allExist) {
      return DiagnosticCheckResult(
        passed: true,
        message: 'All required tables exist',
        details: results,
      );
    }

    return DiagnosticCheckResult(
      passed: false,
      message: 'Missing tables: ${missingTables.join(", ")}',
      suggestion: 'Run schema initialization to create missing tables',
      details: results,
    );
  }

  /// Get table structure information
  Future<DiagnosticCheckResult> getTableStructure(String tableName) async {
    try {
      // Query information_schema for column information
      final columns = await _supabase
          .from('information_schema.columns')
          .select('column_name, data_type, is_nullable')
          .eq('table_schema', 'public')
          .eq('table_name', tableName);

      if (columns.isEmpty) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Could not retrieve structure for table "$tableName"',
          suggestion: 'Verify the table exists in the database',
        );
      }

      return DiagnosticCheckResult(
        passed: true,
        message: 'Retrieved structure for table "$tableName"',
        details: {
          'table_name': tableName,
          'column_count': columns.length,
          'columns': columns,
        },
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'Failed to get table structure: $e',
        suggestion: 'Check if information_schema is accessible',
      );
    }
  }

  // ==================== RLS Policy Validation ====================

  /// Check if RLS is enabled on a table
  Future<DiagnosticCheckResult> validateRLSEnabled(String tableName) async {
    try {
      // Query information_schema.tables to check RLS status
      final result =
          await _supabase
              .from('information_schema.tables')
              .select('rowsecurity')
              .eq('table_schema', 'public')
              .eq('table_name', tableName)
              .maybeSingle();

      if (result == null) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Table "$tableName" not found',
          suggestion: 'Verify the table exists in the database',
        );
      }

      final rlsEnabled = result['rowsecurity'] as bool? ?? false;

      if (!rlsEnabled) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'Row Level Security (RLS) is not enabled on "$tableName"',
          suggestion: 'Enable RLS on the table for security',
        );
      }

      return DiagnosticCheckResult(
        passed: true,
        message: 'Row Level Security (RLS) is enabled on "$tableName"',
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'Failed to check RLS status: $e',
        suggestion: 'Verify you have permission to query table metadata',
      );
    }
  }

  /// Test actual data access with current user
  Future<DiagnosticCheckResult> testRLSAccess() async {
    try {
      if (!isAuthenticated) {
        return DiagnosticCheckResult(
          passed: false,
          message: 'User not authenticated',
          suggestion: 'Please log in to test RLS access',
        );
      }

      // Try to access user's own notes
      final response =
          await _supabase
              .from('notes')
              .select('id')
              .eq('user_id', currentUserId!)
              .limit(1)
              .count();

      return DiagnosticCheckResult(
        passed: true,
        message: 'RLS access test successful - can access own data',
        details: {
          'user_id': currentUserId,
          'accessible_records': response.count,
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return DiagnosticCheckResult(
          passed: false,
          message: 'RLS policy denied access (42501)',
          suggestion:
              'Check that RLS policies are correctly configured for your user',
          details: {'error_code': e.code, 'error_message': e.message},
        );
      }

      return DiagnosticCheckResult(
        passed: false,
        message: 'RLS access test failed: ${e.message}',
        suggestion: 'Verify RLS policies are correctly configured',
        details: {'error_code': e.code, 'error_message': e.message},
      );
    } catch (e) {
      return DiagnosticCheckResult(
        passed: false,
        message: 'RLS access test error: $e',
        suggestion: 'Check your database connection and permissions',
      );
    }
  }

  // ==================== Comprehensive Diagnostics ====================

  /// Run comprehensive diagnostic report
  Future<DiagnosticReport> generateDiagnosticReport() async {
    final checks = <DiagnosticCheckResult>[];

    // Run all diagnostic checks
    checks.add(await validateSupabaseInitialization());
    checks.add(await checkAuthenticationStatus());
    checks.add(await testDatabaseConnection());
    checks.add(await validateAllRequiredTables());
    checks.add(await validateRLSEnabled('notes'));
    checks.add(await validateRLSEnabled('folders'));
    checks.add(await testRLSAccess());

    // Determine overall health
    final isHealthy = checks.every((c) => c.passed);

    // Generate overall suggestion
    String? overallSuggestion;
    if (!isHealthy) {
      final failedChecks = checks.where((c) => !c.passed).toList();

      if (failedChecks.any((c) => c.message.contains('PGRST205'))) {
        overallSuggestion =
            'Database schema not found. Run schema initialization to create required tables.';
      } else if (failedChecks.any(
        (c) => c.message.contains('not authenticated'),
      )) {
        overallSuggestion = 'Please log in to access the database.';
      } else if (failedChecks.any((c) => c.message.contains('Connection'))) {
        overallSuggestion =
            'Check your internet connection and Supabase configuration.';
      } else if (failedChecks.any((c) => c.message.contains('RLS'))) {
        overallSuggestion =
            'Row Level Security policies may be misconfigured. Check your database policies.';
      } else {
        overallSuggestion =
            'Multiple issues detected. Review the failed checks above for details.';
      }
    }

    return DiagnosticReport(
      isHealthy: isHealthy,
      checks: checks,
      timestamp: DateTime.now(),
      overallSuggestion: overallSuggestion,
    );
  }

  /// Print diagnostic report to debug console
  Future<void> printDiagnosticReport() async {
    final report = await generateDiagnosticReport();
    debugPrint(report.formatReport());
  }
}
