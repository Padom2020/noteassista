import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateVariable {
  final String name;
  final String placeholder;
  final bool required;

  TemplateVariable({
    required this.name,
    required this.placeholder,
    this.required = false,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'placeholder': placeholder, 'required': required};
  }

  factory TemplateVariable.fromMap(Map<String, dynamic> data) {
    return TemplateVariable(
      name: data['name'] ?? '',
      placeholder: data['placeholder'] ?? '',
      required: data['required'] ?? false,
    );
  }
}

class TemplateModel {
  final String id;
  final String name;
  final String description;
  final String content;
  final List<TemplateVariable> variables;
  final int usageCount;
  final DateTime createdAt;
  final bool isCustom;

  TemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
    this.variables = const [],
    this.usageCount = 0,
    DateTime? createdAt,
    this.isCustom = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'content': content,
      'variables': variables.map((v) => v.toMap()).toList(),
      'usageCount': usageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCustom': isCustom,
    };
  }

  factory TemplateModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TemplateModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      content: data['content'] ?? '',
      variables:
          (data['variables'] as List<dynamic>?)
              ?.map((v) => TemplateVariable.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      usageCount: data['usageCount'] ?? 0,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      isCustom: data['isCustom'] ?? false,
    );
  }

  TemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    String? content,
    List<TemplateVariable>? variables,
    int? usageCount,
    DateTime? createdAt,
    bool? isCustom,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      content: content ?? this.content,
      variables: variables ?? this.variables,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
