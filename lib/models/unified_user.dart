/// Abstract interface for unified user representation across different auth providers
abstract class UnifiedUser {
  /// Unique identifier for the user
  String get uid;

  /// User's email address
  String? get email;

  /// User's display name
  String? get displayName;

  /// Whether the user is anonymous
  bool get isAnonymous;

  /// Convert user to map representation
  Map<String, dynamic> toMap();
}
