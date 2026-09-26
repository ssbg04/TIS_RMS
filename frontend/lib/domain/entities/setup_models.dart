class AcademicYearModel {
  final int id;
  final String yearRange;
  final String status;
  final String? startDate;
  final String? endDate;

  AcademicYearModel({
    required this.id,
    required this.yearRange,
    required this.status,
    this.startDate,
    this.endDate,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) {
    return AcademicYearModel(
      id: (json['id'] as num).toInt(),
      yearRange: json['year_range'] as String,
      status: json['status'] as String,
      startDate: json['start_date'] as String? ?? json['startDate'] as String?,
      endDate: json['end_date'] as String? ?? json['endDate'] as String?,
    );
  }
}

class SectionModel {
  final int id;
  final String name;
  final int gradeLevel;
  final int? academicYearId;
  final String? academicYearRange;
  final int? teacherId;
  final String? teacherFirstName;
  final String? teacherLastName;

  String? get teacherFullName {
    if (teacherLastName != null && teacherFirstName != null) {
      return '$teacherLastName, $teacherFirstName';
    }
    return teacherFirstName ?? teacherLastName;
  }

  SectionModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    this.academicYearId,
    this.academicYearRange,
    this.teacherId,
    this.teacherFirstName,
    this.teacherLastName,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      gradeLevel: (json['grade_level'] as num).toInt(),
      academicYearId: json['academic_year_id'] != null
          ? (json['academic_year_id'] as num).toInt()
          : null,
      academicYearRange: json['academic_year_range'] as String?,
      teacherId: json['teacher_id'] != null
          ? (json['teacher_id'] as num).toInt()
          : null,
      teacherFirstName: json['teacher_first_name'] as String?,
      teacherLastName: json['teacher_last_name'] as String?,
    );
  }
}

class GradeLevelModel {
  final int id;
  final int level;
  final String name;

  GradeLevelModel({required this.id, required this.level, required this.name});

  factory GradeLevelModel.fromJson(Map<String, dynamic> json) {
    return GradeLevelModel(
      id: (json['id'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}
