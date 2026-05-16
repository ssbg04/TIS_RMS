class DashboardStats {
  final int totalStudents;
  final int printQueueCount;
  final int pendingVerifications;
  final int activeUsers;

  DashboardStats({
    required this.totalStudents,
    required this.printQueueCount,
    required this.pendingVerifications,
    required this.activeUsers,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalStudents: json['totalStudents'] ?? 0,
      printQueueCount: json['printQueueCount'] ?? 0,
      pendingVerifications: json['pendingVerifications'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
    );
  }
}

class PendingTask {
  final int id;
  final String fileName;
  final String createdAt;
  final String firstName;
  final String lastName;

  PendingTask({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.firstName,
    required this.lastName,
  });

  factory PendingTask.fromJson(Map<String, dynamic> json) {
    return PendingTask(
      id: json['id'] ?? 0,
      fileName: json['file_name'] ?? 'Unknown',
      createdAt: json['created_at'] ?? '',
      firstName: json['first_name'] ?? 'Unknown',
      lastName: json['last_name'] ?? '',
    );
  }
}
