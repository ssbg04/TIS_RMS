// ══════════════════════════════════════════════════════════════════════════════
// Dashboard stats — new tile model
// ══════════════════════════════════════════════════════════════════════════════
class DashboardStats {
  final int totalStudents;
  final int activeUsers;
  final int completedDocuments;
  final int missingDocuments;

  DashboardStats({
    required this.totalStudents,
    required this.activeUsers,
    required this.completedDocuments,
    required this.missingDocuments,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalStudents:      (json['totalStudents']      as num?)?.toInt() ?? 0,
      activeUsers:        (json['activeUsers']         as num?)?.toInt() ?? 0,
      completedDocuments: (json['completedDocuments']  as num?)?.toInt() ?? 0,
      missingDocuments:   (json['missingDocuments']    as num?)?.toInt() ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Recent Activity — from activity_log table
// ══════════════════════════════════════════════════════════════════════════════
class RecentActivity {
  final int    id;
  final String action;       // CREATE, UPDATE, DELETE
  final String entityType;   // document, student, user
  final int?   entityId;
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
      id:          (json['id']          as num?)?.toInt() ?? 0,
      action:       json['action']       as String? ?? 'UPDATE',
      entityType:   json['entity_type']  as String? ?? 'document',
      entityId:    (json['entity_id']   as num?)?.toInt(),
      description:  json['description']  as String? ?? '',
      createdAt:    json['created_at']   as String? ?? '',
      username:     json['username']     as String?,
      performedBy:  json['performed_by'] as String?,
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
      total:      (p['total']      as num?)?.toInt() ?? 0,
      page:       (p['page']       as num?)?.toInt() ?? 1,
      limit:      (p['limit']      as num?)?.toInt() ?? 10,
      totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// User History — from user_history table
// ══════════════════════════════════════════════════════════════════════════════
class UserHistoryEntry {
  final int    id;
  final String action;          // created, updated, deleted
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
      id:                   (json['id'] as num?)?.toInt() ?? 0,
      action:               json['action']    as String? ?? '',
      username:             json['username']  as String? ?? '',
      fullName:             json['full_name'] as String? ?? '',
      role:                 json['role']      as String? ?? '',
      createdAt:            json['created_at'] as String? ?? '',
      performedByUsername:  json['performed_by_username'] as String?,
      performedByName:      json['performed_by_name'] as String?,
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
      total:      (p['total']      as num?)?.toInt() ?? 0,
      page:       (p['page']       as num?)?.toInt() ?? 1,
      limit:      (p['limit']      as num?)?.toInt() ?? 20,
      totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
