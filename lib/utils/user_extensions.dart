import '../models/unified_user.dart';
import 'package:flutter/foundation.dart';

/// Extension methods for safe user property access
extension UnifiedUserExtensions on UnifiedUser? {
  /// Safely get the user ID, returns null if user is null
  String? get safeUid => this?.uid;

  /// Safely get the user email, returns null if user is null
  String? get safeEmail => this?.email;

  /// Safely get the user display name, returns null if user is null
  String? get safeDisplayName => this?.displayName;

  /// Check if user is authenticated (not null)
  bool get isAuthenticated => this != null;

  /// Check if user is anonymous, returns true if user is null
  bool get isSafeAnonymous => this?.isAnonymous ?? true;

  /// Get user ID with fallback behavior
  String getUidOrFallback(String fallback) {
    final uid = safeUid;
    if (uid == null || uid.isEmpty) {
      debugPrint(
        'UserExtensions: Using fallback UID - user is null or has empty UID',
      );
      return fallback;
    }
    return uid;
  }

  /// Get user email with fallback behavior
  String getEmailOrFallback(String fallback) {
    final email = safeEmail;
    if (email == null || email.isEmpty) {
      debugPrint(
        'UserExtensions: Using fallback email - user is null or has empty email',
      );
      return fallback;
    }
    return email;
  }

  /// Get display name with fallback behavior
  String getDisplayNameOrFallback(String fallback) {
    final displayName = safeDisplayName;
    if (displayName == null || displayName.isEmpty) {
      debugPrint(
        'UserExtensions: Using fallback display name - user is null or has empty display name',
      );
      return fallback;
    }
    return displayName;
  }

  /// Safely convert user to map, returns empty map if user is null
  Map<String, dynamic> safeToMap() {
    try {
      return this?.toMap() ?? <String, dynamic>{};
    } catch (e) {
      debugPrint('UserExtensions: Error converting user to map: $e');
      return <String, dynamic>{};
    }
  }

  /// Check if user has valid authentication data
  bool get hasValidAuthData {
    if (this == null) return false;
    final uid = safeUid;
    return uid != null && uid.isNotEmpty;
  }

  /// Log user state for debugging
  void logUserState(String context) {
    if (this == null) {
      debugPrint('UserExtensions [$context]: User is null');
    } else {
      debugPrint(
        'UserExtensions [$context]: User authenticated - UID: $safeUid, Email: $safeEmail',
      );
    }
  }
}

/// Extension methods for nullable string operations
extension SafeStringExtensions on String? {
  /// Returns the string or a default value if null or empty
  String orDefault(String defaultValue) {
    return (this?.isEmpty ?? true) ? defaultValue : this!;
  }

  /// Check if string is null or empty
  bool get isNullOrEmpty => this?.isEmpty ?? true;
}
