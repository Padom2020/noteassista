import '../models/unified_user.dart';

class UserModel {
  final String uid;
  final String email;

  UserModel({required this.uid, required this.email});

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email};
  }

  factory UserModel.fromUnifiedUser(UnifiedUser user) {
    return UserModel(uid: user.uid, email: user.email ?? '');
  }

  // Deprecated: Use fromUnifiedUser instead
  @Deprecated('Use fromUnifiedUser instead')
  factory UserModel.fromFirebaseUser(dynamic user) {
    // This method is kept for backward compatibility
    // but should not be used with new code
    throw UnsupportedError(
      'fromFirebaseUser is deprecated. Use fromUnifiedUser instead.',
    );
  }
}
