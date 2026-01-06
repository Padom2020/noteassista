import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _preservedContext;
  Map<String, dynamic> _authFlowContext = {};

  @override
  void initState() {
    super.initState();

    // Check for preserved context from session expiration
    _preservedContext = _authService.getAndClearPreservedContext();
    _authFlowContext = _authService.getAndClearAuthFlowContext();

    if (_preservedContext != null) {
      ErrorHandler.logInfo(
        'LoginScreen',
        'Restored preserved context: $_preservedContext',
      );

      // Show message to user about session expiration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final message =
              _authFlowContext['reason'] == 'session_expired'
                  ? 'Your session expired. Please sign in again to continue.'
                  : 'Please sign in to continue.';

          ErrorHandler.showWarningSnackBar(
            context,
            message,
            duration: const Duration(seconds: 5),
          );
        }
      });
    }

    if (_authFlowContext.isNotEmpty) {
      ErrorHandler.logInfo(
        'LoginScreen',
        'Restored auth flow context: ${_authFlowContext.keys.join(', ')}',
      );

      // Pre-fill email if available from context
      final email = _authFlowContext['email'] as String?;
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
    }

    // Listen to auth state changes
    _authService.stateChanges.listen((event) {
      if (!mounted) return;

      switch (event.state) {
        case AuthenticationState.authenticated:
          if (event.user != null) {
            ErrorHandler.logInfo(
              'LoginScreen',
              'User authenticated, navigating to home',
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
          break;
        case AuthenticationState.error:
          setState(() {
            _isLoading = false;
          });
          if (event.error != null) {
            ErrorHandler.showErrorSnackBar(context, event.error!);
          }
          break;
        case AuthenticationState.loading:
          setState(() {
            _isLoading = true;
          });
          break;
        default:
          setState(() {
            _isLoading = false;
          });
          break;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if auth service is available
    if (!_authService.isAvailable) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Authentication service is not available. Please check your internet connection.',
      );
      return;
    }

    try {
      // Preserve current context before attempting login
      if (_preservedContext != null) {
        _authService.preserveUserContext(_preservedContext!);
      }
      if (_authFlowContext.isNotEmpty) {
        _authService.preserveAuthFlowContext(_authFlowContext);
      }

      // Clear any previous errors
      _authService.clearLastError();

      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Navigation is handled by the auth state listener
      ErrorHandler.logInfo('LoginScreen', 'Login attempt completed');
    } on AuthServiceException catch (e) {
      ErrorHandler.logError(
        'LoginScreen',
        'AuthServiceException: ${e.message}',
      );
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e.message);
      }
    } on AuthException catch (e) {
      ErrorHandler.logError('LoginScreen', 'AuthException: ${e.message}');
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          ErrorHandler.getAuthErrorMessage(e.message),
        );
      }
    } catch (e) {
      ErrorHandler.logError('LoginScreen', 'Unexpected error during login');
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'An unexpected error occurred during login',
        );
      }
    }
  }

  void _navigateToSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/noteassista-logo-transparent.png',
                    height: 90,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.note_alt,
                        size: 60,
                        color: Colors.black,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 48),

                // Show warning if Supabase is not available
                if (!_authService.isAvailable)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Authentication service is offline. Please check your internet connection.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _navigateToSignup,
                  child: const Text("Don't have an account? Sign up"),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
