import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/unified_user.dart';
import '../models/supabase_user_adapter.dart';
import '../utils/error_handler.dart';
import 'supabase_service.dart';

/// Authentication state enumeration
enum AuthenticationState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  sessionExpired,
  error,
}

/// Authentication state change event
class AuthStateChangeEvent {
  final AuthenticationState state;
  final UnifiedUser? user;
  final String? error;
  final DateTime timestamp;

  AuthStateChangeEvent({required this.state, this.user, this.error})
    : timestamp = DateTime.now();

  @override
  String toString() {
    return 'AuthStateChangeEvent(state: $state, user: ${user?.uid}, error: $error, timestamp: $timestamp)';
  }
}

/// Exception thrown when authentication operations fail
class AuthServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AuthServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'AuthServiceException: $message${code != null ? ' (Code: $code)' : ''}';
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  String? _lastError;

  // Authentication state management
  AuthenticationState _currentState = AuthenticationState.initial;
  final StreamController<AuthStateChangeEvent> _stateController =
      StreamController<AuthStateChangeEvent>.broadcast();
  Timer? _sessionCheckTimer;
  String? _preservedUserContext;
  Map<String, dynamic> _authFlowContext = {};

  // Session management
  static const Duration _sessionCheckInterval = Duration(minutes: 5);
  static const Duration _sessionWarningThreshold = Duration(minutes: 10);
  static const Duration _sessionRefreshThreshold = Duration(minutes: 15);

  AuthService() {
    _initializeAuth();
  }

  void _initializeAuth() {
    try {
      // Supabase is initialized globally, so we can use it directly
      _isInitialized = true;
      _logDebug('Supabase Auth initialized successfully');

      // Set initial state based on current session
      _updateAuthState();

      // Start session monitoring
      _startSessionMonitoring();
    } catch (e) {
      _logError('Failed to initialize Supabase Auth', e);
      _isInitialized = false;
      _emitStateChange(AuthenticationState.error, error: e.toString());
    }
  }

  /// Update authentication state based on current session
  void _updateAuthState() {
    try {
      final session = _supabase.auth.currentSession;
      final user = session?.user;

      if (user != null) {
        // Check if session is expired or about to expire
        if (_isSessionExpired(session!)) {
          _emitStateChange(AuthenticationState.sessionExpired);
        } else {
          _emitStateChange(
            AuthenticationState.authenticated,
            user: SupabaseUserAdapter(user),
          );
        }
      } else {
        _emitStateChange(AuthenticationState.unauthenticated);
      }
    } catch (e) {
      _logError('Error updating auth state', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
    }
  }

  /// Check if session is expired or about to expire
  bool _isSessionExpired(Session session) {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
    );
    final now = DateTime.now();
    return expiresAt.isBefore(now.add(_sessionWarningThreshold));
  }

  /// Check if session needs refresh (before warning threshold)
  bool _shouldRefreshSession(Session session) {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
    );
    final now = DateTime.now();
    return expiresAt.isBefore(now.add(_sessionRefreshThreshold));
  }

  /// Start monitoring session expiration
  void _startSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(_sessionCheckInterval, (_) {
      _checkSessionExpiration();
    });
  }

  /// Check for session expiration and handle accordingly
  void _checkSessionExpiration() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        if (_isSessionExpired(session)) {
          _logDebug('Session is about to expire, attempting refresh');

          // Try to refresh the session
          final refreshed = await refreshSession();
          if (!refreshed) {
            _logDebug('Session refresh failed, marking as expired');
            await handleSessionExpiration();
          }
        } else if (_shouldRefreshSession(session)) {
          _logDebug('Session needs proactive refresh');

          // Proactively refresh session before it gets too close to expiration
          await refreshSession();
        }
      }
    } catch (e) {
      _logError('Error checking session expiration', e);
    }
  }

  /// Emit authentication state change
  void _emitStateChange(
    AuthenticationState state, {
    UnifiedUser? user,
    String? error,
  }) {
    _currentState = state;
    final event = AuthStateChangeEvent(state: state, user: user, error: error);

    _logDebug('Auth state changed: $event');
    ErrorHandler.logInfo('AuthService', 'State transition: $_currentState');

    _stateController.add(event);
  }

  /// Get current authentication state
  AuthenticationState get currentState => _currentState;

  /// Stream of authentication state changes
  Stream<AuthStateChangeEvent> get stateChanges => _stateController.stream;

  /// Preserve user context for auth flow recovery
  void preserveUserContext(String context) {
    _preservedUserContext = context;
    _logDebug('User context preserved: $context');
  }

  /// Preserve detailed auth flow context
  void preserveAuthFlowContext(Map<String, dynamic> context) {
    _authFlowContext = Map.from(context);
    _logDebug('Auth flow context preserved: ${context.keys.join(', ')}');
  }

  /// Get and clear preserved user context
  String? getAndClearPreservedContext() {
    final context = _preservedUserContext;
    _preservedUserContext = null;
    if (context != null) {
      _logDebug('Retrieved preserved context: $context');
    }
    return context;
  }

  /// Get and clear preserved auth flow context
  Map<String, dynamic> getAndClearAuthFlowContext() {
    final context = Map<String, dynamic>.from(_authFlowContext);
    _authFlowContext.clear();
    if (context.isNotEmpty) {
      _logDebug('Retrieved auth flow context: ${context.keys.join(', ')}');
    }
    return context;
  }

  /// Handle session expiration gracefully
  Future<void> handleSessionExpiration() async {
    try {
      _logDebug('Handling session expiration');

      // Preserve current context if user was doing something
      if (_currentState == AuthenticationState.authenticated) {
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          preserveAuthFlowContext({
            'reason': 'session_expired',
            'userId': currentUser.id,
            'email': currentUser.email,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        preserveUserContext('session_expired');
      }

      // Sign out to clear invalid session
      await signOut();

      // Emit session expired state
      _emitStateChange(AuthenticationState.sessionExpired);
    } catch (e) {
      _logError('Error handling session expiration', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
    }
  }

  /// Create or update user profile in the profiles table
  Future<void> _createOrUpdateProfile(User user) async {
    try {
      final displayName =
          user.userMetadata?['display_name'] as String? ??
          user.email?.split('@').first ??
          'User';

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': displayName,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      _logDebug('Profile created/updated for user: ${user.id}');
    } catch (e) {
      _logError('Error creating/updating profile', e);
      // Don't fail auth if profile creation fails
      // Try again with a small delay
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final displayName =
            user.userMetadata?['display_name'] as String? ??
            user.email?.split('@').first ??
            'User';

        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'display_name': displayName,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
        _logDebug('Profile created/updated on retry for user: ${user.id}');
      } catch (retryError) {
        _logError('Error creating/updating profile on retry', retryError);
      }
    }
  }

  /// Log debug messages with consistent formatting
  void _logDebug(String message) {
    debugPrint('AuthService: $message');
  }

  /// Log error messages with consistent formatting and store last error
  void _logError(String message, [dynamic error]) {
    final errorMsg = error != null ? '$message: $error' : message;
    _lastError = errorMsg;
    debugPrint('AuthService ERROR: $errorMsg');
  }

  /// Get the last error that occurred
  String? get lastError => _lastError;

  /// Clear the last error
  void clearLastError() {
    _lastError = null;
  }

  // Stream of unified user changes - primary auth state stream
  Stream<UnifiedUser?> get userChanges {
    if (!_isInitialized) {
      _logError(
        'Attempted to access userChanges when auth service not initialized',
      );
      // Return a stream that emits null when Supabase is not available
      return Stream.value(null);
    }

    try {
      return _supabase.auth.onAuthStateChange
          .map((authState) {
            try {
              final user = authState.session?.user;
              if (user != null) {
                _logDebug('User state changed: authenticated user ${user.id}');
                final unifiedUser = SupabaseUserAdapter(user);

                // Update internal state
                _emitStateChange(
                  AuthenticationState.authenticated,
                  user: unifiedUser,
                );

                return unifiedUser;
              } else {
                _logDebug('User state changed: no authenticated user');

                // Update internal state
                _emitStateChange(AuthenticationState.unauthenticated);

                return null;
              }
            } catch (e) {
              _logError('Error processing auth state change', e);
              _emitStateChange(AuthenticationState.error, error: e.toString());
              return null;
            }
          })
          .handleError((error) {
            _logError('Error in auth state stream', error);
            _emitStateChange(
              AuthenticationState.error,
              error: error.toString(),
            );
            return null;
          });
    } catch (e) {
      _logError('Failed to create auth state stream', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
      return Stream.value(null);
    }
  }

  // Stream of auth state changes - updated to emit UnifiedUser objects
  Stream<UnifiedUser?> get authStateChanges {
    return userChanges;
  }

  // Get current user as UnifiedUser
  UnifiedUser? get currentUser {
    if (!_isInitialized) {
      _logError(
        'Attempted to access currentUser when auth service not initialized',
      );
      return null;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _logDebug('Retrieved current user: ${user.id}');
        return SupabaseUserAdapter(user);
      } else {
        _logDebug('No current user available');
        return null;
      }
    } catch (e) {
      _logError('Error retrieving current user', e);
      return null;
    }
  }

  // Get raw Supabase user (for backward compatibility)
  User? get currentSupabaseUser {
    if (!_isInitialized) {
      _logError(
        'Attempted to access currentSupabaseUser when auth service not initialized',
      );
      return null;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _logDebug('Retrieved current Supabase user: ${user.id}');
      }
      return user;
    } catch (e) {
      _logError('Error retrieving current Supabase user', e);
      return null;
    }
  }

  // Sign up with email and password
  Future<AuthResponse?> signUp(String email, String password) async {
    if (!_isInitialized) {
      const error = 'Cannot sign up: Supabase Auth not initialized';
      _logError(error);
      _emitStateChange(AuthenticationState.error, error: error);
      throw const AuthServiceException(error, code: 'AUTH_NOT_INITIALIZED');
    }

    if (email.trim().isEmpty || password.isEmpty) {
      const error = 'Email and password cannot be empty';
      _logError(error);
      _emitStateChange(AuthenticationState.error, error: error);
      throw const AuthServiceException(error, code: 'INVALID_INPUT');
    }

    try {
      _emitStateChange(AuthenticationState.loading);
      _logDebug('Attempting to sign up user with email: $email');

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        _logDebug('Sign up successful for user: ${response.user!.id}');

        // Create user profile
        await _createOrUpdateProfile(response.user!);

        final unifiedUser = SupabaseUserAdapter(response.user!);
        _emitStateChange(AuthenticationState.authenticated, user: unifiedUser);

        // Initialize predefined templates for new user
        try {
          await SupabaseService.instance.createPredefinedTemplates();
          _logDebug('Predefined templates created for new user');
        } catch (e) {
          _logDebug('Could not create predefined templates: $e');
          // Don't fail signup if templates can't be created
        }
      } else {
        _logDebug('Sign up completed but no user returned');
        _emitStateChange(AuthenticationState.unauthenticated);
      }

      return response;
    } on AuthException catch (e) {
      _logError('Supabase auth error during sign up', e);
      _emitStateChange(AuthenticationState.error, error: e.message);
      throw AuthServiceException(
        _getReadableErrorMessage(e.message),
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      _logError('Unexpected error during sign up', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
      throw AuthServiceException(
        'An unexpected error occurred during sign up',
        originalError: e,
      );
    }
  }

  // Sign in with email and password
  Future<AuthResponse?> signIn(String email, String password) async {
    if (!_isInitialized) {
      const error = 'Cannot sign in: Supabase Auth not initialized';
      _logError(error);
      _emitStateChange(AuthenticationState.error, error: error);
      throw const AuthServiceException(error, code: 'AUTH_NOT_INITIALIZED');
    }

    if (email.trim().isEmpty || password.isEmpty) {
      const error = 'Email and password cannot be empty';
      _logError(error);
      _emitStateChange(AuthenticationState.error, error: error);
      throw const AuthServiceException(error, code: 'INVALID_INPUT');
    }

    try {
      _emitStateChange(AuthenticationState.loading);
      _logDebug('Attempting to sign in user with email: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        _logDebug('Sign in successful for user: ${response.user!.id}');

        // Create or update user profile
        await _createOrUpdateProfile(response.user!);

        final unifiedUser = SupabaseUserAdapter(response.user!);
        _emitStateChange(AuthenticationState.authenticated, user: unifiedUser);

        // Start session monitoring after successful sign in
        _startSessionMonitoring();
      } else {
        _logDebug('Sign in completed but no user returned');
        _emitStateChange(AuthenticationState.unauthenticated);
      }

      return response;
    } on AuthException catch (e) {
      _logError('Supabase auth error during sign in', e);
      _emitStateChange(AuthenticationState.error, error: e.message);
      throw AuthServiceException(
        _getReadableErrorMessage(e.message),
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      _logError('Unexpected error during sign in', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
      throw AuthServiceException(
        'An unexpected error occurred during sign in',
        originalError: e,
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!_isInitialized) {
      _logError('Cannot sign out: Supabase Auth not initialized');
      _emitStateChange(AuthenticationState.unauthenticated);
      return; // Gracefully handle this case - user might already be signed out
    }

    try {
      _logDebug('Attempting to sign out current user');

      // Stop session monitoring
      _sessionCheckTimer?.cancel();

      await _supabase.auth.signOut();
      _logDebug('Sign out successful');

      // Clear preserved context on explicit sign out (not session expiration)
      if (_currentState != AuthenticationState.sessionExpired) {
        _preservedUserContext = null;
        _authFlowContext.clear();
      }

      _emitStateChange(AuthenticationState.unauthenticated);
    } catch (e) {
      _logError('Error during sign out', e);
      // Still emit unauthenticated state even if sign out fails
      _emitStateChange(AuthenticationState.unauthenticated);
    }
  }

  /// Convert technical error messages to user-friendly ones
  String _getReadableErrorMessage(String? technicalMessage) {
    if (technicalMessage == null) return 'An unknown error occurred';

    switch (technicalMessage.toLowerCase()) {
      case 'invalid login credentials':
        return 'Invalid email or password';
      case 'email not confirmed':
        return 'Please check your email and confirm your account';
      case 'user already registered':
        return 'An account with this email already exists';
      case 'password should be at least 6 characters':
        return 'Password must be at least 6 characters long';
      case 'signup disabled':
        return 'New account registration is currently disabled';
      case 'email rate limit exceeded':
        return 'Too many requests. Please wait before trying again';
      default:
        return technicalMessage;
    }
  }

  // Check if auth is available
  bool get isAvailable => _isInitialized;

  /// Ensure the current user's profile exists in the database
  Future<void> ensureProfileExists() async {
    try {
      final user = currentSupabaseUser;
      if (user != null) {
        await _createOrUpdateProfile(user);
      }
    } catch (e) {
      _logError('Error ensuring profile exists', e);
    }
  }

  /// Check if there's an active authenticated session
  bool get hasActiveSession {
    try {
      return _isInitialized && _supabase.auth.currentSession != null;
    } catch (e) {
      _logError('Error checking active session', e);
      return false;
    }
  }

  /// Refresh the current session if possible
  Future<bool> refreshSession() async {
    if (!_isInitialized) {
      _logError('Cannot refresh session: Auth not initialized');
      _emitStateChange(
        AuthenticationState.error,
        error: 'Auth not initialized',
      );
      return false;
    }

    try {
      _logDebug('Attempting to refresh session');
      _emitStateChange(AuthenticationState.loading);

      final response = await _supabase.auth.refreshSession();
      if (response.session != null && response.user != null) {
        _logDebug('Session refresh successful');
        final unifiedUser = SupabaseUserAdapter(response.user!);
        _emitStateChange(AuthenticationState.authenticated, user: unifiedUser);
        return true;
      } else {
        _logDebug('Session refresh failed: no session returned');
        _emitStateChange(AuthenticationState.sessionExpired);
        return false;
      }
    } catch (e) {
      _logError('Error refreshing session', e);
      _emitStateChange(AuthenticationState.sessionExpired);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionCheckTimer?.cancel();
    _stateController.close();
  }

  /// Handle authentication state transitions with proper error recovery
  Future<void> handleAuthStateTransition(
    AuthenticationState fromState,
    AuthenticationState toState, {
    Map<String, dynamic>? context,
  }) async {
    try {
      _logDebug('Auth state transition: $fromState -> $toState');

      // Preserve context during critical transitions
      if (context != null && context.isNotEmpty) {
        preserveAuthFlowContext(context);
      }

      // Handle specific transition scenarios
      switch (toState) {
        case AuthenticationState.sessionExpired:
          await handleSessionExpiration();
          break;
        case AuthenticationState.unauthenticated:
          if (fromState == AuthenticationState.authenticated) {
            // User was signed out, preserve context for potential re-auth
            preserveUserContext('signed_out');
          }
          break;
        case AuthenticationState.authenticated:
          // Clear any error states and start session monitoring
          clearLastError();
          _startSessionMonitoring();
          break;
        case AuthenticationState.error:
          // Stop session monitoring on error
          _sessionCheckTimer?.cancel();
          break;
        default:
          break;
      }
    } catch (e) {
      _logError('Error handling auth state transition', e);
      _emitStateChange(AuthenticationState.error, error: e.toString());
    }
  }
}
