import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../screens/edit_note_screen.dart';

/// Service for handling navigation from the graph view with proper validation and error handling
class GraphNavigationService {
  final SupabaseService _supabaseService;
  final AuthService _authService;

  GraphNavigationService({
    SupabaseService? supabaseService,
    AuthService? authService,
  }) : _supabaseService = supabaseService ?? SupabaseService.instance,
       _authService = authService ?? AuthService();

  /// Navigate to a note from the graph view with comprehensive validation
  ///
  /// This method performs the following checks:
  /// 1. Validates input parameters
  /// 2. Validates user authentication
  /// 3. Checks if the note exists and is accessible
  /// 4. Handles navigation with proper error handling
  /// 5. Provides user feedback for various error conditions
  Future<bool> navigateToNote(
    BuildContext context,
    String nodeId, {
    bool showErrorMessages = true,
  }) async {
    // Input validation
    if (nodeId.isEmpty || nodeId.trim().isEmpty) {
      debugPrint(
        'GraphNavigationService.navigateToNote: Invalid node ID: $nodeId',
      );
      if (showErrorMessages && context.mounted) {
        _showErrorSnackBar(context, 'Invalid note identifier');
      }
      return false;
    }

    // Validate context
    if (!context.mounted) {
      debugPrint('GraphNavigationService.navigateToNote: Context not mounted');
      return false;
    }

    try {
      // Check authentication first
      final user = _authService.currentUser;
      if (user == null) {
        debugPrint(
          'GraphNavigationService.navigateToNote: User not authenticated',
        );
        if (showErrorMessages && context.mounted) {
          _showErrorSnackBar(context, 'Please log in to access notes');
        }
        return false;
      }

      // Validate user ID
      if (user.uid.isEmpty) {
        debugPrint('GraphNavigationService.navigateToNote: Invalid user ID');
        if (showErrorMessages && context.mounted) {
          _showErrorSnackBar(
            context,
            'Authentication error. Please log in again.',
          );
        }
        return false;
      }

      // Validate note access
      final noteExists = await validateNoteAccess(nodeId, user);
      if (!noteExists) {
        debugPrint(
          'GraphNavigationService.navigateToNote: Note access validation failed for: $nodeId',
        );
        if (showErrorMessages && context.mounted) {
          _showErrorSnackBar(context, 'Note not found or no longer accessible');
        }
        return false;
      }

      // Get the note data
      final noteResult = await _supabaseService.getNoteById(nodeId);
      if (!noteResult.success || noteResult.data == null) {
        debugPrint(
          'GraphNavigationService.navigateToNote: Failed to load note data for: $nodeId',
        );
        if (showErrorMessages && context.mounted) {
          _showErrorSnackBar(context, 'Unable to load note content');
        }
        return false;
      }

      final note = noteResult.data!;

      // Validate note data
      if (note.id.isEmpty || note.title.isEmpty) {
        debugPrint(
          'GraphNavigationService.navigateToNote: Invalid note data for: $nodeId',
        );
        if (showErrorMessages && context.mounted) {
          _showErrorSnackBar(context, 'Note data is corrupted');
        }
        return false;
      }

      // Navigate to the note
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
        );
        return true;
      }

