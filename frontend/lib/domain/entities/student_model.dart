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
  final bool is4ps; // 4Ps beneficiary
  final int missingDocumentsCount;
  final int totalDocumentsCount;
  final List<String> missingDocuments;
  final int? _latestGradeLevel;
  final String? _latestSection;
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
    this.is4ps = false,
    this.missingDocumentsCount = 0,
    this.totalDocumentsCount = 0,
    this.missingDocuments = const [],
    int? latestGradeLevel,
    String? latestSection,
    this.enrollments,
  }) : _latestGradeLevel = latestGradeLevel,
       _latestSection = latestSection;

  String _getValidExtension() {
    if (extension == null || extension!.trim().isEmpty) return '';
    // do not display the suffix with n/a regex
    final RegExp naRegex = RegExp(r'^n\/?a$', caseSensitive: false);
    if (naRegex.hasMatch(extension!.trim())) return '';
    return extension!.trim();
  }

  /// Format: [Lastname, Firstname, suffix, middle name]
  String get listDisplayName {
    final extStr = _getValidExtension();
    final ext = extStr.isNotEmpty ? ' $extStr' : '';
    final mName = middleName != null && middleName!.isNotEmpty
        ? ' $middleName'
        : '';
    return '$lastName, $firstName$ext$mName'.trim();
  }

  /// Format: [First Name, Middle name, last name, suffix]
  String get profileDisplayName {
    final extStr = _getValidExtension();
    final ext = extStr.isNotEmpty ? ' $extStr' : '';
    final mName = middleName != null && middleName!.isNotEmpty
        ? ' $middleName'
        : '';
    return '$firstName$mName $lastName$ext'.trim();
  }

  /// Legacy fullName alias (maps to listDisplayName to avoid breaking existing code where not updated yet)
  String get fullName => listDisplayName;

  /// Traverses the enrollments list and dynamically resolves parameters matching
  /// the highest value of academicYearId or the highest lexicographical string sequence in yearRange.
  EnrollmentModel? get latestEnrollment {
    if (enrollments == null || enrollments!.isEmpty) return null;
    EnrollmentModel best = enrollments!.first;
    for (int i = 1; i < enrollments!.length; i++) {
      final current = enrollments![i];

      // Compare yearRange lexicographically first
      final currentRange = current.yearRange ?? '';
      final bestRange = best.yearRange ?? '';
      final rangeCmp = currentRange.compareTo(bestRange);
      if (rangeCmp != 0) {
        if (rangeCmp > 0) {
          best = current;
        }
        continue;
      }

      // If yearRange is same, compare academicYearId
      if (current.academicYearId != best.academicYearId) {
        if (current.academicYearId > best.academicYearId) {
          best = current;
        }
        continue;
      }

      // If academicYearId is also same, compare gradeLevel
      if (current.gradeLevel != best.gradeLevel) {
        if (current.gradeLevel > best.gradeLevel) {
          best = current;
        }
        continue;
      }

      // Fallback: compare enrollment ID
      if (current.id > best.id) {
        best = current;
      }
    }
    return best;
  }

  int? get latestGradeLevel {
    if (enrollments != null && enrollments!.isNotEmpty) {
      return latestEnrollment?.gradeLevel;
    }
    return _latestGradeLevel;
  }

  String? get latestSection {
    if (enrollments != null && enrollments!.isNotEmpty) {
      return latestEnrollment?.sectionName;
    }
    return _latestSection;
  }

  /// e.g. "Grade 10 – Sec A"
  String get gradeSection {
    if (latestGradeLevel == null) return '—';
    final section = latestSection?.isNotEmpty == true
        ? ' — ${latestSection!}'
        : '';
    return 'Grade $latestGradeLevel$section';
  }

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as int,
      lrn: json['lrn'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      extension: json['extension'] as String?,
      sex: json['sex'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      status: json['status'] as String? ?? 'Enrolled',
      is4ps: (json['is_4ps'] as num?)?.toInt() == 1,
      missingDocumentsCount:
          (json['missingDocumentsCount'] as num?)?.toInt() ?? 0,
      totalDocumentsCount: (json['totalDocumentsCount'] as num?)?.toInt() ?? 0,
      missingDocuments:
          (json['missingDocuments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      latestGradeLevel: (json['latest_grade_level'] as num?)?.toInt(),
      latestSection: json['latest_section'] as String?,
      enrollments: json['enrollments'] != null
          ? (json['enrollments'] as List)
                .map((e) => EnrollmentModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lrn': lrn,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'extension': extension,
      'sex': sex,
      'birth_date': birthDate.toIso8601String().split('T').first,
      'status': status,
      'is_4ps': is4ps ? 1 : 0,
    };
  }

  /// Used when submitting the create/update form
  Map<String, dynamic> toRequestBody() {
    return {
      'lrn': lrn,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'extension': extension,
      'sex': sex,
      'birthDate': birthDate.toIso8601String().split('T').first,
      'status': status,
      'is4ps': is4ps,
    };
  }

  StudentModel copyWith({
    int? id,
    String? lrn,
    String? firstName,
    String? middleName,
    String? lastName,
    String? extension,
    String? sex,
    DateTime? birthDate,
    String? status,
    bool? is4ps,
    int? missingDocumentsCount,
    int? totalDocumentsCount,
    List<String>? missingDocuments,
    int? latestGradeLevel,
    String? latestSection,
    List<EnrollmentModel>? enrollments,
  }) {
    return StudentModel(
      id: id ?? this.id,
      lrn: lrn ?? this.lrn,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      extension: extension ?? this.extension,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      status: status ?? this.status,
      is4ps: is4ps ?? this.is4ps,
      missingDocumentsCount:
          missingDocumentsCount ?? this.missingDocumentsCount,
      totalDocumentsCount: totalDocumentsCount ?? this.totalDocumentsCount,
      missingDocuments: missingDocuments ?? this.missingDocuments,
      latestGradeLevel: latestGradeLevel ?? this.latestGradeLevel,
      latestSection: latestSection ?? this.latestSection,
      enrollments: enrollments ?? this.enrollments,
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
