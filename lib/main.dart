import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/web_clipper_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
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
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
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