      debugPrint(
        'GraphNavigationService.navigateToNote: Context no longer mounted after note load',
      );
      return false;
    } catch (e) {
      debugPrint(
        'GraphNavigationService.navigateToNote: Error navigating to note $nodeId: $e',
      );
      if (showErrorMessages && context.mounted) {
        _showErrorSnackBar(context, 'Failed to open note. Please try again.');
      }
      return false;
    }
  }

  /// Validate that a user has access to a specific note
  ///
  /// Performs comprehensive validation including:
  /// - Input parameter validation
  /// - User authentication status
  /// - User ID validation
  /// - Note existence in the database
  /// - User ownership/access permissions
  Future<bool> validateNoteAccess(String nodeId, dynamic user) async {
    // Input validation
    if (nodeId.isEmpty || nodeId.trim().isEmpty) {
      debugPrint(
        'GraphNavigationService.validateNoteAccess: Invalid node ID format',
      );
      return false;
    }

    // Validate node ID length (reasonable bounds)
    if (nodeId.length > 100) {
      debugPrint(
        'GraphNavigationService.validateNoteAccess: Node ID too long: ${nodeId.length} characters',
      );
      return false;
    }

    try {
      // Check if user is authenticated
      if (user == null) {
        debugPrint(
          'GraphNavigationService.validateNoteAccess: User not authenticated',
        );
        return false;
      }

      // Validate user ID
      if (user.uid.isEmpty || user.uid.trim().isEmpty) {
        debugPrint(
          'GraphNavigationService.validateNoteAccess: Invalid user ID',
        );
        return false;
      }

      // Check if note exists and user has access
      final noteResult = await _supabaseService.getNoteById(nodeId);
      if (!noteResult.success || noteResult.data == null) {
        debugPrint(
          'GraphNavigationService.validateNoteAccess: Note not found or inaccessible for node: $nodeId',
        );
        return false;
      }

      final note = noteResult.data!;

      // Additional validation of note data
      if (note.id != nodeId) {
        debugPrint(
          'GraphNavigationService.validateNoteAccess: Note ID mismatch. Expected: $nodeId, Got: ${note.id}',
        );
        return false;
      }

      if (note.ownerId != user.uid) {
        debugPrint(
          'GraphNavigationService.validateNoteAccess: Owner ID mismatch for note: $nodeId',
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint(
        'GraphNavigationService.validateNoteAccess: Error validating note access for $nodeId: $e',
      );
      return false;
    }
  }

  /// Check if a note exists without full validation (lighter weight check)
  ///
  /// This method performs a basic existence check without loading full note data
  Future<bool> noteExists(String nodeId, String userId) async {
    try {
      if (nodeId.isEmpty || nodeId.trim().isEmpty || userId.isEmpty) {
        return false;
      }

      final noteResult = await _supabaseService.getNoteById(nodeId);
      return noteResult.success && noteResult.data != null;
    } catch (e) {
      debugPrint('Error checking note existence: $e');
      return false;
    }
  }

  /// Handle navigation errors gracefully with user-friendly messages
  ///
  /// This method provides centralized error handling for navigation failures
  void handleNavigationError(
    BuildContext context,
    String nodeId,
    dynamic error, {
    bool showUserMessage = true,
  }) {
    debugPrint('Navigation error for node $nodeId: $error');

    if (!showUserMessage || !context.mounted) {
      return;
    }

    String userMessage;
    if (error.toString().contains('permission-denied')) {
      userMessage = 'You don\'t have permission to access this note';
    } else if (error.toString().contains('not-found')) {
      userMessage = 'This note no longer exists';
    } else if (error.toString().contains('unavailable')) {
      userMessage = 'Service temporarily unavailable. Please try again';
    } else if (error.toString().contains('unauthenticated')) {
      userMessage = 'Please log in to access notes';
    } else {
      userMessage = 'Unable to open note. Please try again';
    }

    _showErrorSnackBar(context, userMessage);
  }

  /// Batch validate multiple node IDs for efficiency
  ///
  /// Useful for validating multiple nodes at once, such as when filtering
  /// visible nodes in the graph view
  Future<Map<String, bool>> batchValidateNotes(
    List<String> nodeIds,
    dynamic user,
  ) async {
    final results = <String, bool>{};

    // Input validation
    if (nodeIds.isEmpty) {
      debugPrint(
        'GraphNavigationService.batchValidateNotes: Empty node IDs list',
      );
      return results;
    }

    // Validate batch size (prevent excessive requests)
    if (nodeIds.length > 1000) {
      debugPrint(
        'GraphNavigationService.batchValidateNotes: Too many node IDs: ${nodeIds.length}, limiting to 1000',
      );
      nodeIds = nodeIds.take(1000).toList();
    }

    if (user == null) {
      debugPrint(
        'GraphNavigationService.batchValidateNotes: User not authenticated, all validations fail',
      );
      // If no user, all validations fail
      for (final nodeId in nodeIds) {
        results[nodeId] = false;
      }
      return results;
    }

    // Validate user ID
    if (user.uid.isEmpty) {
      debugPrint('GraphNavigationService.batchValidateNotes: Invalid user ID');
      for (final nodeId in nodeIds) {
        results[nodeId] = false;
      }
      return results;
    }

    // Validate each node
    for (final nodeId in nodeIds) {
      // Skip invalid node IDs
      if (nodeId.isEmpty || nodeId.trim().isEmpty) {
        debugPrint(
          'GraphNavigationService.batchValidateNotes: Skipping invalid node ID: $nodeId',
        );
        results[nodeId] = false;
        continue;
      }

      try {
        results[nodeId] = await validateNoteAccess(nodeId, user);
      } catch (e) {
        debugPrint(
          'GraphNavigationService.batchValidateNotes: Error validating node $nodeId: $e',
        );
        results[nodeId] = false;
      }
    }

    return results;
  }

  /// Get current authenticated user
  ///
  /// Provides a centralized way to get the current user with null safety
  dynamic getCurrentUser() {
    return _authService.currentUser;
  }

  /// Check if user is currently authenticated
  bool get isAuthenticated => _authService.currentUser != null;

  /// Show error message to user via SnackBar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
}
