class DocumentVersionModel {
  final int id;
  final int documentId;
  final int versionNumber;
  final String fileName;
  final String? filePath;
  final int? fileSize;
  final int? templateId;
  final int? templateVersionId;
  final int? uploadedBy;
  final String? uploadedByName;
  final String? notes;
  final DateTime? createdAt;

  // Joined optional fields
  final String? templateName;
  final int? templateVersionNumber;

  const DocumentVersionModel({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.fileName,
    this.filePath,
    this.fileSize,
    this.templateId,
    this.templateVersionId,
    this.uploadedBy,
    this.uploadedByName,
    this.notes,
    this.createdAt,
    this.templateName,
    this.templateVersionNumber,
  });

  factory DocumentVersionModel.fromJson(Map<String, dynamic> json) {
    return DocumentVersionModel(
      id: (json['id'] as num).toInt(),
      documentId: (json['document_id'] as num?)?.toInt() ?? 0,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      templateId: (json['template_id'] as num?)?.toInt(),
      templateVersionId: (json['template_version_id'] as num?)?.toInt(),
      uploadedBy: (json['uploaded_by'] as num?)?.toInt(),
      uploadedByName: json['uploaded_by_name'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      templateName: json['template_name'] as String?,
      templateVersionNumber: (json['template_version_number'] as num?)?.toInt(),
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

  String get ext => fileName.toLowerCase().split('.').last;
}
