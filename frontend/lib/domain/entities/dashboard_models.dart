// ══════════════════════════════════════════════════════════════════════════════
// Dashboard stats — new tile model
// ══════════════════════════════════════════════════════════════════════════════
class DashboardStats {
  final int totalStudents;
  final int activeUsers;
  final int completedDocuments;
  final int missingDocuments;
  final bool hasAssignedSections;

  DashboardStats({
    required this.totalStudents,
    required this.activeUsers,
    required this.completedDocuments,
    required this.missingDocuments,
    this.hasAssignedSections = true,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
      completedDocuments: (json['completedDocuments'] as num?)?.toInt() ?? 0,
      missingDocuments: (json['missingDocuments'] as num?)?.toInt() ?? 0,
      hasAssignedSections: json['hasAssignedSections'] as bool? ?? true,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Recent Activity — from activity_log table
// ══════════════════════════════════════════════════════════════════════════════
class RecentActivity {
  final int id;
  final String action; // CREATE, UPDATE, DELETE
  final String entityType; // document, student, user
  final int? entityId;
  final String description;
  final String createdAt;
  final String? username;
  final String? performedBy;

  const RecentActivity({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.description,
    required this.createdAt,
    this.username,
    this.performedBy,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? 'UPDATE',
      entityType: json['entity_type'] as String? ?? 'document',
      entityId: (json['entity_id'] as num?)?.toInt(),
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      username: json['username'] as String?,
      performedBy: json['performed_by'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pagination wrapper
// ══════════════════════════════════════════════════════════════════════════════
class PaginatedActivities {
  final List<RecentActivity> activities;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginatedActivities({
    required this.activities,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedActivities.fromJson(Map<String, dynamic> json) {
    final p = json['pagination'] as Map<String, dynamic>? ?? {};
    return PaginatedActivities(
      activities: (json['activities'] as List<dynamic>? ?? [])
          .map((e) => RecentActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (p['total'] as num?)?.toInt() ?? 0,
      page: (p['page'] as num?)?.toInt() ?? 1,
      limit: (p['limit'] as num?)?.toInt() ?? 10,
      totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// User History — from user_history table
// ══════════════════════════════════════════════════════════════════════════════
class UserHistoryEntry {
  final int id;
  final String action; // created, updated, deleted
  final String username;
  final String fullName;
  final String role;
  final String createdAt;
  final String? performedByUsername;
  final String? performedByName;

  const UserHistoryEntry({
    required this.id,
    required this.action,
    required this.username,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.performedByUsername,
    this.performedByName,
  });

  factory UserHistoryEntry.fromJson(Map<String, dynamic> json) {
    return UserHistoryEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      performedByUsername: json['performed_by_username'] as String?,
      performedByName: json['performed_by_name'] as String?,
    );
  }
}

class PaginatedUserHistory {
  final List<UserHistoryEntry> history;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginatedUserHistory({
    required this.history,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedUserHistory.fromJson(Map<String, dynamic> json) {
    final p = json['pagination'] as Map<String, dynamic>? ?? {};
    return PaginatedUserHistory(
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => UserHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (p['total'] as num?)?.toInt() ?? 0,
      page: (p['page'] as num?)?.toInt() ?? 1,
      limit: (p['limit'] as num?)?.toInt() ?? 20,
      totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dashboard KPI models — used by the chart section on the dashboard
// ══════════════════════════════════════════════════════════════════════════════

class DigitalizationCategory {
  final int total;
  final int digitized;
  const DigitalizationCategory({required this.total, required this.digitized});
  double get percent => total == 0 ? 0 : digitized / total;
  factory DigitalizationCategory.fromJson(Map<String, dynamic> j) =>
      DigitalizationCategory(
        total: (j['total'] as num?)?.toInt() ?? 0,
        digitized: (j['digitized'] as num?)?.toInt() ?? 0,
      );
}

class DigitalizationData {
  final DigitalizationCategory jhs;
  final DigitalizationCategory shs;
  final DigitalizationCategory overall;
  const DigitalizationData({required this.jhs, required this.shs, required this.overall});
  factory DigitalizationData.fromJson(Map<String, dynamic> j) =>
      DigitalizationData(
        jhs: DigitalizationCategory.fromJson(j['jhs'] as Map<String, dynamic>? ?? {}),
        shs: DigitalizationCategory.fromJson(j['shs'] as Map<String, dynamic>? ?? {}),
        overall: DigitalizationCategory.fromJson(j['overall'] as Map<String, dynamic>? ?? {}),
      );
}

class ActivityByDayEntry {
  final String day;
  final String action;
  final String entityType;
  final int count;
  const ActivityByDayEntry({
    required this.day,
    required this.action,
    required this.entityType,
    required this.count,
  });
  factory ActivityByDayEntry.fromJson(Map<String, dynamic> j) =>
      ActivityByDayEntry(
        day: j['day'] as String? ?? '',
        action: j['action'] as String? ?? '',
        entityType: j['entity_type'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class StatusDistributionEntry {
  final String status;
  final int count;
  const StatusDistributionEntry({required this.status, required this.count});
  factory StatusDistributionEntry.fromJson(Map<String, dynamic> j) =>
      StatusDistributionEntry(
        status: j['status'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class StudentDocCount {
  final int id;
  final String name;
  final int docCount;
  final int uploadedCount;
  final int totalRequired;
  final int missingCount;
  final List<String> missingRequirements;
  final double percent;
  final int? gradeLevel;
  final String category;

  const StudentDocCount({
    required this.id,
    required this.name,
    required this.docCount,
    this.uploadedCount = 0,
    this.totalRequired = 0,
    this.missingCount = 0,
    this.missingRequirements = const [],
    this.percent = 0.0,
    this.gradeLevel,
    this.category = 'JHS',
  });

  factory StudentDocCount.fromJson(Map<String, dynamic> j) {
    final uploaded = (j['uploadedCount'] as num?)?.toInt() ??
        (j['doc_count'] as num?)?.toInt() ??
        0;
    final total = (j['totalRequired'] as num?)?.toInt() ?? 0;
    final missing = (j['missingCount'] as num?)?.toInt() ?? 0;
    final pct = (j['percent'] as num?)?.toDouble() ??
        (total == 0 ? (uploaded > 0 ? 1.0 : 0.0) : uploaded / total);

    final missingReqs = (j['missingRequirements'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return StudentDocCount(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      docCount: uploaded,
      uploadedCount: uploaded,
      totalRequired: total,
      missingCount: missing,
      missingRequirements: missingReqs,
      percent: pct,
      gradeLevel: (j['gradeLevel'] as num?)?.toInt(),
      category: j['category'] as String? ?? 'JHS',
    );
  }
}

class DocTypeEntry {
  final String name;
  final int count;
  const DocTypeEntry({required this.name, required this.count});
  factory DocTypeEntry.fromJson(Map<String, dynamic> j) =>
      DocTypeEntry(
        name: j['name'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class DocTypeGradeEntry {
  final String gradeLevel;
  final int grade;
  final int count;
  final int totalStudents;
  final double percent;

  const DocTypeGradeEntry({
    required this.gradeLevel,
    required this.grade,
    required this.count,
    required this.totalStudents,
    required this.percent,
  });

  factory DocTypeGradeEntry.fromJson(Map<String, dynamic> j) =>
      DocTypeGradeEntry(
        gradeLevel: j['gradeLevel'] as String? ?? '',
        grade: (j['grade'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
        percent: (j['percent'] as num?)?.toDouble() ?? 0.0,
      );
}

class UploadTrendEntry {
  final String day;
  final int count;
  const UploadTrendEntry({required this.day, required this.count});
  factory UploadTrendEntry.fromJson(Map<String, dynamic> j) =>
      UploadTrendEntry(
        day: j['day'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class StorageTypeEntry {
  final String name;
  final int bytes;
  const StorageTypeEntry({required this.name, required this.bytes});
  factory StorageTypeEntry.fromJson(Map<String, dynamic> j) =>
      StorageTypeEntry(
        name: j['name'] as String? ?? '',
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      );
}

class StorageAnalytics {
  final int totalBytes;
  final int totalFiles;
  final int filesWithSize;
  final List<StorageTypeEntry> byType;
  final int growthRate;
  final int recentBytes;
  const StorageAnalytics({
    required this.totalBytes,
    required this.totalFiles,
    required this.filesWithSize,
    required this.byType,
    required this.growthRate,
    required this.recentBytes,
  });
  factory StorageAnalytics.fromJson(Map<String, dynamic> j) =>
      StorageAnalytics(
        totalBytes: (j['totalBytes'] as num?)?.toInt() ?? 0,
        totalFiles: (j['totalFiles'] as num?)?.toInt() ?? 0,
        filesWithSize: (j['filesWithSize'] as num?)?.toInt() ?? 0,
        byType: (j['byType'] as List<dynamic>? ?? [])
            .map((e) => StorageTypeEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        growthRate: (j['growthRate'] as num?)?.toInt() ?? 0,
        recentBytes: (j['recentBytes'] as num?)?.toInt() ?? 0,
      );
}

class DashboardKpis {
  final DigitalizationData digitalization;
  final List<ActivityByDayEntry> activityByDay;
  final List<StatusDistributionEntry> statusDistribution;
  final List<StudentDocCount> topStudents;
  final List<StudentDocCount> bottomStudents;
  final List<DocTypeEntry> docTypeBreakdown;
  final Map<String, List<DocTypeGradeEntry>> docTypeByGrade;
  final List<UploadTrendEntry> uploadTrend;
  final StorageAnalytics storageAnalytics;
  final String? activeAcademicYear;

  const DashboardKpis({
    required this.digitalization,
    required this.activityByDay,
    required this.statusDistribution,
    required this.topStudents,
    required this.bottomStudents,
    required this.docTypeBreakdown,
    this.docTypeByGrade = const {},
    required this.uploadTrend,
    required this.storageAnalytics,
    this.activeAcademicYear,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> j) {
    final gradeMap = <String, List<DocTypeGradeEntry>>{};
    if (j['docTypeByGrade'] is Map) {
      final rawMap = j['docTypeByGrade'] as Map<String, dynamic>;
      rawMap.forEach((key, val) {
        if (val is List) {
          gradeMap[key] = val
              .map((e) => DocTypeGradeEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return DashboardKpis(
      digitalization: DigitalizationData.fromJson(
          j['digitalization'] as Map<String, dynamic>? ?? {}),
      activityByDay: (j['activityByDay'] as List<dynamic>? ?? [])
          .map((e) => ActivityByDayEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusDistribution: (j['statusDistribution'] as List<dynamic>? ?? [])
          .map((e) => StatusDistributionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      topStudents: (j['topStudents'] as List<dynamic>? ?? [])
          .map((e) => StudentDocCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      bottomStudents: (j['bottomStudents'] as List<dynamic>? ?? [])
          .map((e) => StudentDocCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      docTypeBreakdown: (j['docTypeBreakdown'] as List<dynamic>? ?? [])
          .map((e) => DocTypeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      docTypeByGrade: gradeMap,
      uploadTrend: (j['uploadTrend'] as List<dynamic>? ?? [])
          .map((e) => UploadTrendEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      storageAnalytics: StorageAnalytics.fromJson(
          j['storageAnalytics'] as Map<String, dynamic>? ?? {}),
      activeAcademicYear: j['activeAcademicYear'] as String?,
    );
  }
}
