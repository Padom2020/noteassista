import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sets up Supabase mocks for testing
Future<void> setupSupabaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock shared preferences for Supabase
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, Object>{};
          }
          return null;
        },
      );

  // Initialize Supabase for testing
  try {
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  } catch (e) {
    // Supabase might already be initialized, ignore error
  }
}

/// Cleans up Supabase mocks after testing
void tearDownSupabaseMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      );
}
