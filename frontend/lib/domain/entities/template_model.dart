class DocumentTemplateModel {
  final int id;
  final int? requirementId;
  final String name;
  final String? description;
  final bool isActive;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String? requirementName;
  final String? requirementCategory;
  final int versionCount;
  final int? currentVersionId;
  final int? currentVersionNumber;
  final String? currentFileName;
  final List<TemplateVersionModel> versions;

  const DocumentTemplateModel({
    required this.id,
    this.requirementId,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.requirementName,
    this.requirementCategory,
    this.versionCount = 0,
    this.currentVersionId,
    this.currentVersionNumber,
    this.currentFileName,
    this.versions = const [],
  });

  factory DocumentTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['versions'];
    final List<TemplateVersionModel> versions = rawVersions is List
        ? rawVersions
              .map((v) => TemplateVersionModel.fromJson(v as Map<String, dynamic>))
              .toList()
        : [];
    return DocumentTemplateModel(
      id: (json['id'] as num).toInt(),
      requirementId: (json['requirement_id'] as num?)?.toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdBy: (json['created_by'] as num?)?.toInt(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      requirementName: json['requirement_name'] as String?,
      requirementCategory: json['requirement_category'] as String?,
      versionCount: (json['version_count'] as num?)?.toInt() ?? 0,
      currentVersionId: (json['current_version_id'] as num?)?.toInt(),
      currentVersionNumber: (json['current_version_number'] as num?)?.toInt(),
      currentFileName: json['current_file_name'] as String?,
      versions: versions,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    return DateTime.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requirement_id': requirementId,
        'name': name,
        'description': description,
        'is_active': isActive ? 1 : 0,
        'created_by': createdBy,
        'requirement_name': requirementName,
        'requirement_category': requirementCategory,
        'current_version_id': currentVersionId,
        'current_version_number': currentVersionNumber,
        'current_file_name': currentFileName,
      };

  DocumentTemplateModel copyWith({
    String? name,
    String? description,
    int? requirementId,
    bool? isActive,
  }) =>
      DocumentTemplateModel(
        id: id,
        requirementId: requirementId ?? this.requirementId,
        name: name ?? this.name,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        requirementName: requirementName,
        requirementCategory: requirementCategory,
        versionCount: versionCount,
        currentVersionId: currentVersionId,
        currentVersionNumber: currentVersionNumber,
        currentFileName: currentFileName,
        versions: versions,
      );
}

class TemplateVersionModel {
  final int id;
  final int templateId;
  final int versionNumber;
  final String fileName;
  final String? filePath;
  final int? fileSize;
  final bool isCurrent;
  final int? uploadedBy;
  final String? uploadedByName;
  final DateTime? createdAt;

  const TemplateVersionModel({
    required this.id,
    required this.templateId,
    required this.versionNumber,
    required this.fileName,
    this.filePath,
    this.fileSize,
    this.isCurrent = false,
    this.uploadedBy,
    this.uploadedByName,
    this.createdAt,
  });

  factory TemplateVersionModel.fromJson(Map<String, dynamic> json) {
    return TemplateVersionModel(
      id: (json['id'] as num).toInt(),
      templateId: (json['template_id'] as num?)?.toInt() ?? 0,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      isCurrent: json['is_current'] == 1 || json['is_current'] == true,
      uploadedBy: (json['uploaded_by'] as num?)?.toInt(),
      uploadedByName: json['uploaded_by_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String get formattedSize {
    if (fileSize == null || fileSize! <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize!.toDouble();
    int i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${units[i]}';
  }
}
