/// Represents one academic year record from the DB.
class AcademicYear {
  final int id;
  final String yearRange;
  final String status;

  const AcademicYear({required this.id, required this.yearRange, required this.status});

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
        id: j['id'] as int,
        yearRange: j['year_range'] as String,
        status: j['status'] as String? ?? 'active',
      );
}

/// KPI summary numbers for the Reports screen.
class ReportStats {
  final int totalStudents;
  final int pendingDocs;
  final int verifiedDocs;
  final int printQueueCount;
  final int verificationRate; // 0-100 %

  const ReportStats({
    required this.totalStudents,
    required this.pendingDocs,
    required this.verifiedDocs,
    required this.printQueueCount,
    required this.verificationRate,
  });

  factory ReportStats.fromJson(Map<String, dynamic> j) => ReportStats(
        totalStudents: (j['totalStudents'] as num).toInt(),
        pendingDocs: (j['pendingDocs'] as num).toInt(),
        verifiedDocs: (j['verifiedDocs'] as num).toInt(),
        printQueueCount: (j['printQueueCount'] as num).toInt(),
        verificationRate: (j['verificationRate'] as num).toInt(),
      );
}

/// One bar in the "Enrollment by Grade" chart.
class GradeEnrollment {
  final int gradeLevel;
  final int count;

  const GradeEnrollment({required this.gradeLevel, required this.count});

  factory GradeEnrollment.fromJson(Map<String, dynamic> j) => GradeEnrollment(
        gradeLevel: (j['grade_level'] as num).toInt(),
        count: (j['count'] as num).toInt(),
      );

  String get label => gradeLevel <= 10 ? 'G$gradeLevel' : 'G$gradeLevel';
  String get fullLabel => 'Grade $gradeLevel';
}

/// Document verification status breakdown.
class DocumentStatus {
  final int pending;
  final int verified;
  final int draft;
  final int archived;

  const DocumentStatus({
    required this.pending,
    required this.verified,
    required this.draft,
    required this.archived,
  });

  int get total => pending + verified + draft + archived;
  double get verificationRate => total > 0 ? verified / total : 0.0;
  double get pendingRate => total > 0 ? pending / total : 0.0;

  factory DocumentStatus.fromJson(Map<String, dynamic> j) => DocumentStatus(
        pending: (j['Pending'] as num?)?.toInt() ?? 0,
        verified: (j['Verified'] as num?)?.toInt() ?? 0,
        draft: (j['Draft'] as num?)?.toInt() ?? 0,
        archived: (j['Archived'] as num?)?.toInt() ?? 0,
      );
}

/// One student row for the Excel export detail sheet.
class ReportStudent {
  final String lrn;
  final String firstName;
  final String lastName;
  final String sex;
  final int? gradeLevel;
  final int verifiedDocs;
  final int pendingDocs;

  const ReportStudent({
    required this.lrn,
    required this.firstName,
    required this.lastName,
    required this.sex,
    this.gradeLevel,
    required this.verifiedDocs,
    required this.pendingDocs,
  });

  factory ReportStudent.fromJson(Map<String, dynamic> j) => ReportStudent(
        lrn: j['lrn'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        sex: j['sex'] as String? ?? '',
        gradeLevel: (j['grade_level'] as num?)?.toInt(),
        verifiedDocs: (j['verified_docs'] as num?)?.toInt() ?? 0,
        pendingDocs: (j['pending_docs'] as num?)?.toInt() ?? 0,
      );
}

/// Grade-level summary row for the Excel export.
class GradeExportRow {
  final int gradeLevel;
  final int totalStudents;
  final String yearRange;

  const GradeExportRow({
    required this.gradeLevel,
    required this.totalStudents,
    required this.yearRange,
  });

  factory GradeExportRow.fromJson(Map<String, dynamic> j) => GradeExportRow(
        gradeLevel: (j['grade_level'] as num).toInt(),
        totalStudents: (j['total_students'] as num).toInt(),
        yearRange: j['year_range'] as String? ?? 'All Years',
      );
}

/// Full export payload from /api/reports/export-data.
class ReportExportData {
  final List<GradeExportRow> enrollmentByGrade;
  final DocumentStatus documentStatus;
  final List<ReportStudent> students;

  const ReportExportData({
    required this.enrollmentByGrade,
    required this.documentStatus,
    required this.students,
  });

  factory ReportExportData.fromJson(Map<String, dynamic> j) => ReportExportData(
        enrollmentByGrade: (j['enrollmentByGrade'] as List)
            .map((e) => GradeExportRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        documentStatus: DocumentStatus.fromJson(j['documentStatus'] as Map<String, dynamic>),
        students: (j['students'] as List)
            .map((e) => ReportStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
