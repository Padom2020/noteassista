import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'unified_user.dart';

/// Adapter that maps Supabase User to UnifiedUser interface
class SupabaseUserAdapter implements UnifiedUser {
  final User _supabaseUser;

  SupabaseUserAdapter(this._supabaseUser) {
    // Validate that the user object has required properties
    if (_supabaseUser.id.isEmpty) {
      debugPrint('SupabaseUserAdapter: Warning - User has empty ID');
    }
  }

  @override
  String get uid {
    try {
      final id = _supabaseUser.id;
      if (id.isEmpty) {
        debugPrint('SupabaseUserAdapter: Warning - User ID is empty');
      }
      return id;
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error accessing user ID: $e');
      return '';
    }
  }

  @override
  String? get email {
    try {
      return _supabaseUser.email;
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error accessing user email: $e');
      return null;
    }
  }

  @override
  String? get displayName {
    try {
      return _supabaseUser.userMetadata?['display_name'] as String?;
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error accessing user display name: $e');
      return null;
    }
  }

  @override
  bool get isAnonymous {
    try {
      return _supabaseUser.isAnonymous;
    } catch (e) {
      debugPrint(
        'SupabaseUserAdapter: Error accessing user anonymous status: $e',
      );
      return true; // Default to anonymous if we can't determine
    }
  }

  @override
  Map<String, dynamic> toMap() {
    try {
      return {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'isAnonymous': isAnonymous,
      };
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error converting to map: $e');
      return {
        'uid': '',
        'email': null,
        'displayName': null,
        'isAnonymous': true,
      };
    }
  }

  /// Get the underlying Supabase user object
  User get supabaseUser => _supabaseUser;

  /// Validate that the user adapter has valid data
  bool get isValid {
    try {
      return uid.isNotEmpty;
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error validating user: $e');
      return false;
    }
  }

  /// Get user metadata safely
  Map<String, dynamic>? get safeUserMetadata {
    try {
      return _supabaseUser.userMetadata;
    } catch (e) {
      debugPrint('SupabaseUserAdapter: Error accessing user metadata: $e');
      return null;
    }
  }
}
