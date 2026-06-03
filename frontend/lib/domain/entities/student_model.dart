class StudentModel {
  final int id;
  final String lrn;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? extension;
  final String sex;
  final DateTime birthDate;
  final String status; // 'Enrolled', 'Graduated', 'Transferred', 'Dropped'
  final int missingDocumentsCount;
  final int totalDocumentsCount;
  final List<String> missingDocuments;
  final int? latestGradeLevel;
  final String? latestSection;
  final List<EnrollmentModel>? enrollments;

  StudentModel({
    required this.id,
    required this.lrn,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.extension,
    required this.sex,
    required this.birthDate,
    this.status = 'Enrolled',
    this.missingDocumentsCount = 0,
    this.totalDocumentsCount = 0,
    this.missingDocuments = const [],
    this.latestGradeLevel,
    this.latestSection,
    this.enrollments,
  });

  /// Display name: "De La Cruz, Juan Jr. M."
  String get fullName {
    final ext = extension != null && extension!.isNotEmpty ? ' ${extension!}' : '';
    final mi  = middleName != null && middleName!.isNotEmpty ? ' ${middleName![0]}.' : '';
    return '$lastName, $firstName$ext$mi'.trim();
  }

  /// e.g. "Grade 10 – Sec A"
  String get gradeSection {
    if (latestGradeLevel == null) return '—';
    final section = latestSection?.isNotEmpty == true ? ' — ${latestSection!}' : '';
    return 'Grade $latestGradeLevel$section';
  }

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id:                   json['id']     as int,
      lrn:                  json['lrn']    as String,
      firstName:            json['first_name']  as String,
      middleName:           json['middle_name'] as String?,
      lastName:             json['last_name']   as String,
      extension:            json['extension']   as String?,
      sex:                  json['sex']         as String,
      birthDate:            DateTime.parse(json['birth_date'] as String),
      status:               json['status']      as String? ?? 'Enrolled',
      missingDocumentsCount: (json['missingDocumentsCount'] as num?)?.toInt() ?? 0,
      totalDocumentsCount: (json['totalDocumentsCount'] as num?)?.toInt() ?? 0,
      missingDocuments:    (json['missingDocuments'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      latestGradeLevel:     (json['latest_grade_level'] as num?)?.toInt(),
      latestSection:        json['latest_section'] as String?,
      enrollments:          json['enrollments'] != null
          ? (json['enrollments'] as List)
              .map((e) => EnrollmentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':          id,
      'lrn':         lrn,
      'first_name':  firstName,
      'middle_name': middleName,
      'last_name':   lastName,
      'extension':   extension,
      'sex':         sex,
      'birth_date':  birthDate.toIso8601String().split('T').first,
      'status':      status,
    };
  }

  /// Used when submitting the create/update form
  Map<String, dynamic> toRequestBody() {
    return {
      'lrn':        lrn,
      'firstName':  firstName,
      'middleName': middleName,
      'lastName':   lastName,
      'extension':  extension,
      'sex':        sex,
      'birthDate':  birthDate.toIso8601String().split('T').first,
      'status':     status,
    };
  }

  StudentModel copyWith({
    int?    id,
    String? lrn,
    String? firstName,
    String? middleName,
    String? lastName,
    String? extension,
    String? sex,
    DateTime? birthDate,
    String? status,
    int?    missingDocumentsCount,
    int?    totalDocumentsCount,
    List<String>? missingDocuments,
    int?    latestGradeLevel,
    String? latestSection,
    List<EnrollmentModel>? enrollments,
  }) {
    return StudentModel(
      id:                   id                   ?? this.id,
      lrn:                  lrn                  ?? this.lrn,
      firstName:            firstName             ?? this.firstName,
      middleName:           middleName            ?? this.middleName,
      lastName:             lastName              ?? this.lastName,
      extension:            extension             ?? this.extension,
      sex:                  sex                  ?? this.sex,
      birthDate:            birthDate             ?? this.birthDate,
      status:               status               ?? this.status,
      missingDocumentsCount: missingDocumentsCount ?? this.missingDocumentsCount,
      totalDocumentsCount:  totalDocumentsCount ?? this.totalDocumentsCount,
      missingDocuments:     missingDocuments     ?? this.missingDocuments,
      latestGradeLevel:     latestGradeLevel      ?? this.latestGradeLevel,
      latestSection:        latestSection         ?? this.latestSection,
      enrollments:          enrollments           ?? this.enrollments,
    );
  }
}

class EnrollmentModel {
  final int id;
  final int studentId;
  final int academicYearId;
  final int sectionId;
  final int gradeLevel;
  final String? trackStrand;
  final String? yearRange;
  final String? sectionName;

  EnrollmentModel({
    required this.id,
    required this.studentId,
    required this.academicYearId,
    required this.sectionId,
    required this.gradeLevel,
    this.trackStrand,
    this.yearRange,
    this.sectionName,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      academicYearId: json['academic_year_id'] as int,
      sectionId: json['section_id'] as int,
      gradeLevel: json['grade_level'] as int,
      trackStrand: json['track_strand'] as String?,
      yearRange: json['year_range'] as String?,
      sectionName: json['section_name'] as String?,
    );
  }
}
