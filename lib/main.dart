import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/web_clipper_screen.dart';
import 'screens/whats_new_screen.dart';
import 'screens/edit_note_screen.dart';
import 'services/reminder_service.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/onboarding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    debugPrint('Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully');

    // Initialize database schema
    debugPrint('Initializing database schema...');
    await SupabaseService.initializeSchema();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    // Continue app execution even if Supabase fails
  }

  // Initialize reminder service
  final reminderService = ReminderService();
  try {
    await reminderService.initialize();
    debugPrint('Reminder service initialized successfully');
  } catch (e) {
    debugPrint('Reminder service initialization failed: $e');
    // Continue app execution even if reminder service fails
  }

  runApp(MyApp(reminderService: reminderService));
}

class MyApp extends StatefulWidget {
  final ReminderService reminderService;

  const MyApp({super.key, required this.reminderService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _intentDataStreamSubscription;
  final OnboardingService _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
    _initNotificationHandling();
    _checkForNewVersion();
  }

  /// Check if this is a new version and show What's New screen
  Future<void> _checkForNewVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final isNew = await _onboardingService.isNewVersion(currentVersion);

      if (isNew) {
        // Wait for the app to fully load before showing What's New
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => WhatsNewScreen(version: currentVersion),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }

  /// Initialize notification tap handling
  void _initNotificationHandling() {
    widget.reminderService.onNotificationTapped = (noteId, action) {
      _handleNotificationAction(noteId, action);
    };
  }

  /// Handle notification actions (tap, snooze, mark done)
  Future<void> _handleNotificationAction(String noteId, String? action) async {
    if (action == 'snooze') {
      // Capture context before async gap
      final context = _navigatorKey.currentContext;
      final scaffoldMessenger =
          context != null ? ScaffoldMessenger.of(context) : null;

      // Snooze the reminder for 10 minutes
      await widget.reminderService.snoozeReminder(noteId, noteId);

      // Show snackbar
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Reminder snoozed for 10 minutes')),
        );
      }
    } else if (action == 'mark_done') {
      // Capture context before async operations
      final context = _navigatorKey.currentContext;
      final scaffoldMessenger =
          context != null ? ScaffoldMessenger.of(context) : null;

      // Mark the note as done
      try {
        final authService = AuthService();
        final user = authService.currentUser;
        if (user != null) {
          // Update note status using SupabaseService
          final supabaseService = SupabaseService.instance;
          final result = await supabaseService.toggleNoteStatus(noteId, true);

          if (!result.success) {
            throw Exception(result.error ?? 'Failed to update note status');
          }
        }

        // Show snackbar
        if (scaffoldMessenger != null && mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Note marked as done')),
          );
        }
      } catch (e) {
        // Show error snackbar
        if (scaffoldMessenger != null && mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error marking note as done: $e')),
          );
        }
      }
    } else {
      // Default action: open the note
      _navigateToNote(noteId);
    }
  }

  /// Navigate to the note edit screen
  void _navigateToNote(String noteId) async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        // Get note details using SupabaseService and navigate to edit screen
        final supabaseService = SupabaseService.instance;
        final result = await supabaseService.getNoteById(noteId);

        if (result.success && result.data != null) {
          final note = result.data!;

          // Navigate to edit note screen using MaterialPageRoute
          if (mounted) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => EditNoteScreen(note: note),
              ),
            );
          }
        } else {
          throw Exception(result.error ?? 'Note not found');
        }
      }
    } catch (e) {
      // Show error snackbar
      if (mounted) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error opening note: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  /// Initialize sharing intent listeners
  void _initSharingIntent() {
    // For sharing while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        final firstFile = value.first;
        if (firstFile.path.startsWith('http')) {
          _handleSharedText(firstFile.path);
        }
      }
    });

    // For sharing while app is open
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              final firstFile = value.first;
              if (firstFile.path.startsWith('http')) {
                _handleSharedText(firstFile.path);
              }
            }
          },
          onError: (err) {
            debugPrint('Error receiving shared media: $err');
          },
        );
  }

  /// Handle shared text (URL)
  void _handleSharedText(String text) {
    // Check if the text is a URL
    final urlPattern = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    );

    if (urlPattern.hasMatch(text)) {
      // Navigate to web clipper screen
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => WebClipperScreen(sharedUrl: text),
          ),
        );
      });
    } else {
      // If not a URL, show a message
      Future.delayed(const Duration(milliseconds: 500), () {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please share a valid URL')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'NoteAssista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.grey[800]!,
          surface: Colors.white,
          error: const Color(0xFFB3261E),
        ),
        useMaterial3: true,

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: false,
        ),

        // Card theme
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB3261E), width: 2),
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),

        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Text button theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 4,
        ),

        // Checkbox theme
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.grey[400];
          }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),

        // Snackbar theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
