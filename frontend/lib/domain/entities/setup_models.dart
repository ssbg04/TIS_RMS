class AcademicYearModel {
  final int id;
  final String yearRange;
  final String status;

  AcademicYearModel({
    required this.id,
    required this.yearRange,
    required this.status,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) {
    return AcademicYearModel(
      id: (json['id'] as num).toInt(),
      yearRange: json['year_range'] as String,
      status: json['status'] as String,
    );
  }
}

class SectionModel {
  final int id;
  final String name;
  final int gradeLevel;
  final int? academicYearId;
  final String? academicYearRange;

  SectionModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    this.academicYearId,
    this.academicYearRange,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      gradeLevel: (json['grade_level'] as num).toInt(),
      academicYearId: json['academic_year_id'] != null ? (json['academic_year_id'] as num).toInt() : null,
      academicYearRange: json['academic_year_range'] as String?,
    );
  }
}

class GradeLevelModel {
  final int id;
  final int level;
  final String name;

  GradeLevelModel({
    required this.id,
    required this.level,
    required this.name,
  });

  factory GradeLevelModel.fromJson(Map<String, dynamic> json) {
    return GradeLevelModel(
      id: (json['id'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}
