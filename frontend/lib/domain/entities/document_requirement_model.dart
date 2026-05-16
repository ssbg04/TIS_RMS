class DocumentRequirementModel {
  final int id;
  final String name;
  final String? description;
  final String category; // 'JHS', 'SHS'
  final bool isMandatory;
  final bool isEnabled;
  final DateTime? dueDate;
  final String acceptedFileTypes;
  final String schoolLevels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DocumentRequirementModel({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.isMandatory,
    this.isEnabled = true,
    this.dueDate,
    this.acceptedFileTypes = 'pdf,jpg,jpeg,png',
    this.schoolLevels = 'JHS,SHS',
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentRequirementModel.fromJson(Map<String, dynamic> json) {
    return DocumentRequirementModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      isMandatory: json['is_mandatory'] == 1 || json['is_mandatory'] == true,
      isEnabled: json['is_enabled'] == 1 || json['is_enabled'] == true,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      acceptedFileTypes: json['accepted_file_types'] ?? 'pdf,jpg,jpeg,png',
      schoolLevels: json['school_levels'] ?? 'JHS,SHS',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'isMandatory': isMandatory,
      'isEnabled': isEnabled,
      'dueDate': dueDate?.toIso8601String(),
      'acceptedFileTypes': acceptedFileTypes,
      'schoolLevels': schoolLevels,
    };
  }

  DocumentRequirementModel copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    bool? isMandatory,
    bool? isEnabled,
    DateTime? dueDate,
    String? acceptedFileTypes,
    String? schoolLevels,
  }) {
    return DocumentRequirementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      isMandatory: isMandatory ?? this.isMandatory,
      isEnabled: isEnabled ?? this.isEnabled,
      dueDate: dueDate ?? this.dueDate,
      acceptedFileTypes: acceptedFileTypes ?? this.acceptedFileTypes,
      schoolLevels: schoolLevels ?? this.schoolLevels,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
