enum CollaboratorRole { viewer, editor, owner }

class CollaboratorModel {
  final String userId;
  final String email;
  final String displayName;
  final CollaboratorRole role;
  final DateTime addedAt;

  CollaboratorModel({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'role': role.toString(),
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CollaboratorModel.fromMap(Map<String, dynamic> data) {
    return CollaboratorModel(
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: CollaboratorRole.values.firstWhere(
        (e) => e.toString() == data['role'],
        orElse: () => CollaboratorRole.viewer,
      ),
      addedAt:
          data['addedAt'] != null
              ? DateTime.parse(data['addedAt'] as String)
              : DateTime.now(),
    );
  }

  CollaboratorModel copyWith({
    String? userId,
    String? email,
    String? displayName,
    CollaboratorRole? role,
    DateTime? addedAt,
  }) {
    return CollaboratorModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
