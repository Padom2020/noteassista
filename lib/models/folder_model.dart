class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final String color;
  final int noteCount;
  final DateTime createdAt;
  final bool isFavorite;

  FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.color,
    this.noteCount = 0,
    DateTime? createdAt,
    this.isFavorite = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'parentId': parentId,
      'color': color,
      'noteCount': noteCount,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    String? color,
    int? noteCount,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      noteCount: noteCount ?? this.noteCount,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
