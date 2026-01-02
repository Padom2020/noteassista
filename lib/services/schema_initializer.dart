import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a schema initialization operation
class SchemaInitializationResult {
  final bool success;
  final String message;
  final List<String> createdTables;
  final List<String> errors;

  SchemaInitializationResult({
    required this.success,
    required this.message,
    required this.createdTables,
    required this.errors,
  });
}

/// Service for initializing and managing database schema
class SchemaInitializer {
  static SchemaInitializer? _instance;
  late final SupabaseClient _supabase;

  SchemaInitializer._internal() {
    _supabase = Supabase.instance.client;
  }

  /// Singleton instance
  static SchemaInitializer get instance {
    _instance ??= SchemaInitializer._internal();
    return _instance!;
  }

  /// Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ==================== Schema Creation ====================

  /// Initialize complete database schema
  /// Note: This requires running the SQL schema from supabase_schema.sql in the Supabase dashboard
  Future<SchemaInitializationResult> initializeSchema() async {
    final createdTables = <String>[];
    final errors = <String>[];

    try {
      debugPrint('🔍 Checking database schema...');

      // Check if tables exist
      final tablesExist = await _checkTablesExist();

      if (tablesExist) {
        debugPrint('✅ Database schema already exists');
        return SchemaInitializationResult(
          success: true,
          message: 'Database schema already initialized',
          createdTables: [
            'notes',
            'folders',
            'templates',
            'daily_note_preferences',
          ],
          errors: [],
        );
      }

      debugPrint('⚠️ Database schema not found');
      debugPrint('📋 To initialize the schema, please:');
      debugPrint('1. Go to your Supabase dashboard');
      debugPrint('2. Open the SQL editor');
      debugPrint('3. Copy and paste the contents of supabase_schema.sql');
      debugPrint('4. Execute the SQL');

      return SchemaInitializationResult(
        success: false,
        message:
            'Database schema not initialized. Please run the SQL schema from supabase_schema.sql in your Supabase dashboard.',
        createdTables: [],
        errors: [
          'Schema not found. Manual initialization required via Supabase dashboard.',
        ],
      );
    } catch (e) {
      debugPrint('❌ Schema initialization error: $e');
      return SchemaInitializationResult(
        success: false,
        message: 'Schema initialization error: $e',
        createdTables: createdTables,
        errors: [...errors, e.toString()],
      );
    }
  }

  /// Check if all required tables exist
  Future<bool> _checkTablesExist() async {
    const requiredTables = ['notes', 'folders', 'templates'];

    for (final table in requiredTables) {
      try {
        await _supabase.from(table).select('id').limit(1).count();
      } catch (e) {
        debugPrint('❌ Table "$table" not found: $e');
        return false;
      }
    }

    debugPrint('✅ All required tables exist');
    return true;
  }

  /// Get schema initialization instructions
  String getInitializationInstructions() {
    return '''
DATABASE SCHEMA INITIALIZATION INSTRUCTIONS
============================================

The NoteAssista database schema needs to be initialized in your Supabase project.

Steps:
1. Go to your Supabase dashboard (https://app.supabase.com)
2. Select your project
3. Navigate to the SQL Editor
4. Click "New Query"
5. Copy and paste the entire contents of supabase_schema.sql
6. Click "Run"
7. Wait for the schema to be created
8. Restart the NoteAssista app

The schema includes:
- notes table
- folders table
- templates table
- daily_note_preferences table
- Indexes for performance
- Row Level Security (RLS) policies
- Automatic timestamp triggers

If you encounter any errors, please check:
- Your Supabase project is properly configured
- You have the correct permissions
- The database is not in a restricted state
''';
  }
}
