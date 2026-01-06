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
  final List<String> collaboratorIds; // Deprecated: use collaborators instead
  final List<Map<String, dynamic>> collaborators; // New: stores role info
  final String? sourceUrl;
  final ReminderModel? reminder;
  final int viewCount;
  final int wordCount;
  final String? ownerId; // Owner of the note
  final String? userId; // User ID of the note creator (for RLS policies)

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
    this.collaborators = const [],
    this.sourceUrl,
    this.reminder,
    this.viewCount = 0,
    this.wordCount = 0,
    this.ownerId,
    this.userId,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'outgoingLinks': outgoingLinks,
      'audioUrls': audioUrls,
      'imageUrls': imageUrls,
      'drawingUrls': drawingUrls,
      'folderId': folderId,
      'isShared': isShared,
      'collaboratorIds': collaboratorIds,
      'collaborators': collaborators,
      'sourceUrl': sourceUrl,
      'reminder': reminder?.toMap(),
      'viewCount': viewCount,
      'wordCount': wordCount,
      'ownerId': ownerId,
      'userId': userId,
    };
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? description,
    String? timestamp,
    int? categoryImageIndex,
    bool? isDone,
    String? customImageUrl,
    bool? isPinned,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? outgoingLinks,
    List<String>? audioUrls,
    List<String>? imageUrls,
    List<String>? drawingUrls,
    String? folderId,
    bool? isShared,
    List<String>? collaboratorIds,
    List<Map<String, dynamic>>? collaborators,
    String? sourceUrl,
    ReminderModel? reminder,
    int? viewCount,
    int? wordCount,
    String? ownerId,
    String? userId,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      categoryImageIndex: categoryImageIndex ?? this.categoryImageIndex,
      isDone: isDone ?? this.isDone,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      outgoingLinks: outgoingLinks ?? this.outgoingLinks,
      audioUrls: audioUrls ?? this.audioUrls,
      imageUrls: imageUrls ?? this.imageUrls,
      drawingUrls: drawingUrls ?? this.drawingUrls,
      folderId: folderId ?? this.folderId,
      isShared: isShared ?? this.isShared,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      collaborators: collaborators ?? this.collaborators,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      reminder: reminder ?? this.reminder,
      viewCount: viewCount ?? this.viewCount,
      wordCount: wordCount ?? this.wordCount,
      ownerId: ownerId ?? this.ownerId,
      userId: userId ?? this.userId,
    );
  }
}
