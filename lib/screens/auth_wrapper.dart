import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/user_extensions.dart';
import '../utils/error_handler.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final AuthService _authService;
  String? _preservedContext;
  Map<String, dynamic> _authFlowContext = {};

  @override
  void initState() {
    super.initState();
    _authService = AuthService();

    // Check for preserved context from session expiration
    _preservedContext = _authService.getAndClearPreservedContext();
    _authFlowContext = _authService.getAndClearAuthFlowContext();

    if (_preservedContext != null) {
      ErrorHandler.logInfo(
        'AuthWrapper',
        'Restored preserved context: $_preservedContext',
      );
    }

    if (_authFlowContext.isNotEmpty) {
      ErrorHandler.logInfo(
        'AuthWrapper',
        'Restored auth flow context: ${_authFlowContext.keys.join(', ')}',
      );
    }
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Authentication Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionExpiredScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Session Expired',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _authFlowContext.isNotEmpty
                    ? 'Your session has expired. Please sign in again to continue where you left off.'
                    : 'Your session has expired. Please sign in again to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Preserve context when navigating to login after session expiration
                if (_preservedContext != null) {
                  _authService.preserveUserContext(_preservedContext!);
                }
                if (_authFlowContext.isNotEmpty) {
                  _authService.preserveAuthFlowContext(_authFlowContext);
                }
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Sign In Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If Supabase Auth is not available, go directly to login screen
    if (!_authService.isAvailable) {
      ErrorHandler.logWarning(
        'AuthWrapper',
        'Supabase Auth not available, showing login screen',
      );
      return const LoginScreen();
    }

    return StreamBuilder<AuthStateChangeEvent>(
      stream: _authService.stateChanges,
      builder: (context, snapshot) {
        // Handle connection errors
        if (snapshot.hasError) {
          ErrorHandler.logError(
            'AuthWrapper',
            'Auth state stream error: ${snapshot.error}',
          );
          return _buildErrorScreen(
            'There was a problem with authentication. Please try again.',
          );
        }

        // Get current state
        final currentState =
            snapshot.hasData ? snapshot.data!.state : _authService.currentState;
        final currentUser =
            snapshot.hasData ? snapshot.data!.user : _authService.currentUser;

        switch (currentState) {
          case AuthenticationState.initial:
          case AuthenticationState.loading:
            return _buildLoadingScreen();

          case AuthenticationState.authenticated:
            if (currentUser != null && currentUser.hasValidAuthData) {
              currentUser.logUserState('AuthWrapper - Authenticated');
              return const HomeScreen();
            } else {
              ErrorHandler.logWarning(
                'AuthWrapper',
                'Authenticated but invalid user data',
              );
              return const LoginScreen();
            }

          case AuthenticationState.sessionExpired:
            ErrorHandler.logInfo(
              'AuthWrapper',
              'Session expired, showing session expired screen',
            );
            return _buildSessionExpiredScreen();

          case AuthenticationState.error:
            final error =
                snapshot.hasData
                    ? snapshot.data!.error
                    : 'Unknown authentication error';
            ErrorHandler.logError('AuthWrapper', 'Auth error state: $error');
            return _buildErrorScreen(
              error ?? 'An authentication error occurred',
            );

          case AuthenticationState.unauthenticated:
            ErrorHandler.logInfo(
              'AuthWrapper',
              'Unauthenticated, showing login screen',
            );
            return const LoginScreen();
        }
      },
    );
  }
}
