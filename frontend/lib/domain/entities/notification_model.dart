class NotificationModel {
  final int id;
  final int? userId;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: (json['is_read'] as int? ?? 0) == 1,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
