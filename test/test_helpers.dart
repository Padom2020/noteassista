import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock Firebase platform for testing
class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp(name);
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp(name ?? defaultFirebaseAppName);
  }

  @override
  List<FirebaseAppPlatform> get apps => [
    MockFirebaseApp(defaultFirebaseAppName),
  ];
}

/// Mock Firebase app for testing
class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp(String name)
    : super(
        name,
        const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: 'fake-app-id',
          messagingSenderId: 'fake-sender-id',
          projectId: 'fake-project-id',
        ),
      );

  @override
  Future<void> delete() async {}

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}
}

/// Sets up Firebase mocks for testing
Future<void> setupFirebaseAuthMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the mock Firebase platform
  FirebasePlatform.instance = MockFirebasePlatform();

  // Mock Firebase Auth
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_auth'),
        (methodCall) async {
          if (methodCall.method == 'Auth#registerIdTokenListener') {
            return {'name': '[DEFAULT]'};
          }
          if (methodCall.method == 'Auth#registerAuthStateListener') {
            return {'name': '[DEFAULT]'};
          }
          if (methodCall.method == 'Auth#currentUser') {
            return null;
          }
          return null;
        },
      );

  // Mock Firestore
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/cloud_firestore'),
        (methodCall) async {
          return null;
        },
      );
}

/// Cleans up Firebase mocks after testing
void tearDownFirebaseAuthMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_auth'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/cloud_firestore'),
        null,
      );
}
