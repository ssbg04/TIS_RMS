/// Represents one academic year record from the DB.
class AcademicYear {
  final int id;
  final String yearRange;
  final String status;

  const AcademicYear({
    required this.id,
    required this.yearRange,
    required this.status,
  });

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
    id: j['id'] as int,
    yearRange: j['year_range'] as String,
    status: j['status'] as String? ?? 'active',
  );
}

/// KPI summary numbers for the Reports screen.
class StudentCounts {
  final int active;
  final int inactive;
  final int dropped;
  final int transferee;
  final int graduated;
  final int fourPs;

  const StudentCounts({
    required this.active,
    this.inactive = 0,
    required this.dropped,
    required this.transferee,
    required this.graduated,
    this.fourPs = 0,
  });

  factory StudentCounts.fromJson(Map<String, dynamic> j) => StudentCounts(
    active: (j['active'] as num?)?.toInt() ?? 0,
    inactive: (j['inactive'] as num?)?.toInt() ?? 0,
    dropped: (j['dropped'] as num?)?.toInt() ?? 0,
    transferee: (j['transferee'] as num?)?.toInt() ?? 0,
    graduated: (j['graduated'] as num?)?.toInt() ?? 0,
    fourPs: (j['fourPs'] as num?)?.toInt() ?? 0,
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

  factory MissingDocBreakdown.fromJson(Map<String, dynamic> j) =>
      MissingDocBreakdown(
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
    studentCounts: StudentCounts.fromJson(
      j['studentCounts'] as Map<String, dynamic>,
    ),
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
  final int inactive;
  final int dropped;
  final int graduated;
  final int transferred;

  const YearlyComparisonData({
    required this.year,
    required this.enrolled,
    this.inactive = 0,
    required this.dropped,
    required this.graduated,
    required this.transferred,
  });

  factory YearlyComparisonData.fromJson(Map<String, dynamic> j) =>
      YearlyComparisonData(
        year: j['year'] as String? ?? '',
        enrolled: (j['enrolled'] as num?)?.toInt() ?? 0,
        inactive: (j['inactive'] as num?)?.toInt() ?? 0,
        dropped: (j['dropped'] as num?)?.toInt() ?? 0,
        graduated: (j['graduated'] as num?)?.toInt() ?? 0,
        transferred: (j['transferred'] as num?)?.toInt() ?? 0,
      );
}

/// Represents sex breakdown for a specific grade level or stage
class SexBreakdownCount {
  final int male;
  final int female;
  final int total;

  const SexBreakdownCount({
    required this.male,
    required this.female,
    required this.total,
  });

  factory SexBreakdownCount.fromJson(Map<String, dynamic> j) =>
      SexBreakdownCount(
        male: (j['male'] as num?)?.toInt() ?? 0,
        female: (j['female'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// Enrollment count for a specific grade level with sex breakdown
class GradeEnrollmentBreakdown {
  final int gradeLevel;
  final int male;
  final int female;
  final int total;

  const GradeEnrollmentBreakdown({
    required this.gradeLevel,
    required this.male,
    required this.female,
    required this.total,
  });

  factory GradeEnrollmentBreakdown.fromJson(Map<String, dynamic> j) =>
      GradeEnrollmentBreakdown(
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        male: (j['male'] as num?)?.toInt() ?? 0,
        female: (j['female'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// Enrollment data for one academic year
class YearlyEnrollmentSummary {
  final List<GradeEnrollmentBreakdown> grades;
  final SexBreakdownCount jhsTotal;
  final SexBreakdownCount shsTotal;
  final SexBreakdownCount overallTotal;

  const YearlyEnrollmentSummary({
    required this.grades,
    required this.jhsTotal,
    required this.shsTotal,
    required this.overallTotal,
  });

  factory YearlyEnrollmentSummary.fromJson(Map<String, dynamic> j) =>
      YearlyEnrollmentSummary(
        grades: (j['grades'] as List? ?? [])
            .map((e) => GradeEnrollmentBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        jhsTotal: SexBreakdownCount.fromJson(
            j['jhsTotal'] as Map<String, dynamic>? ?? {}),
        shsTotal: SexBreakdownCount.fromJson(
            j['shsTotal'] as Map<String, dynamic>? ?? {}),
        overallTotal: SexBreakdownCount.fromJson(
            j['overallTotal'] as Map<String, dynamic>? ?? {}),
      );
}

/// Dropout count for one grade level
class GradeDropoutCount {
  final int gradeLevel;
  final int droppedCount;

  const GradeDropoutCount({
    required this.gradeLevel,
    required this.droppedCount,
  });

  factory GradeDropoutCount.fromJson(Map<String, dynamic> j) =>
      GradeDropoutCount(
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        droppedCount: (j['droppedCount'] as num?)?.toInt() ?? 0,
      );
}

class YearlyDropoutSummary {
  final List<GradeDropoutCount> grades;
  final int totalDropped;

  const YearlyDropoutSummary({
    required this.grades,
    required this.totalDropped,
  });

  factory YearlyDropoutSummary.fromJson(Map<String, dynamic> j) =>
      YearlyDropoutSummary(
        grades: (j['grades'] as List? ?? [])
            .map((e) => GradeDropoutCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDropped: (j['totalDropped'] as num?)?.toInt() ?? 0,
      );
}

/// Transferee count for one grade level
class GradeTransfereeCount {
  final int gradeLevel;
  final int transferredCount;

  const GradeTransfereeCount({
    required this.gradeLevel,
    required this.transferredCount,
  });

  factory GradeTransfereeCount.fromJson(Map<String, dynamic> j) =>
      GradeTransfereeCount(
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        transferredCount: (j['transferredCount'] as num?)?.toInt() ?? 0,
      );
}

class YearlyTransfereeSummary {
  final List<GradeTransfereeCount> grades;
  final int totalTransferred;

  const YearlyTransfereeSummary({
    required this.grades,
    required this.totalTransferred,
  });

  factory YearlyTransfereeSummary.fromJson(Map<String, dynamic> j) =>
      YearlyTransfereeSummary(
        grades: (j['grades'] as List? ?? [])
            .map((e) => GradeTransfereeCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalTransferred: (j['totalTransferred'] as num?)?.toInt() ?? 0,
      );
}

class Stage4PsSummary {
  final int fourPsCount;
  final int totalStudents;
  final double percentage;

  const Stage4PsSummary({
    required this.fourPsCount,
    required this.totalStudents,
    required this.percentage,
  });

  factory Stage4PsSummary.fromJson(Map<String, dynamic> j) => Stage4PsSummary(
        fourPsCount: (j['fourPsCount'] as num?)?.toInt() ?? 0,
        totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class Yearly4PsSummary {
  final List<Grade4PsCount> grades;
  final Stage4PsSummary jhsTotal;
  final Stage4PsSummary shsTotal;
  final Stage4PsSummary overallTotal;

  const Yearly4PsSummary({
    required this.grades,
    required this.jhsTotal,
    required this.shsTotal,
    required this.overallTotal,
  });

  factory Yearly4PsSummary.fromJson(Map<String, dynamic> j) => Yearly4PsSummary(
        grades: (j['grades'] as List? ?? [])
            .map((e) => Grade4PsCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        jhsTotal: Stage4PsSummary.fromJson(
            j['jhsTotal'] as Map<String, dynamic>? ?? {}),
        shsTotal: Stage4PsSummary.fromJson(
            j['shsTotal'] as Map<String, dynamic>? ?? {}),
        overallTotal: Stage4PsSummary.fromJson(
            j['overallTotal'] as Map<String, dynamic>? ?? {}),
      );
}

/// Complete yearly Transparency Board item
class YearlyTransparencyItem {
  final String yearRange;
  final YearlyEnrollmentSummary enrollment;
  final YearlyDropoutSummary dropouts;
  final YearlyTransfereeSummary transferees;
  final Yearly4PsSummary fourPs;

  const YearlyTransparencyItem({
    required this.yearRange,
    required this.enrollment,
    required this.dropouts,
    required this.transferees,
    this.fourPs = const Yearly4PsSummary(
      grades: [],
      jhsTotal: Stage4PsSummary(fourPsCount: 0, totalStudents: 0, percentage: 0.0),
      shsTotal: Stage4PsSummary(fourPsCount: 0, totalStudents: 0, percentage: 0.0),
      overallTotal: Stage4PsSummary(fourPsCount: 0, totalStudents: 0, percentage: 0.0),
    ),
  });

  factory YearlyTransparencyItem.fromJson(Map<String, dynamic> j) =>
      YearlyTransparencyItem(
        yearRange: j['yearRange'] as String? ?? '',
        enrollment: YearlyEnrollmentSummary.fromJson(
            j['enrollment'] as Map<String, dynamic>? ?? {}),
        dropouts: YearlyDropoutSummary.fromJson(
            j['dropouts'] as Map<String, dynamic>? ?? {}),
        transferees: YearlyTransfereeSummary.fromJson(
            j['transferees'] as Map<String, dynamic>? ?? {}),
        fourPs: Yearly4PsSummary.fromJson(
            j['fourPs'] as Map<String, dynamic>? ?? {}),
      );
}

/// 4Ps equity item per grade
class Grade4PsCount {
  final int gradeLevel;
  final int fourPsCount;
  final int totalStudents;
  final double percentage;

  const Grade4PsCount({
    required this.gradeLevel,
    required this.fourPsCount,
    required this.totalStudents,
    required this.percentage,
  });

  factory Grade4PsCount.fromJson(Map<String, dynamic> j) => Grade4PsCount(
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        fourPsCount: (j['fourPsCount'] as num?)?.toInt() ?? 0,
        totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 4Ps overall equity summary
class Equity4PsSummary {
  final List<Grade4PsCount> grades;
  final int total4Ps;
  final int totalStudents;
  final double overallPercentage;

  const Equity4PsSummary({
    required this.grades,
    required this.total4Ps,
    required this.totalStudents,
    required this.overallPercentage,
  });

  factory Equity4PsSummary.fromJson(Map<String, dynamic> j) =>
      Equity4PsSummary(
        grades: (j['grades'] as List? ?? [])
            .map((e) => Grade4PsCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        total4Ps: (j['total4Ps'] as num?)?.toInt() ?? 0,
        totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
        overallPercentage:
            (j['overallPercentage'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Top level response for Transparency Board
class TransparencyBoardData {
  final List<YearlyTransparencyItem> years;
  final Equity4PsSummary equity4Ps;

  const TransparencyBoardData({
    required this.years,
    required this.equity4Ps,
  });

  factory TransparencyBoardData.fromJson(Map<String, dynamic> j) =>
      TransparencyBoardData(
        years: (j['years'] as List? ?? [])
            .map((e) =>
                YearlyTransparencyItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        equity4Ps: Equity4PsSummary.fromJson(
            j['equity4Ps'] as Map<String, dynamic>? ?? {}),
      );
}

