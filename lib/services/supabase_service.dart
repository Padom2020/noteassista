import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/template_model.dart';
import '../config/debug_config.dart';
import 'database_diagnostic_service.dart';
import 'cache_refresh_manager.dart';
import 'schema_initializer.dart';

/// Result wrapper for Supabase operations
class SupabaseOperationResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final SupabaseErrorType? errorType;
  final Map<String, dynamic>? errorDetails;

  SupabaseOperationResult.success(this.data)
    : success = true,
      error = null,
      errorType = null,
      errorDetails = null;

  SupabaseOperationResult.failure(
    this.error, {
    this.errorType,
    this.errorDetails,
  }) : success = false,
       data = null;
}

/// Types of Supabase errors for better error handling
enum SupabaseErrorType {
  authentication,
  authorization,
  network,
  validation,
  database,
  unknown,
}

/// Service class for all Supabase database operations
/// Replaces FirestoreService with equivalent functionality
class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _supabase;

  SupabaseService._internal() {
    _supabase = Supabase.instance.client;
  }

  /// Singleton instance
  static SupabaseService get instance {
    _instance ??= SupabaseService._internal();
    return _instance!;
  }

  /// Initialize schema on first connection (called once)
  static Future<void> initializeSchema() async {
    try {
      debugPrint('🔍 Checking database schema...');

      final diagnostic = DatabaseDiagnosticService.instance;
      final schemaCheck = await diagnostic.validateAllRequiredTables();

      if (!schemaCheck.passed) {
        debugPrint('⚠️ Schema validation failed. Attempting initialization...');

        final initializer = SchemaInitializer.instance;
        final result = await initializer.initializeSchema();

        if (result.success) {
          debugPrint('✅ Schema initialized successfully');
        } else {
          debugPrint('❌ Schema initialization failed: ${result.errors}');
        }
      } else {
        debugPrint('✅ Database schema is valid');
      }
    } catch (e) {
      debugPrint('❌ Error during schema initialization: $e');
    }
  }

  /// Get current user ID from Supabase auth
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Check network connectivity and provide user guidance
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Simple connectivity check by making a lightweight request
      await _supabase.from('notes').select('id').limit(1).count();
      return true;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('socketexception')) {
        return false;
      }
      // If it's not a network error, assume connectivity is fine
      return true;
    }
  }

  /// Execute operation with automatic retry for network errors
  Future<SupabaseOperationResult<T>> _executeWithRetry<T>(
    String operation,
    Future<T> Function() operationFunction, {
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 1),
    Map<String, dynamic>? parameters,
  }) async {
    // Simplified without performance monitoring for now
    _logOperationStart(operation, parameters);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await operationFunction();
        _logOperationSuccess(operation, result);
        return SupabaseOperationResult.success(result);
      } catch (e, stackTrace) {
        final errorType = _getErrorType(e);

        // Handle PGRST205 errors with cache refresh
        if (e is PostgrestException &&
            e.code == 'PGRST205' &&
            attempt < maxRetries) {
          _logError(
            '$operation (PGRST205 - attempt ${attempt + 1})',
            e,
            stackTrace,
          );

          debugPrint('🔄 Attempting cache refresh for PGRST205 error...');
          final cacheManager = CacheRefreshManager.instance;
          final refreshResult = await cacheManager.refreshSchemaCache();

          if (refreshResult.success) {
            debugPrint('✅ Cache refreshed, retrying operation...');
            await Future.delayed(retryDelay);
            continue;
          } else {
            debugPrint(
              '❌ Cache refresh failed, attempting schema initialization...',
            );
            final initializer = SchemaInitializer.instance;
            final initResult = await initializer.initializeSchema();

            if (initResult.success) {
              debugPrint('✅ Schema initialized, retrying operation...');
              await Future.delayed(retryDelay);
              continue;
            }
          }
        }

        // Only retry for network errors and not on the last attempt
        if (errorType == SupabaseErrorType.network && attempt < maxRetries) {
          _logError('$operation (attempt ${attempt + 1})', e, stackTrace);

          // Check connectivity before retrying
          final hasConnectivity = await _checkNetworkConnectivity();
          if (!hasConnectivity) {
            return SupabaseOperationResult.failure(
              'No internet connection. Please check your network and try again.',
              errorType: SupabaseErrorType.network,
              errorDetails: {
                'operation': operation,
                'attempts': attempt + 1,
                'connectivity_check': false,
              },
            );
          }

          // Wait before retrying
          await Future.delayed(retryDelay * (attempt + 1));
          continue;
        }

        // Log final error
        _logError(operation, e, stackTrace);

        return SupabaseOperationResult.failure(
          _getErrorMessage(e, operation),
          errorType: errorType,
          errorDetails: {
            'operation': operation,
            'attempts': attempt + 1,
            'final_error': e.toString(),
          },
        );
      }
    }

    // This should never be reached, but just in case
    return SupabaseOperationResult.failure(
      'Operation failed after $maxRetries retries',
      errorType: SupabaseErrorType.unknown,
    );
  }

  // ==================== Error Handling ====================

  /// Convert Supabase errors to user-friendly messages with detailed context
  String _getErrorMessage(dynamic error, [String? operation]) {
    if (error is AuthException) {
      return _getAuthErrorMessage(error, operation);
    }

    if (error is PostgrestException) {
      return _getDatabaseErrorMessage(error, operation);
    }

    if (error is Exception) {
      return _getNetworkErrorMessage(error, operation);
    }

    // Handle string errors (common in Dart/Flutter)
    if (error is String) {
      return _parseStringError(error, operation);
    }

    return operation != null
        ? 'An unexpected error occurred while $operation. Please try again.'
        : 'An unexpected error occurred. Please try again.';
  }

  /// Handle authentication-specific errors with clear guidance
  String _getAuthErrorMessage(AuthException error, [String? operation]) {
    final baseMessage = switch (error.statusCode) {
      '400' => 'Invalid request. Please check your input and try again.',
      '401' => 'Your session has expired. Please log in again to continue.',
      '403' =>
        "You don't have permission to perform this action. Please contact support if you believe this is an error.",
      '422' =>
        'The provided data is invalid. Please check your information and try again.',
      '429' => 'Too many requests. Please wait a moment before trying again.',
      '500' => 'Server error occurred. Please try again in a few moments.',
      _ =>
        error.message.isNotEmpty
            ? error.message
            : 'Authentication error occurred.',
    };

    // Add operation-specific context
    if (operation != null) {
      return '$baseMessage (Operation: $operation)';
    }

    // Add helpful guidance for common auth errors
    if (error.statusCode == '401') {
      return '$baseMessage\n\nTip: Try logging out and logging back in.';
    }

    if (error.statusCode == '403') {
      return '$baseMessage\n\nTip: Make sure you have the necessary permissions for this action.';
    }

    return baseMessage;
  }

  /// Handle database-specific errors with detailed information
  String _getDatabaseErrorMessage(
    PostgrestException error, [
    String? operation,
  ]) {
    final baseMessage = switch (error.code) {
      '23505' =>
        'This item already exists. Please use a different name or identifier.',
      '23503' =>
        'Cannot perform this action because other items depend on this data.',
      '23514' =>
        'The provided data violates database constraints. Please check your input.',
      '42501' =>
        'Access denied. You do not have permission to access this data.',
      'PGRST116' => 'The requested item was not found or has been deleted.',
      'PGRST301' => 'Multiple items found when only one was expected.',
      'PGRST204' => 'No data was returned from the operation.',
      'PGRST205' =>
        'Database tables not found. The database schema may not be initialized.',
      _ =>
        error.message.isNotEmpty
            ? 'Database error: ${error.message}'
            : 'A database error occurred.',
    };

    if (operation != null) {
      return '$baseMessage (Operation: $operation)';
    }

    // Add helpful tips for common database errors
    if (error.code == '23505') {
      return '$baseMessage\n\nTip: Try using a different name or check if the item already exists.';
    }

    if (error.code == '23503') {
      return '$baseMessage\n\nTip: Remove or update dependent items first, then try again.';
    }

    if (error.code == 'PGRST205') {
      return '$baseMessage\n\nTip: Try running diagnostics from the app settings to initialize the database schema. If the problem persists, contact support.';
    }

    return baseMessage;
  }

  /// Handle network and connection errors with recovery suggestions
  String _getNetworkErrorMessage(Exception error, [String? operation]) {
    final message = error.toString().toLowerCase();

    if (message.contains('socketexception') || message.contains('network')) {
      final baseMsg =
          'Network connection failed. Please check your internet connection and try again.';
      return operation != null ? '$baseMsg (Operation: $operation)' : baseMsg;
    }

    if (message.contains('timeout') || message.contains('timed out')) {
      final baseMsg =
          'The operation timed out. This might be due to a slow connection or server issues.';
      final tip =
          '\n\nTip: Try again in a few moments or check your internet connection.';
      return operation != null
          ? '$baseMsg (Operation: $operation)$tip'
          : '$baseMsg$tip';
    }

    if (message.contains('certificate') ||
        message.contains('ssl') ||
        message.contains('tls')) {
      final baseMsg =
          'Secure connection failed. This might be due to network security settings.';
      final tip =
          '\n\nTip: Check your network settings or try a different connection.';
      return operation != null
          ? '$baseMsg (Operation: $operation)$tip'
          : '$baseMsg$tip';
    }

    if (message.contains('host') || message.contains('resolve')) {
      final baseMsg =
          'Cannot reach the server. Please check your internet connection.';
      return operation != null ? '$baseMsg (Operation: $operation)' : baseMsg;
    }

    // Generic network error
    final baseMsg = 'A network error occurred: ${error.toString()}';
    return operation != null ? '$baseMsg (Operation: $operation)' : baseMsg;
  }

  /// Parse string errors for common patterns
  String _parseStringError(String error, [String? operation]) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (lowerError.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    }

    if (lowerError.contains('permission') ||
        lowerError.contains('unauthorized')) {
      return 'Access denied. Please check your permissions.';
    }

    if (lowerError.contains('not found')) {
      return 'The requested item was not found.';
    }

    // Return the original error with operation context
    return operation != null ? '$error (Operation: $operation)' : error;
  }

  /// Determine error type for better error handling and recovery strategies
  SupabaseErrorType _getErrorType(dynamic error) {
    if (error is AuthException) {
      return switch (error.statusCode) {
        '401' => SupabaseErrorType.authentication,
        '403' => SupabaseErrorType.authorization,
        '422' => SupabaseErrorType.validation,
        '429' => SupabaseErrorType.network, // Rate limiting is network-related
        _ => SupabaseErrorType.authentication,
      };
    }

    if (error is PostgrestException) {
      return switch (error.code) {
        '23505' || '23503' || '23514' => SupabaseErrorType.validation,
        '42501' => SupabaseErrorType.authorization,
        'PGRST116' || 'PGRST301' || 'PGRST204' => SupabaseErrorType.database,
        _ => SupabaseErrorType.database,
      };
    }

    if (error is Exception) {
      final message = error.toString().toLowerCase();
      if (message.contains('network') ||
          message.contains('connection') ||
          message.contains('timeout') ||
          message.contains('socketexception') ||
          message.contains('host') ||
          message.contains('resolve')) {
        return SupabaseErrorType.network;
      }
      if (message.contains('certificate') ||
          message.contains('ssl') ||
          message.contains('tls')) {
        return SupabaseErrorType.network;
      }
    }

    if (error is String) {
      final lowerError = error.toLowerCase();
      if (lowerError.contains('network') ||
          lowerError.contains('connection') ||
          lowerError.contains('timeout')) {
        return SupabaseErrorType.network;
      }
      if (lowerError.contains('permission') ||
          lowerError.contains('unauthorized')) {
        return SupabaseErrorType.authorization;
      }
      if (lowerError.contains('validation') || lowerError.contains('invalid')) {
        return SupabaseErrorType.validation;
      }
    }

    return SupabaseErrorType.unknown;
  }

  /// Log errors with comprehensive context and debug information
  void _logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    if (!DebugConfig.instance.isVerboseLoggingEnabled) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final errorType = _getErrorType(error);
    final userId = currentUserId ?? 'anonymous';

    // Create detailed error log
    final logMessage = '''
========== SUPABASE ERROR ==========
Timestamp: $timestamp
Operation: $operation
User ID: $userId
Error Type: $errorType
Error: $error
${error is AuthException ? 'Auth Status Code: ${error.statusCode}' : ''}
${error is PostgrestException ? 'Database Error Code: ${error.code}' : ''}
===================================''';

    debugPrint(logMessage);

    if (stackTrace != null && DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('Stack trace:\n$stackTrace');
    }

    // Log additional context for specific error types
    if (error is AuthException &&
        DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('Auth Error Details: ${error.message}');
    }

    if (error is PostgrestException &&
        DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('Database Error Details: ${error.message}');
      if (error.details != null) {
        debugPrint('Database Error Details: ${error.details}');
      }
      if (error.hint != null) {
        debugPrint('Database Error Hint: ${error.hint}');
      }
    }
  }

  /// Log operation start for debugging (when verbose logging is enabled)
  void _logOperationStart(String operation, [Map<String, dynamic>? params]) {
    if (!DebugConfig.instance.isVerboseLoggingEnabled) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final userId = currentUserId ?? 'anonymous';

    debugPrint(
      '[$timestamp] 🚀 Starting operation: $operation (User: $userId)',
    );

    if (params != null &&
        params.isNotEmpty &&
        DebugConfig.instance.shouldLogOperationParameters) {
      debugPrint('  📋 Operation parameters: $params');
    }
  }

  /// Log operation success for debugging
  void _logOperationSuccess(String operation, [dynamic result]) {
    if (!DebugConfig.instance.isVerboseLoggingEnabled) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] ✅ Operation completed successfully: $operation');

    if (result != null && DebugConfig.instance.shouldLogOperationResults) {
      // Log result summary without sensitive data
      if (result is List) {
        debugPrint('  📊 Result: List with ${result.length} items');
      } else if (result is Map) {
        debugPrint('  📊 Result: Map with ${result.length} keys');
      } else if (result is String) {
        debugPrint('  📊 Result: String (length: ${result.length})');
      } else {
        debugPrint('  📊 Result type: ${result.runtimeType}');
      }
    }
  }

  // ==================== User Management ====================

  /// Create user document in Supabase (handled by auth, but we can extend user profile)
  Future<SupabaseOperationResult<void>> createUser(
    String uid,
    String email,
  ) async {
    try {
      // In Supabase, user creation is handled by auth
      // We can extend this to create user profile data if needed
      debugPrint('User created with Supabase auth: $uid');
      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('createUser', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  // ==================== Notes Operations ====================

  /// Create a new note
  Future<SupabaseOperationResult<String>> createNote(NoteModel note) async {
    return await _executeWithRetry<String>(
      'createNote',
      () async {
        debugPrint('SupabaseService.createNote: Starting note creation');
        debugPrint(
          'SupabaseService.createNote: isAuthenticated = $isAuthenticated',
        );
        debugPrint(
          'SupabaseService.createNote: currentUserId = $currentUserId',
        );

        if (!isAuthenticated) {
          throw Exception('Authentication required to create notes');
        }

        final noteData = _noteToSupabaseMap(note);
        noteData['user_id'] = currentUserId;

        debugPrint('SupabaseService.createNote: Note data prepared');
        debugPrint('SupabaseService.createNote: Title = ${noteData['title']}');
        debugPrint(
          'SupabaseService.createNote: User ID = ${noteData['user_id']}',
        );
        debugPrint('SupabaseService.createNote: Attempting database insert...');

        final response =
            await _supabase
                .from('notes')
                .insert(noteData)
                .select('id')
                .single();

        debugPrint('SupabaseService.createNote: Database insert successful');
        final noteId = response['id'] as String;
        debugPrint('SupabaseService.createNote: Created note with ID: $noteId');

        // Increment note count in folder if note is assigned to a folder
        if (note.folderId != null) {
          await _updateFolderNoteCount(note.folderId!, 1);
        }

        return noteId;
      },
      parameters: {
        'title': note.title,
        'folderId': note.folderId,
        'hasAudio': note.audioUrls.isNotEmpty,
        'hasImages': note.imageUrls.isNotEmpty,
        'hasDrawings': note.drawingUrls.isNotEmpty,
        'tagCount': note.tags.length,
      },
    );
  }

  /// Update an existing note
  Future<SupabaseOperationResult<void>> updateNote(
    String noteId,
    NoteModel note,
  ) async {
    return await _executeWithRetry<void>('updateNote', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to update notes');
      }

      final noteData = _noteToSupabaseMap(note);
      noteData['updated_at'] = DateTime.now().toIso8601String();

      // Remove user_id from update data - it should never be changed
      noteData.remove('user_id');

      await _supabase
          .from('notes')
          .update(noteData)
          .eq('id', noteId)
          .eq('user_id', currentUserId!);
    });
  }

  /// Delete a note
  Future<SupabaseOperationResult<void>> deleteNote(String noteId) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to delete notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      debugPrint('Attempting to delete note: $noteId for user: $currentUserId');

      // Get the note to find its folder and verify ownership before deleting
      final noteResult = await getNoteById(noteId);
      if (noteResult.success && noteResult.data != null) {
        final note = noteResult.data!;
        final folderId = note.folderId;
        final noteUserId = note.userId ?? currentUserId;

        debugPrint(
          'Note found - owner: ${note.ownerId}, user_id: ${note.userId}, current user: $currentUserId',
        );

        // Delete the note using the note's user_id
        final response = await _supabase
            .from('notes')
            .delete()
            .eq('id', noteId)
            .eq('user_id', noteUserId!);

        debugPrint('Delete response: $response');

        // Decrement note count in folder if note was in a folder
        if (folderId != null) {
          await _updateFolderNoteCount(folderId, -1);
        }
      } else {
        debugPrint('Note not found or error getting note: ${noteResult.error}');
        // Note not found, still try to delete using current user ID
        final response = await _supabase
            .from('notes')
            .delete()
            .eq('id', noteId)
            .eq('user_id', currentUserId!);

        debugPrint('Delete response for not-found note: $response');
      }

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      debugPrint('Error deleting note: $e');
      _logError('deleteNote', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get a single note by ID
  Future<SupabaseOperationResult<NoteModel?>> getNoteById(String noteId) async {
    return await _executeWithRetry<NoteModel?>('getNoteById', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to access notes');
      }

      final response =
          await _supabase
              .from('notes')
              .select()
              .eq('id', noteId)
              .eq('user_id', currentUserId!)
              .maybeSingle();

      if (response == null) {
        return null;
      }

      return _noteFromSupabaseMap(response);
    }, parameters: {'noteId': noteId});
  }

  /// Stream notes filtered by isDone status
  Stream<List<NoteModel>> streamNotes(bool isDone) {
    if (!isAuthenticated) {
      return Stream<List<NoteModel>>.error(
        'Please log in to access notes',
      ).asBroadcastStream();
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) async {
          try {
            final response = await _supabase
                .from('notes')
                .select()
                .eq('user_id', currentUserId!)
                .eq('is_done', isDone)
                .order('created_at', ascending: false);

            return response.map((item) => _noteFromSupabaseMap(item)).toList();
          } catch (e) {
            _logError('streamNotes', e);
            return <NoteModel>[];
          }
        })
        .distinct((previous, next) {
          // Only emit if the list of note IDs changed
          if (previous.length != next.length) return false;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i].id != next[i].id) return false;
          }
          return true;
        })
        .asBroadcastStream();
  }

  /// Stream notes filtered by folder (includes both owned and shared notes)
  Stream<List<NoteModel>> streamNotesByFolder(
    String? folderId, {
    bool? isDone,
  }) {
    if (!isAuthenticated) {
      return Stream<List<NoteModel>>.error(
        'Please log in to access notes',
      ).asBroadcastStream();
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) async {
          try {
            // Query notes where user is the owner OR a collaborator
            var query = _supabase
                .from('notes')
                .select()
                .or(
                  'user_id.eq.$currentUserId,collaborator_ids.cs.{$currentUserId}',
                );

            // Filter by folderId only if specified (only applies to owned notes)
            if (folderId != null) {
              query = query.eq('folder_id', folderId);
            }

            // Optionally filter by isDone status
            if (isDone != null) {
              query = query.eq('is_done', isDone);
            }

            final response = await query.order('created_at', ascending: false);
            return response.map((item) => _noteFromSupabaseMap(item)).toList();
          } catch (e) {
            _logError('streamNotesByFolder', e);
            return <NoteModel>[];
          }
        })
        .distinct((previous, next) {
          // Only emit if the list of note IDs changed
          if (previous.length != next.length) return false;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i].id != next[i].id) return false;
          }
          return true;
        })
        .asBroadcastStream();
  }

  /// Stream all notes for the current user (includes both owned and shared notes)
  Stream<List<NoteModel>> streamAllNotes() {
    if (!isAuthenticated) {
      return Stream<List<NoteModel>>.error(
        'Please log in to access notes',
      ).asBroadcastStream();
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) async {
          try {
            // Query notes where user is the owner OR a collaborator
            final response = await _supabase
                .from('notes')
                .select()
                .or(
                  'user_id.eq.$currentUserId,collaborator_ids.cs.{$currentUserId}',
                )
                .order('updated_at', ascending: false);

            return response.map((item) => _noteFromSupabaseMap(item)).toList();
          } catch (e) {
            _logError('streamAllNotes', e);
            return <NoteModel>[];
          }
        })
        .distinct((previous, next) {
          // Only emit if the list of note IDs changed
          if (previous.length != next.length) return false;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i].id != next[i].id) return false;
          }
          return true;
        })
        .asBroadcastStream();
  }

  /// Stream only shared notes (where user is a collaborator but not the owner)
  Stream<List<NoteModel>> streamSharedNotes() {
    if (!isAuthenticated) {
      return Stream<List<NoteModel>>.error(
        'Please log in to access notes',
      ).asBroadcastStream();
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) async {
          try {
            // Query notes where user is a collaborator but NOT the owner
            // Using the or filter to check if user is in collaborator_ids array
            final response = await _supabase
                .from('notes')
                .select()
                .neq('user_id', currentUserId!)
                .or('collaborator_ids.cs.{$currentUserId}')
                .order('updated_at', ascending: false);

            return response.map((item) => _noteFromSupabaseMap(item)).toList();
          } catch (e) {
            _logError('streamSharedNotes', e);
            return <NoteModel>[];
          }
        })
        .distinct((previous, next) {
          // Only emit if the list of note IDs changed
          if (previous.length != next.length) return false;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i].id != next[i].id) return false;
          }
          return true;
        })
        .asBroadcastStream();
  }

  /// Get notes by folder (one-time fetch) - includes both owned and shared notes
  Future<SupabaseOperationResult<List<NoteModel>>> getNotesByFolder(
    String? folderId, {
    bool? isDone,
  }) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Query notes where user is the owner OR a collaborator
      var query = _supabase
          .from('notes')
          .select()
          .or('user_id.eq.$currentUserId,collaborator_ids.cs.{$currentUserId}');

      // Filter by folderId (only applies to owned notes)
      if (folderId != null) {
        query = query.eq('folder_id', folderId);
      } else {
        query = query.isFilter('folder_id', null);
      }

      // Optionally filter by isDone status
      if (isDone != null) {
        query = query.eq('is_done', isDone);
      }

      final response = await query.order('created_at', ascending: false);

      final notes = response.map((item) => _noteFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(notes);
    } catch (e, stackTrace) {
      _logError('getNotesByFolder', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Move a note to a different folder
  Future<SupabaseOperationResult<void>> moveNoteToFolder(
    String noteId,
    String? newFolderId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Get the note to find its current folder
      final noteResult = await getNoteById(noteId);
      if (!noteResult.success || noteResult.data == null) {
        return SupabaseOperationResult.failure(
          'Note not found',
          errorType: SupabaseErrorType.database,
        );
      }

      final oldFolderId = noteResult.data!.folderId;

      // If moving to the same folder, do nothing
      if (oldFolderId == newFolderId) {
        return SupabaseOperationResult.success(null);
      }

      // Update the note's folderId
      await _supabase
          .from('notes')
          .update({
            'folder_id': newFolderId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', currentUserId!);

      // Decrement note count in old folder
      if (oldFolderId != null) {
        await _updateFolderNoteCount(oldFolderId, -1);
      }

      // Increment note count in new folder
      if (newFolderId != null) {
        await _updateFolderNoteCount(newFolderId, 1);
      }

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('moveNoteToFolder', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get all notes for the current user
  Future<SupabaseOperationResult<List<NoteModel>>> getAllNotes() async {
    return await _executeWithRetry<List<NoteModel>>('getAllNotes', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to access notes');
      }

      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false);

      return response.map((item) => _noteFromSupabaseMap(item)).toList();
    });
  }

  /// Update note pin status
  Future<SupabaseOperationResult<void>> toggleNotePinStatus(
    String noteId,
    bool isPinned,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('notes')
          .update({
            'is_pinned': isPinned,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('toggleNotePinStatus', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Update note view count
  Future<SupabaseOperationResult<void>> incrementNoteViewCount(
    String noteId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Get current view count and increment it
      final currentNote = await getNoteById(noteId);
      if (!currentNote.success || currentNote.data == null) {
        return SupabaseOperationResult.failure(
          'Note not found',
          errorType: SupabaseErrorType.database,
        );
      }

      final newViewCount = currentNote.data!.viewCount + 1;

      await _supabase
          .from('notes')
          .update({
            'view_count': newViewCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('incrementNoteViewCount', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Toggle note completion status
  Future<SupabaseOperationResult<void>> toggleNoteStatus(
    String noteId,
    bool newStatus,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('notes')
          .update({
            'is_done': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('toggleNoteStatus', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Search notes by text content
  Future<SupabaseOperationResult<List<NoteModel>>> searchNotes(
    String searchQuery,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to search notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      if (searchQuery.trim().isEmpty) {
        return SupabaseOperationResult.success([]);
      }

      // Search in title and description using ilike for case-insensitive search
      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', currentUserId!)
          .or(
            'title.ilike.%${searchQuery.trim()}%,description.ilike.%${searchQuery.trim()}%',
          )
          .order('updated_at', ascending: false);

      final notes = response.map((item) => _noteFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(notes);
    } catch (e, stackTrace) {
      _logError('searchNotes', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get notes by tags
  Future<SupabaseOperationResult<List<NoteModel>>> getNotesByTags(
    List<String> tags,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      if (tags.isEmpty) {
        return SupabaseOperationResult.success([]);
      }

      // Use overlaps operator to find notes that contain any of the specified tags
      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', currentUserId!)
          .overlaps('tags', tags)
          .order('updated_at', ascending: false);

      final notes = response.map((item) => _noteFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(notes);
    } catch (e, stackTrace) {
      _logError('getNotesByTags', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get pinned notes
  Future<SupabaseOperationResult<List<NoteModel>>> getPinnedNotes() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', currentUserId!)
          .eq('is_pinned', true)
          .order('updated_at', ascending: false);

      final notes = response.map((item) => _noteFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(notes);
    } catch (e, stackTrace) {
      _logError('getPinnedNotes', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Update note word count
  Future<SupabaseOperationResult<void>> updateNoteWordCount(
    String noteId,
    int wordCount,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('notes')
          .update({
            'word_count': wordCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('updateNoteWordCount', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Bulk delete notes
  Future<SupabaseOperationResult<void>> bulkDeleteNotes(
    List<String> noteIds,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to delete notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      if (noteIds.isEmpty) {
        return SupabaseOperationResult.success(null);
      }

      await _supabase
          .from('notes')
          .delete()
          .inFilter('id', noteIds)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('bulkDeleteNotes', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get notes count by status
  Future<SupabaseOperationResult<Map<String, int>>> getNotesCount() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access notes',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Get total count
      final totalResponse =
          await _supabase
              .from('notes')
              .select('id')
              .eq('user_id', currentUserId!)
              .count();

      // Get completed count
      final completedResponse =
          await _supabase
              .from('notes')
              .select('id')
              .eq('user_id', currentUserId!)
              .eq('is_done', true)
              .count();

      final totalCount = totalResponse.count;
      final completedCount = completedResponse.count;
      final pendingCount = totalCount - completedCount;

      return SupabaseOperationResult.success({
        'total': totalCount,
        'completed': completedCount,
        'pending': pendingCount,
      });
    } catch (e, stackTrace) {
      _logError('getNotesCount', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  // ==================== Folders Operations ====================

  /// Create a new folder
  Future<SupabaseOperationResult<String>> createFolder(
    FolderModel folder,
  ) async {
    return await _executeWithRetry<String>(
      'createFolder',
      () async {
        if (!isAuthenticated) {
          throw Exception('Authentication required to create folders');
        }

        final folderData = _folderToSupabaseMap(folder);
        folderData['user_id'] = currentUserId;

        final response =
            await _supabase
                .from('folders')
                .insert(folderData)
                .select('id')
                .single();

        return response['id'] as String;
      },
      parameters: {
        'name': folder.name,
        'color': folder.color,
        'parentId': folder.parentId,
        'isFavorite': folder.isFavorite,
      },
    );
  }

  /// Update an existing folder
  Future<SupabaseOperationResult<void>> updateFolder(
    String folderId,
    FolderModel folder,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final folderData = _folderToSupabaseMap(folder);
      folderData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('folders')
          .update(folderData)
          .eq('id', folderId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('updateFolder', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Delete a folder and reassign its notes to parent folder or root
  Future<SupabaseOperationResult<void>> deleteFolder(
    String folderId, {
    String? targetFolderId,
  }) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to delete folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Get the folder to check if it has a parent
      final folderResult = await getFolderById(folderId);
      if (!folderResult.success || folderResult.data == null) {
        return SupabaseOperationResult.failure(
          'Folder not found',
          errorType: SupabaseErrorType.database,
        );
      }

      final folder = folderResult.data!;
      final parentId = folder.parentId;

      // Determine where to move notes
      final newFolderId = targetFolderId ?? parentId;

      // Get all notes in this folder
      final notesResult = await getNotesByFolder(folderId);
      if (!notesResult.success) {
        return SupabaseOperationResult.failure(
          'Failed to get notes in folder',
          errorType: SupabaseErrorType.database,
        );
      }

      final notes = notesResult.data!;

      // Move all notes to the target folder
      for (final note in notes) {
        final moveResult = await moveNoteToFolder(note.id, newFolderId);
        if (!moveResult.success) {
          return SupabaseOperationResult.failure(
            'Failed to move notes from folder',
            errorType: SupabaseErrorType.database,
          );
        }
      }

      // Update note count for target folder if moving notes there
      if (newFolderId != null && notes.isNotEmpty) {
        await _updateFolderNoteCount(newFolderId, notes.length);
      }

      // Delete the folder
      await _supabase
          .from('folders')
          .delete()
          .eq('id', folderId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('deleteFolder', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get a single folder by ID
  Future<SupabaseOperationResult<FolderModel?>> getFolderById(
    String folderId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response =
          await _supabase
              .from('folders')
              .select()
              .eq('id', folderId)
              .eq('user_id', currentUserId!)
              .maybeSingle();

      if (response == null) {
        return SupabaseOperationResult.success(null);
      }

      final folder = _folderFromSupabaseMap(response);
      return SupabaseOperationResult.success(folder);
    } catch (e, stackTrace) {
      _logError('getFolderById', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get all folders for the current user
  Future<SupabaseOperationResult<List<FolderModel>>> getFolders() async {
    return await _executeWithRetry<List<FolderModel>>('getFolders', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to access folders');
      }

      final response = await _supabase
          .from('folders')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: true);

      return response.map((item) => _folderFromSupabaseMap(item)).toList();
    });
  }

  /// Stream folders for real-time updates
  Stream<List<FolderModel>> streamFolders() {
    if (!isAuthenticated) {
      return Stream.error('Please log in to access folders');
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        final response = await _supabase
            .from('folders')
            .select()
            .eq('user_id', currentUserId!)
            .order('created_at', ascending: true);

        return response.map((item) => _folderFromSupabaseMap(item)).toList();
      } catch (e) {
        _logError('streamFolders', e);
        return <FolderModel>[];
      }
    });
  }

  /// Toggle folder favorite status
  Future<SupabaseOperationResult<void>> toggleFolderFavorite(
    String folderId,
    bool isFavorite,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('folders')
          .update({
            'is_favorite': isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', folderId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('toggleFolderFavorite', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Update folder color
  Future<SupabaseOperationResult<void>> updateFolderColor(
    String folderId,
    String color,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('folders')
          .update({
            'color': color,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', folderId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('updateFolderColor', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Update folder note count (internal helper method)
  Future<void> _updateFolderNoteCount(String folderId, int increment) async {
    try {
      // Get current folder
      final folderResult = await getFolderById(folderId);
      if (folderResult.success && folderResult.data != null) {
        final currentCount = folderResult.data!.noteCount;
        final newCount = currentCount + increment;

        await _supabase
            .from('folders')
            .update({
              'note_count': newCount > 0 ? newCount : 0,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', folderId)
            .eq('user_id', currentUserId!);
      }
    } catch (e) {
      _logError('_updateFolderNoteCount', e);
      // Don't throw error for note count updates as it's not critical
    }
  }

  /// Get folders count
  Future<SupabaseOperationResult<int>> getFoldersCount() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response =
          await _supabase
              .from('folders')
              .select('id')
              .eq('user_id', currentUserId!)
              .count();

      return SupabaseOperationResult.success(response.count);
    } catch (e, stackTrace) {
      _logError('getFoldersCount', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get favorite folders
  Future<SupabaseOperationResult<List<FolderModel>>>
  getFavoriteFolders() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access folders',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response = await _supabase
          .from('folders')
          .select()
          .eq('user_id', currentUserId!)
          .eq('is_favorite', true)
          .order('created_at', ascending: true);

      final folders =
          response.map((item) => _folderFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(folders);
    } catch (e, stackTrace) {
      _logError('getFavoriteFolders', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  // ==================== Templates Operations ====================

  /// Create a new template
  Future<SupabaseOperationResult<String>> createTemplate(
    TemplateModel template,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to create templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final templateData = _templateToSupabaseMap(template);
      templateData['user_id'] = currentUserId;

      final response =
          await _supabase
              .from('templates')
              .insert(templateData)
              .select('id')
              .single();

      return SupabaseOperationResult.success(response['id'] as String);
    } catch (e, stackTrace) {
      _logError('createTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Update an existing template
  Future<SupabaseOperationResult<void>> updateTemplate(
    String templateId,
    TemplateModel template,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final templateData = _templateToSupabaseMap(template);
      templateData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('templates')
          .update(templateData)
          .eq('id', templateId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('updateTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Delete a template
  Future<SupabaseOperationResult<void>> deleteTemplate(
    String templateId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to delete templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      await _supabase
          .from('templates')
          .delete()
          .eq('id', templateId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('deleteTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get a single template by ID
  Future<SupabaseOperationResult<TemplateModel?>> getTemplateById(
    String templateId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response =
          await _supabase
              .from('templates')
              .select()
              .eq('id', templateId)
              .eq('user_id', currentUserId!)
              .maybeSingle();

      if (response == null) {
        return SupabaseOperationResult.success(null);
      }

      final template = _templateFromSupabaseMap(response);
      return SupabaseOperationResult.success(template);
    } catch (e, stackTrace) {
      _logError('getTemplateById', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Get all templates for the current user
  Future<SupabaseOperationResult<List<TemplateModel>>> getTemplates() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to access templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final response = await _supabase
          .from('templates')
          .select()
          .eq('user_id', currentUserId!)
          .order('usage_count', ascending: false);

      final templates =
          response.map((item) => _templateFromSupabaseMap(item)).toList();
      return SupabaseOperationResult.success(templates);
    } catch (e, stackTrace) {
      _logError('getTemplates', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Stream templates for real-time updates
  Stream<List<TemplateModel>> streamTemplates() {
    if (!isAuthenticated) {
      return Stream.error('Please log in to access templates');
    }

    // Use periodic stream for now - can be optimized later with real-time subscriptions
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        final response = await _supabase
            .from('templates')
            .select()
            .eq('user_id', currentUserId!)
            .order('usage_count', ascending: false);

        return response.map((item) => _templateFromSupabaseMap(item)).toList();
      } catch (e) {
        _logError('streamTemplates', e);
        return <TemplateModel>[];
      }
    });
  }

  /// Increment template usage count
  Future<SupabaseOperationResult<void>> incrementTemplateUsage(
    String templateId,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to update templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Get current template to increment usage count
      final templateResult = await getTemplateById(templateId);
      if (!templateResult.success || templateResult.data == null) {
        return SupabaseOperationResult.failure(
          'Template not found',
          errorType: SupabaseErrorType.database,
        );
      }

      final currentUsage = templateResult.data!.usageCount;
      final newUsage = currentUsage + 1;

      await _supabase
          .from('templates')
          .update({
            'usage_count': newUsage,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', templateId)
          .eq('user_id', currentUserId!);

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('incrementTemplateUsage', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Create predefined templates for a new user
  Future<SupabaseOperationResult<void>> createPredefinedTemplates() async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to create templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      final predefinedTemplates = _getPredefinedTemplates();

      for (final template in predefinedTemplates) {
        final templateData = _templateToSupabaseMap(template);
        templateData['user_id'] = currentUserId;

        await _supabase.from('templates').insert(templateData);
      }

      return SupabaseOperationResult.success(null);
    } catch (e, stackTrace) {
      _logError('createPredefinedTemplates', e, stackTrace);
      return SupabaseOperationResult.failure(
        _getErrorMessage(e),
        errorType: _getErrorType(e),
      );
    }
  }

  /// Export template to JSON format
  SupabaseOperationResult<String> exportTemplate(TemplateModel template) {
    try {
      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'template': {
          'name': template.name,
          'description': template.description,
          'content': template.content,
          'variables': template.variables.map((v) => v.toMap()).toList(),
          'isCustom': template.isCustom,
        },
      };

      final jsonString = jsonEncode(exportData);
      return SupabaseOperationResult.success(jsonString);
    } catch (e, stackTrace) {
      _logError('exportTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        'Failed to export template',
        errorType: SupabaseErrorType.unknown,
      );
    }
  }

  /// Validate imported template structure
  SupabaseOperationResult<Map<String, dynamic>> validateImportedTemplate(
    String jsonString,
  ) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Check required top-level fields
      if (!data.containsKey('template')) {
        return SupabaseOperationResult.failure(
          'Invalid template format: missing template data',
          errorType: SupabaseErrorType.validation,
        );
      }

      final template = data['template'] as Map<String, dynamic>;

      // Check required template fields
      final requiredFields = ['name', 'description', 'content'];
      for (final field in requiredFields) {
        if (!template.containsKey(field) || template[field] == null) {
          return SupabaseOperationResult.failure(
            'Invalid template format: missing $field',
            errorType: SupabaseErrorType.validation,
          );
        }
      }

      // Validate template name
      final name = template['name'] as String;
      if (name.trim().isEmpty) {
        return SupabaseOperationResult.failure(
          'Template name cannot be empty',
          errorType: SupabaseErrorType.validation,
        );
      }

      // Validate variables if present
      if (template.containsKey('variables') && template['variables'] != null) {
        final variables = template['variables'] as List<dynamic>;
        for (final variable in variables) {
          if (variable is! Map<String, dynamic>) {
            return SupabaseOperationResult.failure(
              'Invalid variable format',
              errorType: SupabaseErrorType.validation,
            );
          }

          if (!variable.containsKey('name') ||
              !variable.containsKey('placeholder')) {
            return SupabaseOperationResult.failure(
              'Invalid variable format: missing name or placeholder',
              errorType: SupabaseErrorType.validation,
            );
          }
        }
      }

      return SupabaseOperationResult.success(data);
    } on FormatException {
      return SupabaseOperationResult.failure(
        'Invalid JSON format',
        errorType: SupabaseErrorType.validation,
      );
    } catch (e, stackTrace) {
      _logError('validateImportedTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        'Failed to validate template',
        errorType: SupabaseErrorType.unknown,
      );
    }
  }

  /// Import template from JSON
  Future<SupabaseOperationResult<String>> importTemplate(
    String jsonString,
  ) async {
    try {
      if (!isAuthenticated) {
        return SupabaseOperationResult.failure(
          'Please log in to import templates',
          errorType: SupabaseErrorType.authentication,
        );
      }

      // Validate the imported template
      final validationResult = validateImportedTemplate(jsonString);
      if (!validationResult.success) {
        return SupabaseOperationResult.failure(
          validationResult.error!,
          errorType: validationResult.errorType,
        );
      }

      final validatedData = validationResult.data!;
      final templateData = validatedData['template'] as Map<String, dynamic>;

      // Create TemplateModel from imported data
      final template = TemplateModel(
        id: '', // Will be set by Supabase
        name: templateData['name'] as String,
        description: templateData['description'] as String,
        content: templateData['content'] as String,
        variables:
            (templateData['variables'] as List<dynamic>?)
                ?.map(
                  (v) => TemplateVariable.fromMap(v as Map<String, dynamic>),
                )
                .toList() ??
            [],
        usageCount: 0, // Reset usage count for imported templates
        createdAt: DateTime.now(),
        isCustom: true, // Imported templates are always custom
      );

      // Check if template with same name already exists
      final existingTemplatesResult = await getTemplates();
      if (!existingTemplatesResult.success) {
        return SupabaseOperationResult.failure(
          'Failed to check existing templates',
          errorType: SupabaseErrorType.database,
        );
      }

      final existingTemplates = existingTemplatesResult.data!;
      final existingNames =
          existingTemplates.map((t) => t.name.toLowerCase()).toSet();

      String finalName = template.name;
      int counter = 1;
      while (existingNames.contains(finalName.toLowerCase())) {
        finalName = '${template.name} ($counter)';
        counter++;
      }

      // Create the template with unique name
      final finalTemplate = template.copyWith(name: finalName);
      return await createTemplate(finalTemplate);
    } catch (e, stackTrace) {
      _logError('importTemplate', e, stackTrace);
      return SupabaseOperationResult.failure(
        'Failed to import template',
        errorType: SupabaseErrorType.unknown,
      );
    }
  }

  /// Get predefined templates
  List<TemplateModel> _getPredefinedTemplates() {
    return [
      // Meeting Notes Template
      TemplateModel(
        id: '',
        name: 'Meeting Notes',
        description:
            'Template for capturing meeting discussions and action items',
        content: '''# {{meeting_title}}

**Date:** {{date}}
**Attendees:** {{attendees}}
**Duration:** {{duration}}

## Agenda
- {{agenda_item_1}}
- {{agenda_item_2}}
- {{agenda_item_3}}

## Discussion Points
{{discussion_notes}}

## Action Items
- [ ] {{action_item_1}} - Assigned to: {{assignee_1}}
- [ ] {{action_item_2}} - Assigned to: {{assignee_2}}
- [ ] {{action_item_3}} - Assigned to: {{assignee_3}}

## Next Steps
{{next_steps}}

## Next Meeting
**Date:** {{next_meeting_date}}
**Time:** {{next_meeting_time}}''',
        variables: [
          TemplateVariable(
            name: 'meeting_title',
            placeholder: 'Enter meeting title',
            required: true,
          ),
          TemplateVariable(
            name: 'date',
            placeholder: 'Enter meeting date',
            required: true,
          ),
          TemplateVariable(
            name: 'attendees',
            placeholder: 'List attendees',
            required: true,
          ),
          TemplateVariable(
            name: 'duration',
            placeholder: 'Meeting duration',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_1',
            placeholder: 'First agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_2',
            placeholder: 'Second agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'agenda_item_3',
            placeholder: 'Third agenda item',
            required: false,
          ),
          TemplateVariable(
            name: 'discussion_notes',
            placeholder: 'Key discussion points',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_1',
            placeholder: 'First action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_1',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_2',
            placeholder: 'Second action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_2',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_item_3',
            placeholder: 'Third action item',
            required: false,
          ),
          TemplateVariable(
            name: 'assignee_3',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'next_steps',
            placeholder: 'What happens next',
            required: false,
          ),
          TemplateVariable(
            name: 'next_meeting_date',
            placeholder: 'Next meeting date',
            required: false,
          ),
          TemplateVariable(
            name: 'next_meeting_time',
            placeholder: 'Next meeting time',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Daily Journal Template
      TemplateModel(
        id: '',
        name: 'Daily Journal',
        description: 'Template for daily reflection and planning',
        content: '''# Daily Journal - {{date}}

## Morning Reflection
**Mood:** {{morning_mood}}
**Energy Level:** {{energy_level}}
**Today's Focus:** {{todays_focus}}

## Goals for Today
- [ ] {{goal_1}}
- [ ] {{goal_2}}
- [ ] {{goal_3}}

## Gratitude
I'm grateful for:
1. {{gratitude_1}}
2. {{gratitude_2}}
3. {{gratitude_3}}

## Key Events
{{key_events}}

## Lessons Learned
{{lessons_learned}}

## Tomorrow's Priorities
- {{priority_1}}
- {{priority_2}}
- {{priority_3}}

## Evening Reflection
**How did today go?** {{evening_reflection}}
**What could be improved?** {{improvements}}''',
        variables: [
          TemplateVariable(
            name: 'date',
            placeholder: 'Enter date',
            required: true,
          ),
          TemplateVariable(
            name: 'morning_mood',
            placeholder: 'How are you feeling?',
            required: false,
          ),
          TemplateVariable(
            name: 'energy_level',
            placeholder: 'High/Medium/Low',
            required: false,
          ),
          TemplateVariable(
            name: 'todays_focus',
            placeholder: 'Main focus for today',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_1',
            placeholder: 'First goal',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_2',
            placeholder: 'Second goal',
            required: false,
          ),
          TemplateVariable(
            name: 'goal_3',
            placeholder: 'Third goal',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_1',
            placeholder: 'First thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_2',
            placeholder: 'Second thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'gratitude_3',
            placeholder: 'Third thing you\'re grateful for',
            required: false,
          ),
          TemplateVariable(
            name: 'key_events',
            placeholder: 'Important events today',
            required: false,
          ),
          TemplateVariable(
            name: 'lessons_learned',
            placeholder: 'What did you learn?',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_1',
            placeholder: 'First priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_2',
            placeholder: 'Second priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'priority_3',
            placeholder: 'Third priority for tomorrow',
            required: false,
          ),
          TemplateVariable(
            name: 'evening_reflection',
            placeholder: 'Reflect on your day',
            required: false,
          ),
          TemplateVariable(
            name: 'improvements',
            placeholder: 'What could be better?',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Project Plan Template
      TemplateModel(
        id: '',
        name: 'Project Plan',
        description: 'Template for planning and tracking project progress',
        content: '''# {{project_name}}

## Project Overview
**Start Date:** {{start_date}}
**End Date:** {{end_date}}
**Project Manager:** {{project_manager}}
**Team Members:** {{team_members}}

## Objectives
{{project_objectives}}

## Scope
### In Scope
- {{in_scope_1}}
- {{in_scope_2}}
- {{in_scope_3}}

### Out of Scope
- {{out_scope_1}}
- {{out_scope_2}}

## Milestones
- [ ] {{milestone_1}} - Due: {{milestone_1_date}}
- [ ] {{milestone_2}} - Due: {{milestone_2_date}}
- [ ] {{milestone_3}} - Due: {{milestone_3_date}}

## Tasks
- [ ] {{task_1}}
- [ ] {{task_2}}
- [ ] {{task_3}}
- [ ] {{task_4}}

## Resources Required
{{resources}}

## Risks and Mitigation
{{risks}}

## Success Criteria
{{success_criteria}}''',
        variables: [
          TemplateVariable(
            name: 'project_name',
            placeholder: 'Enter project name',
            required: true,
          ),
          TemplateVariable(
            name: 'start_date',
            placeholder: 'Project start date',
            required: true,
          ),
          TemplateVariable(
            name: 'end_date',
            placeholder: 'Project end date',
            required: true,
          ),
          TemplateVariable(
            name: 'project_manager',
            placeholder: 'Project manager name',
            required: true,
          ),
          TemplateVariable(
            name: 'team_members',
            placeholder: 'List team members',
            required: false,
          ),
          TemplateVariable(
            name: 'project_objectives',
            placeholder: 'What are the main goals?',
            required: true,
          ),
          TemplateVariable(
            name: 'in_scope_1',
            placeholder: 'First in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'in_scope_2',
            placeholder: 'Second in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'in_scope_3',
            placeholder: 'Third in-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'out_scope_1',
            placeholder: 'First out-of-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'out_scope_2',
            placeholder: 'Second out-of-scope item',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_1',
            placeholder: 'First milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_1_date',
            placeholder: 'Milestone 1 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_2',
            placeholder: 'Second milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_2_date',
            placeholder: 'Milestone 2 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_3',
            placeholder: 'Third milestone',
            required: false,
          ),
          TemplateVariable(
            name: 'milestone_3_date',
            placeholder: 'Milestone 3 due date',
            required: false,
          ),
          TemplateVariable(
            name: 'task_1',
            placeholder: 'First task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_2',
            placeholder: 'Second task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_3',
            placeholder: 'Third task',
            required: false,
          ),
          TemplateVariable(
            name: 'task_4',
            placeholder: 'Fourth task',
            required: false,
          ),
          TemplateVariable(
            name: 'resources',
            placeholder: 'Required resources',
            required: false,
          ),
          TemplateVariable(
            name: 'risks',
            placeholder: 'Potential risks and mitigation',
            required: false,
          ),
          TemplateVariable(
            name: 'success_criteria',
            placeholder: 'How will success be measured?',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Book Review Template
      TemplateModel(
        id: '',
        name: 'Book Review',
        description: 'Template for reviewing and reflecting on books',
        content: '''# Book Review: {{book_title}}

**Author:** {{author}}
**Genre:** {{genre}}
**Rating:** {{rating}}/5 ⭐
**Date Read:** {{date_read}}

## Summary
{{book_summary}}

## Key Takeaways
- {{takeaway_1}}
- {{takeaway_2}}
- {{takeaway_3}}

## Favorite Quotes
> "{{quote_1}}"

> "{{quote_2}}"

## Characters
{{character_analysis}}

## Themes
{{themes}}

## Personal Reflection
{{personal_reflection}}

## Would I Recommend?
{{recommendation}}

## Similar Books
- {{similar_book_1}}
- {{similar_book_2}}''',
        variables: [
          TemplateVariable(
            name: 'book_title',
            placeholder: 'Enter book title',
            required: true,
          ),
          TemplateVariable(
            name: 'author',
            placeholder: 'Author name',
            required: true,
          ),
          TemplateVariable(
            name: 'genre',
            placeholder: 'Book genre',
            required: false,
          ),
          TemplateVariable(name: 'rating', placeholder: '1-5', required: true),
          TemplateVariable(
            name: 'date_read',
            placeholder: 'When did you finish?',
            required: false,
          ),
          TemplateVariable(
            name: 'book_summary',
            placeholder: 'Brief summary of the book',
            required: false,
          ),
          TemplateVariable(
            name: 'takeaway_1',
            placeholder: 'First key takeaway',
            required: false,
          ),
          TemplateVariable(
            name: 'takeaway_2',
            placeholder: 'Second key takeaway',
            required: false,
          ),
          TemplateVariable(
            name: 'takeaway_3',
            placeholder: 'Third key takeaway',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_1',
            placeholder: 'Favorite quote from the book',
            required: false,
          ),
          TemplateVariable(
            name: 'quote_2',
            placeholder: 'Another favorite quote',
            required: false,
          ),
          TemplateVariable(
            name: 'character_analysis',
            placeholder: 'Analysis of main characters',
            required: false,
          ),
          TemplateVariable(
            name: 'themes',
            placeholder: 'Main themes explored',
            required: false,
          ),
          TemplateVariable(
            name: 'personal_reflection',
            placeholder: 'How did this book impact you?',
            required: false,
          ),
          TemplateVariable(
            name: 'recommendation',
            placeholder: 'Would you recommend it?',
            required: false,
          ),
          TemplateVariable(
            name: 'similar_book_1',
            placeholder: 'Similar book 1',
            required: false,
          ),
          TemplateVariable(
            name: 'similar_book_2',
            placeholder: 'Similar book 2',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Retrospective Template
      TemplateModel(
        id: '',
        name: 'Retrospective',
        description: 'Template for team retrospectives and sprint reviews',
        content: '''# Retrospective - {{sprint_name}}

**Date:** {{date}}
**Sprint Duration:** {{sprint_duration}}
**Team Members:** {{team_members}}

## What Went Well ✅
- {{positive_1}}
- {{positive_2}}
- {{positive_3}}

## What Could Be Improved 🔧
- {{improvement_1}}
- {{improvement_2}}
- {{improvement_3}}

## What We Learned 📚
{{lessons_learned}}

## Action Items for Next Sprint
- [ ] {{action_1}} - Owner: {{owner_1}}
- [ ] {{action_2}} - Owner: {{owner_2}}
- [ ] {{action_3}} - Owner: {{owner_3}}

## Metrics
**Velocity:** {{velocity}}
**Bugs Fixed:** {{bugs_fixed}}
**Features Completed:** {{features_completed}}
**Team Satisfaction:** {{satisfaction}}/10

## Notes
{{additional_notes}}''',
        variables: [
          TemplateVariable(
            name: 'sprint_name',
            placeholder: 'Sprint name or number',
            required: true,
          ),
          TemplateVariable(
            name: 'date',
            placeholder: 'Retrospective date',
            required: true,
          ),
          TemplateVariable(
            name: 'sprint_duration',
            placeholder: 'Sprint duration (e.g., 2 weeks)',
            required: false,
          ),
          TemplateVariable(
            name: 'team_members',
            placeholder: 'List of attendees',
            required: false,
          ),
          TemplateVariable(
            name: 'positive_1',
            placeholder: 'First positive point',
            required: false,
          ),
          TemplateVariable(
            name: 'positive_2',
            placeholder: 'Second positive point',
            required: false,
          ),
          TemplateVariable(
            name: 'positive_3',
            placeholder: 'Third positive point',
            required: false,
          ),
          TemplateVariable(
            name: 'improvement_1',
            placeholder: 'First area for improvement',
            required: false,
          ),
          TemplateVariable(
            name: 'improvement_2',
            placeholder: 'Second area for improvement',
            required: false,
          ),
          TemplateVariable(
            name: 'improvement_3',
            placeholder: 'Third area for improvement',
            required: false,
          ),
          TemplateVariable(
            name: 'lessons_learned',
            placeholder: 'Key lessons from this sprint',
            required: false,
          ),
          TemplateVariable(
            name: 'action_1',
            placeholder: 'First action item',
            required: false,
          ),
          TemplateVariable(
            name: 'owner_1',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_2',
            placeholder: 'Second action item',
            required: false,
          ),
          TemplateVariable(
            name: 'owner_2',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'action_3',
            placeholder: 'Third action item',
            required: false,
          ),
          TemplateVariable(
            name: 'owner_3',
            placeholder: 'Person responsible',
            required: false,
          ),
          TemplateVariable(
            name: 'velocity',
            placeholder: 'Story points completed',
            required: false,
          ),
          TemplateVariable(
            name: 'bugs_fixed',
            placeholder: 'Number of bugs fixed',
            required: false,
          ),
          TemplateVariable(
            name: 'features_completed',
            placeholder: 'Number of features completed',
            required: false,
          ),
          TemplateVariable(
            name: 'satisfaction',
            placeholder: '1-10 scale',
            required: false,
          ),
          TemplateVariable(
            name: 'additional_notes',
            placeholder: 'Any additional notes',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Interview Notes Template
      TemplateModel(
        id: '',
        name: 'Interview Notes',
        description: 'Template for conducting and documenting interviews',
        content: '''# Interview Notes

**Candidate:** {{candidate_name}}
**Position:** {{position}}
**Date:** {{interview_date}}
**Interviewer(s):** {{interviewers}}
**Duration:** {{duration}}

## Background
**Experience:** {{experience}}
**Previous Roles:** {{previous_roles}}
**Education:** {{education}}

## Technical Skills Assessment
**Language/Framework 1:** {{skill_1_rating}}/5
**Language/Framework 2:** {{skill_2_rating}}/5
**Problem Solving:** {{problem_solving_rating}}/5

## Key Strengths
- {{strength_1}}
- {{strength_2}}
- {{strength_3}}

## Areas for Development
- {{development_1}}
- {{development_2}}

## Cultural Fit
{{cultural_fit_assessment}}

## Questions Asked
1. {{question_1}}
   - Response: {{response_1}}

2. {{question_2}}
   - Response: {{response_2}}

3. {{question_3}}
   - Response: {{response_3}}

## Overall Assessment
**Technical Score:** {{technical_score}}/10
**Communication Score:** {{communication_score}}/10
**Cultural Fit Score:** {{cultural_fit_score}}/10

## Recommendation
{{recommendation}}

## Next Steps
{{next_steps}}''',
        variables: [
          TemplateVariable(
            name: 'candidate_name',
            placeholder: 'Candidate name',
            required: true,
          ),
          TemplateVariable(
            name: 'position',
            placeholder: 'Position applied for',
            required: true,
          ),
          TemplateVariable(
            name: 'interview_date',
            placeholder: 'Interview date',
            required: true,
          ),
          TemplateVariable(
            name: 'interviewers',
            placeholder: 'Interviewer names',
            required: false,
          ),
          TemplateVariable(
            name: 'duration',
            placeholder: 'Interview duration',
            required: false,
          ),
          TemplateVariable(
            name: 'experience',
            placeholder: 'Years of experience',
            required: false,
          ),
          TemplateVariable(
            name: 'previous_roles',
            placeholder: 'Previous job titles',
            required: false,
          ),
          TemplateVariable(
            name: 'education',
            placeholder: 'Educational background',
            required: false,
          ),
          TemplateVariable(
            name: 'skill_1_rating',
            placeholder: '1-5',
            required: false,
          ),
          TemplateVariable(
            name: 'skill_2_rating',
            placeholder: '1-5',
            required: false,
          ),
          TemplateVariable(
            name: 'problem_solving_rating',
            placeholder: '1-5',
            required: false,
          ),
          TemplateVariable(
            name: 'strength_1',
            placeholder: 'First strength',
            required: false,
          ),
          TemplateVariable(
            name: 'strength_2',
            placeholder: 'Second strength',
            required: false,
          ),
          TemplateVariable(
            name: 'strength_3',
            placeholder: 'Third strength',
            required: false,
          ),
          TemplateVariable(
            name: 'development_1',
            placeholder: 'First area for development',
            required: false,
          ),
          TemplateVariable(
            name: 'development_2',
            placeholder: 'Second area for development',
            required: false,
          ),
          TemplateVariable(
            name: 'cultural_fit_assessment',
            placeholder: 'How well do they fit the culture?',
            required: false,
          ),
          TemplateVariable(
            name: 'question_1',
            placeholder: 'First question asked',
            required: false,
          ),
          TemplateVariable(
            name: 'response_1',
            placeholder: 'Candidate response',
            required: false,
          ),
          TemplateVariable(
            name: 'question_2',
            placeholder: 'Second question asked',
            required: false,
          ),
          TemplateVariable(
            name: 'response_2',
            placeholder: 'Candidate response',
            required: false,
          ),
          TemplateVariable(
            name: 'question_3',
            placeholder: 'Third question asked',
            required: false,
          ),
          TemplateVariable(
            name: 'response_3',
            placeholder: 'Candidate response',
            required: false,
          ),
          TemplateVariable(
            name: 'technical_score',
            placeholder: '1-10',
            required: false,
          ),
          TemplateVariable(
            name: 'communication_score',
            placeholder: '1-10',
            required: false,
          ),
          TemplateVariable(
            name: 'cultural_fit_score',
            placeholder: '1-10',
            required: false,
          ),
          TemplateVariable(
            name: 'recommendation',
            placeholder: 'Hire/No Hire/Maybe',
            required: false,
          ),
          TemplateVariable(
            name: 'next_steps',
            placeholder: 'What happens next?',
            required: false,
          ),
        ],
        isCustom: false,
      ),

      // Travel Planning Template
      TemplateModel(
        id: '',
        name: 'Travel Planning',
        description: 'Template for planning trips and travel itineraries',
        content: '''# Travel Plan: {{destination}}

**Trip Duration:** {{start_date}} to {{end_date}}
**Travelers:** {{travelers}}
**Budget:** {{budget}}

## Destination Overview
{{destination_overview}}

## Accommodation
**Hotel/Airbnb:** {{accommodation_name}}
**Address:** {{accommodation_address}}
**Check-in:** {{check_in_date}}
**Check-out:** {{check_out_date}}
**Cost:** {{accommodation_cost}}

## Transportation
**Flight/Train:** {{transport_type}}
**Departure:** {{departure_time}}
**Arrival:** {{arrival_time}}
**Booking Reference:** {{booking_ref}}

## Daily Itinerary

### Day 1 - {{day_1_date}}
{{day_1_activities}}

### Day 2 - {{day_2_date}}
{{day_2_activities}}

### Day 3 - {{day_3_date}}
{{day_3_activities}}

## Must-See Attractions
- {{attraction_1}}
- {{attraction_2}}
- {{attraction_3}}

## Restaurants to Try
- {{restaurant_1}}
- {{restaurant_2}}
- {{restaurant_3}}

## Packing List
- [ ] {{item_1}}
- [ ] {{item_2}}
- [ ] {{item_3}}
- [ ] {{item_4}}

## Important Information
**Currency:** {{currency}}
**Language:** {{language}}
**Weather:** {{weather}}
**Visa Required:** {{visa_required}}

## Emergency Contacts
**Embassy:** {{embassy_contact}}
**Travel Insurance:** {{insurance_contact}}

## Budget Breakdown
- Flights: {{flight_cost}}
- Accommodation: {{accommodation_cost}}
- Food: {{food_budget}}
- Activities: {{activities_budget}}
- Other: {{other_budget}}

## Notes
{{additional_notes}}''',
        variables: [
          TemplateVariable(
            name: 'destination',
            placeholder: 'Where are you going?',
            required: true,
          ),
          TemplateVariable(
            name: 'start_date',
            placeholder: 'Trip start date',
            required: true,
          ),
          TemplateVariable(
            name: 'end_date',
            placeholder: 'Trip end date',
            required: true,
          ),
          TemplateVariable(
            name: 'travelers',
            placeholder: 'Who is traveling?',
            required: false,
          ),
          TemplateVariable(
            name: 'budget',
            placeholder: 'Total budget',
            required: false,
          ),
          TemplateVariable(
            name: 'destination_overview',
            placeholder: 'Brief overview of destination',
            required: false,
          ),
          TemplateVariable(
            name: 'accommodation_name',
            placeholder: 'Hotel or Airbnb name',
            required: false,
          ),
          TemplateVariable(
            name: 'accommodation_address',
            placeholder: 'Address',
            required: false,
          ),
          TemplateVariable(
            name: 'check_in_date',
            placeholder: 'Check-in date',
            required: false,
          ),
          TemplateVariable(
            name: 'check_out_date',
            placeholder: 'Check-out date',
            required: false,
          ),
          TemplateVariable(
            name: 'accommodation_cost',
            placeholder: 'Cost per night',
            required: false,
          ),
          TemplateVariable(
            name: 'transport_type',
            placeholder: 'Flight/Train/Car',
            required: false,
          ),
          TemplateVariable(
            name: 'departure_time',
            placeholder: 'Departure time',
            required: false,
          ),
          TemplateVariable(
            name: 'arrival_time',
            placeholder: 'Arrival time',
            required: false,
          ),
          TemplateVariable(
            name: 'booking_ref',
            placeholder: 'Booking reference number',
            required: false,
          ),
          TemplateVariable(
            name: 'day_1_date',
            placeholder: 'Date',
            required: false,
          ),
          TemplateVariable(
            name: 'day_1_activities',
            placeholder: 'Activities for day 1',
            required: false,
          ),
          TemplateVariable(
            name: 'day_2_date',
            placeholder: 'Date',
            required: false,
          ),
          TemplateVariable(
            name: 'day_2_activities',
            placeholder: 'Activities for day 2',
            required: false,
          ),
          TemplateVariable(
            name: 'day_3_date',
            placeholder: 'Date',
            required: false,
          ),
          TemplateVariable(
            name: 'day_3_activities',
            placeholder: 'Activities for day 3',
            required: false,
          ),
          TemplateVariable(
            name: 'attraction_1',
            placeholder: 'First attraction',
            required: false,
          ),
          TemplateVariable(
            name: 'attraction_2',
            placeholder: 'Second attraction',
            required: false,
          ),
          TemplateVariable(
            name: 'attraction_3',
            placeholder: 'Third attraction',
            required: false,
          ),
          TemplateVariable(
            name: 'restaurant_1',
            placeholder: 'Restaurant 1',
            required: false,
          ),
          TemplateVariable(
            name: 'restaurant_2',
            placeholder: 'Restaurant 2',
            required: false,
          ),
          TemplateVariable(
            name: 'restaurant_3',
            placeholder: 'Restaurant 3',
            required: false,
          ),
          TemplateVariable(
            name: 'item_1',
            placeholder: 'Packing item',
            required: false,
          ),
          TemplateVariable(
            name: 'item_2',
            placeholder: 'Packing item',
            required: false,
          ),
          TemplateVariable(
            name: 'item_3',
            placeholder: 'Packing item',
            required: false,
          ),
          TemplateVariable(
            name: 'item_4',
            placeholder: 'Packing item',
            required: false,
          ),
          TemplateVariable(
            name: 'currency',
            placeholder: 'Local currency',
            required: false,
          ),
          TemplateVariable(
            name: 'language',
            placeholder: 'Primary language',
            required: false,
          ),
          TemplateVariable(
            name: 'weather',
            placeholder: 'Expected weather',
            required: false,
          ),
          TemplateVariable(
            name: 'visa_required',
            placeholder: 'Yes/No',
            required: false,
          ),
          TemplateVariable(
            name: 'embassy_contact',
            placeholder: 'Embassy contact info',
            required: false,
          ),
          TemplateVariable(
            name: 'insurance_contact',
            placeholder: 'Insurance contact info',
            required: false,
          ),
          TemplateVariable(
            name: 'flight_cost',
            placeholder: 'Flight cost',
            required: false,
          ),
          TemplateVariable(
            name: 'food_budget',
            placeholder: 'Food budget',
            required: false,
          ),
          TemplateVariable(
            name: 'activities_budget',
            placeholder: 'Activities budget',
            required: false,
          ),
          TemplateVariable(
            name: 'other_budget',
            placeholder: 'Other expenses',
            required: false,
          ),
          TemplateVariable(
            name: 'additional_notes',
            placeholder: 'Any additional notes',
            required: false,
          ),
        ],
        isCustom: false,
      ),
    ];
  }

  // ==================== Helper Methods for Data Conversion ====================

  /// Convert NoteModel to Supabase-compatible map
  Map<String, dynamic> _noteToSupabaseMap(NoteModel note) {
    return {
      'title': note.title,
      'description': note.description,
      'timestamp': note.timestamp,
      'category_image_index': note.categoryImageIndex,
      'is_done': note.isDone,
      'custom_image_url': note.customImageUrl,
      'is_pinned': note.isPinned,
      'tags': note.tags,
      'created_at': note.createdAt.toIso8601String(),
      'updated_at': note.updatedAt.toIso8601String(),
      'outgoing_links': note.outgoingLinks,
      'audio_urls': note.audioUrls,
      'image_urls': note.imageUrls,
      'drawing_urls': note.drawingUrls,
      'folder_id': note.folderId,
      'is_shared': note.isShared,
      'collaborator_ids': note.collaboratorIds,
      'collaborators': note.collaborators,
      'source_url': note.sourceUrl,
      'reminder':
          note.reminder != null ? jsonEncode(note.reminder!.toMap()) : null,
      'view_count': note.viewCount,
      'word_count': note.wordCount,
      'owner_id': note.ownerId,
      'user_id': note.userId,
    };
  }

  /// Convert Supabase map to NoteModel
  NoteModel _noteFromSupabaseMap(Map<String, dynamic> data) {
    ReminderModel? reminder;
    if (data['reminder'] != null) {
      final reminderData = data['reminder'];
      if (reminderData is String) {
        // If it's a JSON string, decode it first
        reminder = ReminderModel.fromMap(
          jsonDecode(reminderData) as Map<String, dynamic>,
        );
      } else if (reminderData is Map) {
        // If it's already a Map, use it directly
        reminder = ReminderModel.fromMap(reminderData as Map<String, dynamic>);
      }
    }

    return NoteModel(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      timestamp: data['timestamp'] as String? ?? '',
      categoryImageIndex: data['category_image_index'] as int? ?? 0,
      isDone: data['is_done'] as bool? ?? false,
      customImageUrl: data['custom_image_url'] as String?,
      isPinned: data['is_pinned'] as bool? ?? false,
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      outgoingLinks: List<String>.from(data['outgoing_links'] ?? []),
      audioUrls: List<String>.from(data['audio_urls'] ?? []),
      imageUrls: List<String>.from(data['image_urls'] ?? []),
      drawingUrls: List<String>.from(data['drawing_urls'] ?? []),
      folderId: data['folder_id'] as String?,
      isShared: data['is_shared'] as bool? ?? false,
      collaboratorIds: List<String>.from(data['collaborator_ids'] ?? []),
      collaborators:
          data['collaborators'] != null
              ? List<Map<String, dynamic>>.from(
                (data['collaborators'] as List).map(
                  (item) => Map<String, dynamic>.from(item as Map),
                ),
              )
              : [],
      sourceUrl: data['source_url'] as String?,
      reminder: reminder,
      viewCount: data['view_count'] as int? ?? 0,
      wordCount: data['word_count'] as int? ?? 0,
      ownerId: data['owner_id'] as String?,
      userId: data['user_id'] as String?,
    );
  }

  /// Convert FolderModel to Supabase-compatible map
  Map<String, dynamic> _folderToSupabaseMap(FolderModel folder) {
    return {
      'name': folder.name,
      'color': folder.color,
      'parent_id': folder.parentId,
      'note_count': folder.noteCount,
      'is_favorite': folder.isFavorite,
      'created_at': folder.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert Supabase map to FolderModel
  FolderModel _folderFromSupabaseMap(Map<String, dynamic> data) {
    return FolderModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      color: data['color'] as String? ?? '#2196F3',
      parentId: data['parent_id'] as String?,
      noteCount: data['note_count'] as int? ?? 0,
      isFavorite: data['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  /// Convert TemplateModel to Supabase-compatible map
  Map<String, dynamic> _templateToSupabaseMap(TemplateModel template) {
    return {
      'name': template.name,
      'description': template.description,
      'content': template.content,
      'variables': template.variables.map((v) => v.toMap()).toList(),
      'usage_count': template.usageCount,
      'is_custom': template.isCustom,
      'created_at': template.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert Supabase map to TemplateModel
  TemplateModel _templateFromSupabaseMap(Map<String, dynamic> data) {
    return TemplateModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      content: data['content'] as String? ?? '',
      variables:
          (data['variables'] as List<dynamic>?)
              ?.map((v) => TemplateVariable.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      usageCount: data['usage_count'] as int? ?? 0,
      isCustom: data['is_custom'] as bool? ?? false,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  // ==================== Debug and Performance Utilities ====================

  /// Get performance statistics for all operations (simplified)
  Map<String, dynamic> getPerformanceStats() {
    return <String, dynamic>{};
  }

  /// Get recent performance logs (simplified)
  List<dynamic> getRecentPerformanceLogs([int count = 10]) {
    return <dynamic>[];
  }

  /// Print performance summary to debug console (simplified)
  void printPerformanceSummary() {
    debugPrint('Performance monitoring temporarily disabled');
  }

  /// Clear all performance logs (simplified)
  void clearPerformanceLogs() {
    debugPrint('Performance logs cleared (no-op)');
  }

  /// Get current debug configuration
  Map<String, dynamic> getDebugConfig() {
    return DebugConfig.instance.toMap();
  }

  /// Enable verbose logging for debugging
  void enableVerboseLogging(bool enabled) {
    DebugConfig.instance.enableVerboseLogging(enabled);
    if (enabled && DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('🔧 Verbose logging enabled for SupabaseService');
    }
  }

  /// Enable performance monitoring
  void enablePerformanceMonitoring(bool enabled) {
    DebugConfig.instance.enablePerformanceMonitoring(enabled);
    if (enabled && DebugConfig.instance.isPerformanceMonitoringEnabled) {
      debugPrint('📊 Performance monitoring enabled for SupabaseService');
    }
  }

  /// Enable operation timing
  void enableOperationTiming(bool enabled) {
    DebugConfig.instance.enableOperationTiming(enabled);
    if (enabled && DebugConfig.instance.isOperationTimingEnabled) {
      debugPrint('⏱️ Operation timing enabled for SupabaseService');
    }
  }

  /// Set performance warning threshold
  void setPerformanceWarningThreshold(int milliseconds) {
    DebugConfig.instance.setPerformanceWarningThreshold(milliseconds);
    if (DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('⚠️ Performance warning threshold set to ${milliseconds}ms');
    }
  }

  /// Enable all debug features
  void enableAllDebugFeatures() {
    DebugConfig.instance.enableAllDebugFeatures();
    if (DebugConfig.instance.isVerboseLoggingEnabled) {
      debugPrint('🔧 All debug features enabled for SupabaseService');
    }
  }

  /// Disable all debug features
  void disableAllDebugFeatures() {
    final wasVerbose = DebugConfig.instance.isVerboseLoggingEnabled;
    DebugConfig.instance.disableAllDebugFeatures();
    if (wasVerbose) {
      debugPrint('🔧 All debug features disabled for SupabaseService');
    }
  }

  // ==================== Daily Note Methods (Stubs) ====================

  /// Get daily note for a specific date
  Future<SupabaseOperationResult<NoteModel?>> getDailyNoteForDate(
    String userId,
    DateTime date,
  ) async {
    return await _executeWithRetry<NoteModel?>('getDailyNoteForDate', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to access daily notes');
      }

      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateStr = normalizedDate.toIso8601String().split('T')[0];
      final noteTitle = 'Daily Note - $dateStr';

      // Try to find existing daily note
      final response =
          await _supabase
              .from('notes')
              .select()
              .eq('user_id', userId)
              .eq('title', noteTitle)
              .maybeSingle();

      if (response != null) {
        return _noteFromSupabaseMap(response);
      }

      // If no existing note, create a new one
      final newNote = NoteModel(
        id: '', // Will be set by database
        title: noteTitle,
        description: '',
        timestamp: DateTime.now().toIso8601String(),
        categoryImageIndex: 0,
        isDone: false,
        tags: ['daily'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: userId,
      );

      final createResult = await createNote(newNote);
      if (createResult.success && createResult.data != null) {
        // Fetch and return the created note
        final createdResponse =
            await _supabase
                .from('notes')
                .select()
                .eq('id', createResult.data!)
                .eq('user_id', userId)
                .single();

        return _noteFromSupabaseMap(createdResponse);
      }

      return null;
    }, parameters: {'date': date.toIso8601String()});
  }

  /// Get weekly note for a specific date
  Future<SupabaseOperationResult<NoteModel?>> getWeeklyNoteForDate(
    String userId,
    DateTime date,
  ) async {
    return await _executeWithRetry<NoteModel?>(
      'getWeeklyNoteForDate',
      () async {
        if (!isAuthenticated) {
          throw Exception('Authentication required to access weekly notes');
        }

        // Calculate week start (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final normalizedWeekStart = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day,
        );
        final weekStr = normalizedWeekStart.toIso8601String().split('T')[0];
        final noteTitle = 'Weekly Note - Week of $weekStr';

        // Try to find existing weekly note
        final response =
            await _supabase
                .from('notes')
                .select()
                .eq('user_id', userId)
                .eq('title', noteTitle)
                .maybeSingle();

        if (response != null) {
          return _noteFromSupabaseMap(response);
        }

        // If no existing note, create a new one
        final newNote = NoteModel(
          id: '',
          title: noteTitle,
          description: '',
          timestamp: DateTime.now().toIso8601String(),
          categoryImageIndex: 0,
          isDone: false,
          tags: ['weekly'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ownerId: userId,
        );

        final createResult = await createNote(newNote);
        if (createResult.success && createResult.data != null) {
          // Fetch and return the created note
          final createdResponse =
              await _supabase
                  .from('notes')
                  .select()
                  .eq('id', createResult.data!)
                  .eq('user_id', userId)
                  .single();

          return _noteFromSupabaseMap(createdResponse);
        }

        return null;
      },
      parameters: {'date': date.toIso8601String()},
    );
  }

  /// Get monthly note for a specific date
  Future<SupabaseOperationResult<NoteModel?>> getMonthlyNoteForDate(
    String userId,
    DateTime date,
  ) async {
    return await _executeWithRetry<NoteModel?>(
      'getMonthlyNoteForDate',
      () async {
        if (!isAuthenticated) {
          throw Exception('Authentication required to access monthly notes');
        }

        final monthStart = DateTime(date.year, date.month, 1);
        final monthStr = monthStart.toIso8601String().split('T')[0];
        final noteTitle = 'Monthly Note - $monthStr';

        // Try to find existing monthly note
        final response =
            await _supabase
                .from('notes')
                .select()
                .eq('user_id', userId)
                .eq('title', noteTitle)
                .maybeSingle();

        if (response != null) {
          return _noteFromSupabaseMap(response);
        }

        // If no existing note, create a new one
        final newNote = NoteModel(
          id: '',
          title: noteTitle,
          description: '',
          timestamp: DateTime.now().toIso8601String(),
          categoryImageIndex: 0,
          isDone: false,
          tags: ['monthly'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ownerId: userId,
        );

        final createResult = await createNote(newNote);
        if (createResult.success && createResult.data != null) {
          // Fetch and return the created note
          final createdResponse =
              await _supabase
                  .from('notes')
                  .select()
                  .eq('id', createResult.data!)
                  .eq('user_id', userId)
                  .single();

          return _noteFromSupabaseMap(createdResponse);
        }

        return null;
      },
      parameters: {'date': date.toIso8601String()},
    );
  }

  /// Get daily note preferences
  Future<SupabaseOperationResult<Map<String, dynamic>>> getDailyNotePreferences(
    String userId,
  ) async {
    return await _executeWithRetry<Map<String, dynamic>>(
      'getDailyNotePreferences',
      () async {
        if (!isAuthenticated) {
          throw Exception('Authentication required to access preferences');
        }

        final response =
            await _supabase
                .from('daily_note_preferences')
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (response != null) {
          return response;
        }

        // Return default preferences if none exist
        return <String, dynamic>{};
      },
      parameters: {'userId': userId},
    );
  }

  /// Save daily note preferences
  Future<SupabaseOperationResult<void>> saveDailyNotePreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    return await _executeWithRetry<void>('saveDailyNotePreferences', () async {
      if (!isAuthenticated) {
        throw Exception('Authentication required to save preferences');
      }

      // Check if preferences already exist
      final existing =
          await _supabase
              .from('daily_note_preferences')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      if (existing != null) {
        // Update existing preferences
        await _supabase
            .from('daily_note_preferences')
            .update({
              ...preferences,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } else {
        // Insert new preferences
        await _supabase.from('daily_note_preferences').insert({
          'user_id': userId,
          ...preferences,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }, parameters: {'userId': userId});
  }
}
