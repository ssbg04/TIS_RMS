class DocumentModel {
  final int id;
  final int? studentId;
  final int? requirementId;
  final String fileName;
  final String filePath;
  final String? documentType;
  final String status; // 'Completed', 'Archived'
  final DateTime createdAt;

  // Extra fields for UI display
  final String? studentLrn;
  final String? studentName;
  final int? uploadedBy;
  final String? uploadedByName;
  final int? fileSize;
  final String? size;

  DocumentModel({
    required this.id,
    this.studentId,
    this.requirementId,
    required this.fileName,
    required this.filePath,
    this.documentType,
    required this.status,
    required this.createdAt,
    this.studentLrn,
    this.studentName,
    this.uploadedBy,
    this.uploadedByName,
    this.fileSize,
    this.size,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as int,
      studentId: json['studentId'] ?? json['student_id'] as int?,
      requirementId: json['requirementId'] ?? json['requirement_id'] as int?,
      fileName: json['fileName'] ?? json['file_name'] ?? '',
      filePath: json['filePath'] ?? json['file_path'] ?? '',
      documentType: json['documentType'] ?? json['document_type'],
      status: json['status'] as String? ?? 'Completed',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now()),
      studentLrn: json['studentLrn'] ?? json['student_lrn'],
      studentName: json['studentName'] ?? json['student_name'],
      uploadedBy: json['uploadedBy'] ?? json['uploaded_by'] as int?,
      uploadedByName: json['uploadedByName'] ?? json['uploaded_by_name'] as String?,
      fileSize: json['fileSize'] ?? json['file_size'] as int?,
      size: json['size'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'requirement_id': requirementId,
      'file_name': fileName,
      'file_path': filePath,
      'document_type': documentType,
      'status': status,
      'uploaded_by': uploadedBy,
      'uploaded_by_name': uploadedByName,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
