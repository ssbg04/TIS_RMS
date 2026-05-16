class FolderModel {
  final int id;
  final String name;
  final int? parentId;
  final int? studentId;
  final String? category;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Extra fields for display
  final String? studentLrn;
  final String? studentFirstName;
  final String? studentLastName;
  final String? createdByUsername;
  final int? documentCount;

  // For student folder view
  final StudentInfo? student;
  final List<FolderModel>? subfolders;
  final List<PhysicalEntry>? physicalFolders;
  final List<PhysicalEntry>? physicalFiles;
  final String? folderPath;

  FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.studentId,
    this.category,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.studentLrn,
    this.studentFirstName,
    this.studentLastName,
    this.createdByUsername,
    this.documentCount,
    this.student,
    this.subfolders,
    this.physicalFolders,
    this.physicalFiles,
    this.folderPath,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: json['parent_id'] as int?,
      studentId: json['student_id'] as int?,
      category: json['category'] as String?,
      createdBy: json['created_by'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      studentLrn: json['lrn'] as String?,
      studentFirstName: json['first_name'] as String?,
      studentLastName: json['last_name'] as String?,
      createdByUsername: json['created_by_username'] as String?,
      documentCount: json['document_count'] as int?,
      student: json['student'] != null
          ? StudentInfo.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      subfolders: json['subfolders'] != null
          ? (json['subfolders'] as List)
              .map((f) => FolderModel.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
      physicalFolders: json['physicalFolders'] != null
          ? (json['physicalFolders'] as List)
              .map((e) => PhysicalEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      physicalFiles: json['physicalFiles'] != null
          ? (json['physicalFiles'] as List)
              .map((e) => PhysicalEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      folderPath: json['folderPath'] as String?,
    );
  }
}

class StudentInfo {
  final int id;
  final String lrn;
  final String firstName;
  final String lastName;

  StudentInfo({
    required this.id,
    required this.lrn,
    required this.firstName,
    required this.lastName,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      id: json['id'] as int,
      lrn: json['lrn'] as String,
      firstName: json['firstName'] as String? ?? json['first_name'] as String? ?? '',
      lastName: json['lastName'] as String? ?? json['last_name'] as String? ?? '',
    );
  }
}

class PhysicalEntry {
  final String name;
  final bool isDirectory;

  PhysicalEntry({
    required this.name,
    required this.isDirectory,
  });

  factory PhysicalEntry.fromJson(Map<String, dynamic> json) {
    return PhysicalEntry(
      name: json['name'] as String,
      isDirectory: json['isDirectory'] as bool? ?? false,
    );
  }
}