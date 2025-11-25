import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final ReminderType type;
  final DateTime? triggerTime;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final bool recurring;
  final RecurrencePattern? pattern;

  ReminderModel({
    required this.id,
    required this.type,
    this.triggerTime,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.recurring = false,
    this.pattern,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'triggerTime': triggerTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'recurring': recurring,
      'pattern': pattern?.toMap(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> data) {
    return ReminderModel(
      id: data['id'] ?? '',
      type: ReminderType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => ReminderType.time,
      ),
      triggerTime:
          data['triggerTime'] != null
              ? DateTime.parse(data['triggerTime'])
              : null,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      radiusMeters: data['radiusMeters']?.toDouble(),
      recurring: data['recurring'] ?? false,
      pattern:
          data['pattern'] != null
              ? RecurrencePattern.fromMap(data['pattern'])
              : null,
    );
  }
}

enum ReminderType { time, location }

class RecurrencePattern {
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? endDate;

  RecurrencePattern({
    required this.frequency,
    required this.interval,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.toString(),
      'interval': interval,
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory RecurrencePattern.fromMap(Map<String, dynamic> data) {
    return RecurrencePattern(
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.toString() == data['frequency'],
        orElse: () => RecurrenceFrequency.daily,
      ),
      interval: data['interval'] ?? 1,
      endDate: data['endDate'] != null ? DateTime.parse(data['endDate']) : null,
    );
  }
}

enum RecurrenceFrequency { daily, weekly, monthly }

class NoteModel {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final int categoryImageIndex;
  final bool isDone;
  final String? customImageUrl; // URL for user-uploaded image
  final bool isPinned;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields for advanced features
  final List<String> outgoingLinks;
  final List<String> audioUrls;
  final List<String> imageUrls;
  final List<String> drawingUrls;
  final String? folderId;
  final bool isShared;
  final List<String> collaboratorIds;
  final String? sourceUrl;
  final ReminderModel? reminder;
  final int viewCount;
  final int wordCount;

  NoteModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.categoryImageIndex,
    required this.isDone,
    this.customImageUrl,
    this.isPinned = false,
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.outgoingLinks = const [],
    this.audioUrls = const [],
    this.imageUrls = const [],
    this.drawingUrls = const [],
    this.folderId,
    this.isShared = false,
    this.collaboratorIds = const [],
    this.sourceUrl,
    this.reminder,
    this.viewCount = 0,
    this.wordCount = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'timestamp': timestamp,
      'categoryImageIndex': categoryImageIndex,
      'isDone': isDone,
      'customImageUrl': customImageUrl,
      'isPinned': isPinned,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'outgoingLinks': outgoingLinks,
      'audioUrls': audioUrls,
      'imageUrls': imageUrls,
      'drawingUrls': drawingUrls,
      'folderId': folderId,
      'isShared': isShared,
      'collaboratorIds': collaboratorIds,
      'sourceUrl': sourceUrl,
      'reminder': reminder?.toMap(),
      'viewCount': viewCount,
      'wordCount': wordCount,
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
      customImageUrl: data['customImageUrl'],
      isPinned: data['isPinned'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
      outgoingLinks: List<String>.from(data['outgoingLinks'] ?? []),
      audioUrls: List<String>.from(data['audioUrls'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      drawingUrls: List<String>.from(data['drawingUrls'] ?? []),
      folderId: data['folderId'],
      isShared: data['isShared'] ?? false,
      collaboratorIds: List<String>.from(data['collaboratorIds'] ?? []),
      sourceUrl: data['sourceUrl'],
      reminder:
          data['reminder'] != null
              ? ReminderModel.fromMap(data['reminder'])
              : null,
      viewCount: data['viewCount'] ?? 0,
      wordCount: data['wordCount'] ?? 0,
    );
  }
}
