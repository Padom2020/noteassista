import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final int categoryImageIndex;
  final bool isDone;

  NoteModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.categoryImageIndex,
    required this.isDone,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'timestamp': timestamp,
      'categoryImageIndex': categoryImageIndex,
      'isDone': isDone,
    };
  }

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp: data['timestamp'] ?? '',
      categoryImageIndex: data['categoryImageIndex'] ?? 0,
      isDone: data['isDone'] ?? false,
    );
  }
}
