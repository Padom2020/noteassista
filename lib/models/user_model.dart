import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;

  UserModel({required this.uid, required this.email});

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email};
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(uid: user.uid, email: user.email ?? '');
  }
}
