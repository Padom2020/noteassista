import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Listen to auth state changes
    _authService.stateChanges.listen((event) {
      if (!mounted) return;

      switch (event.state) {
        case AuthenticationState.authenticated:
          if (event.user != null) {
            ErrorHandler.logInfo(
              'SignupScreen',
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePasswordMatch(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signup() async {
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
      // Clear any previous errors
      _authService.clearLastError();

      // Create user account in Supabase Auth
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Navigation is handled by the auth state listener
      ErrorHandler.logInfo('SignupScreen', 'Signup attempt completed');
    } on AuthServiceException catch (e) {
      ErrorHandler.logError(
        'SignupScreen',
        'AuthServiceException: ${e.message}',
      );
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e.message);
      }
    } on AuthException catch (e) {
      ErrorHandler.logError('SignupScreen', 'AuthException: ${e.message}');
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          ErrorHandler.getAuthErrorMessage(e.message),
        );
      }
    } catch (e) {
      ErrorHandler.logError('SignupScreen', 'Unexpected error during signup');
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'An unexpected error occurred during signup',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/noteassista-logo-transparent.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.note_alt,
                        size: 55,
                        color: Colors.black,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),

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
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password should be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: _validatePasswordMatch,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
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
                          : const Text('Sign Up'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Already have an account? Login'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
