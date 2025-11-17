# Firebase Configuration Guide

This guide explains how to configure Firebase for both Android and iOS platforms.

## Prerequisites
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Email/Password authentication in Firebase Console:
   - Go to Authentication > Sign-in method
   - Enable "Email/Password" provider
3. Create a Cloud Firestore database:
   - Go to Firestore Database
   - Click "Create database"
   - Start in test mode (we'll add security rules later)

## Android Configuration

1. In Firebase Console, add an Android app to your project
2. Register your app with package name: `com.example.noteassista` (or your actual package name from `android/app/build.gradle`)
3. Download the `google-services.json` file
4. Place `google-services.json` in the `android/app/` directory
5. Ensure the following is in `android/build.gradle.kts`:
   ```kotlin
   dependencies {
       classpath("com.google.gms:google-services:4.4.0")
   }
   ```
6. Ensure the following is in `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
       id("com.google.gms.google-services")
   }
   ```

## iOS Configuration

1. In Firebase Console, add an iOS app to your project
2. Register your app with bundle ID: `com.example.noteassista` (or your actual bundle ID from `ios/Runner/Info.plist`)
3. Download the `GoogleService-Info.plist` file
4. Open `ios/Runner.xcworkspace` in Xcode
5. Drag `GoogleService-Info.plist` into the Runner folder in Xcode
6. Ensure "Copy items if needed" is checked
7. Update `ios/Podfile` to set minimum iOS version to 12.0:
   ```ruby
   platform :ios, '12.0'
   ```
8. Run `pod install` in the `ios` directory:
   ```bash
   cd ios
   pod install
   cd ..
   ```

## Verification

After configuration, run the app:
```bash
flutter run
```

The app should launch without Firebase initialization errors. Check the console for:
- "Firebase initialized successfully" (or similar message)
- No Firebase configuration errors

## Firestore Security Rules

Once the app is working, update Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /notes/{noteId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## Troubleshooting

### Android Issues
- Ensure `google-services.json` is in `android/app/` directory
- Check that package name matches in Firebase Console and `android/app/build.gradle`
- Run `flutter clean` and rebuild

### iOS Issues
- Ensure `GoogleService-Info.plist` is added to Xcode project (not just copied to folder)
- Check that bundle ID matches in Firebase Console and Xcode
- Run `pod install` in ios directory
- Run `flutter clean` and rebuild

### Common Errors
- "No Firebase App '[DEFAULT]' has been created" - Firebase not initialized properly
- "MissingPluginException" - Run `flutter clean` and rebuild
- Platform-specific errors - Check configuration files are in correct locations
