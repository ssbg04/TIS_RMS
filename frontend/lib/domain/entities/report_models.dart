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
class StudentCounts {
  final int active;
  final int dropped;
  final int transferee;
  final int graduated;

  const StudentCounts({
    required this.active,
    required this.dropped,
    required this.transferee,
    required this.graduated,
  });

  factory StudentCounts.fromJson(Map<String, dynamic> j) => StudentCounts(
        active: (j['active'] as num?)?.toInt() ?? 0,
        dropped: (j['dropped'] as num?)?.toInt() ?? 0,
        transferee: (j['transferee'] as num?)?.toInt() ?? 0,
        graduated: (j['graduated'] as num?)?.toInt() ?? 0,
      );
}

/// One row in the missing documents breakdown chart.
class MissingDocBreakdown {
  final int requirementId;
  final String name;
  final int count;

  const MissingDocBreakdown({
    required this.requirementId,
    required this.name,
    required this.count,
  });

  factory MissingDocBreakdown.fromJson(Map<String, dynamic> j) => MissingDocBreakdown(
        requirementId: (j['requirementId'] as num).toInt(),
        name: j['name'] as String? ?? 'Unknown',
        count: (j['count'] as num).toInt(),
      );
}

/// One student row for compliance list, report previews and Excel export sheets.
class ReportStudent {
  final int id;
  final String lrn;
  final String firstName;
  final String lastName;
  final String sex;
  final String status;
  final int? gradeLevel;
  final String? sectionName;
  final int missingCount;
  final String? missingRequirements;

  const ReportStudent({
    required this.id,
    required this.lrn,
    required this.firstName,
    required this.lastName,
    required this.sex,
    required this.status,
    this.gradeLevel,
    this.sectionName,
    required this.missingCount,
    this.missingRequirements,
  });

  String get fullName => '$lastName, $firstName';

  factory ReportStudent.fromJson(Map<String, dynamic> j) => ReportStudent(
        id: (j['id'] as num).toInt(),
        lrn: j['lrn'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        sex: j['sex'] as String? ?? '',
        status: j['status'] as String? ?? 'Enrolled',
        gradeLevel: (j['grade_level'] as num?)?.toInt(),
        sectionName: j['section_name'] as String?,
        missingCount: (j['missing_count'] as num?)?.toInt() ?? 0,
        missingRequirements: j['missing_requirements'] as String?,
      );
}

/// Complete report payload containing counts, breakdown, and student compliance rows.
class ReportStats {
  final StudentCounts studentCounts;
  final List<MissingDocBreakdown> missingDocsBreakdown;
  final List<ReportStudent> students;

  const ReportStats({
    required this.studentCounts,
    required this.missingDocsBreakdown,
    required this.students,
  });

  factory ReportStats.fromJson(Map<String, dynamic> j) => ReportStats(
        studentCounts: StudentCounts.fromJson(j['studentCounts'] as Map<String, dynamic>),
        missingDocsBreakdown: (j['missingDocsBreakdown'] as List? ?? [])
            .map((e) => MissingDocBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        students: (j['students'] as List? ?? [])
            .map((e) => ReportStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Yearly comparison data for the bar chart.
class YearlyComparisonData {
  final String year;
  final int enrolled;
  final int dropped;
  final int graduated;
  final int transferred;

  const YearlyComparisonData({
    required this.year,
    required this.enrolled,
    required this.dropped,
    required this.graduated,
    required this.transferred,
  });

  factory YearlyComparisonData.fromJson(Map<String, dynamic> j) => YearlyComparisonData(
        year: j['year'] as String? ?? '',
        enrolled: (j['enrolled'] as num?)?.toInt() ?? 0,
        dropped: (j['dropped'] as num?)?.toInt() ?? 0,
        graduated: (j['graduated'] as num?)?.toInt() ?? 0,
        transferred: (j['transferred'] as num?)?.toInt() ?? 0,
      );
}
