class ConnectedUserModel {
  final String username;
  final String role;
  final String platform;
  final String? ip;
  final String loginTime;
  final String lastSeen;

  ConnectedUserModel({
    required this.username,
    required this.role,
    required this.platform,
    this.ip,
    required this.loginTime,
    required this.lastSeen,
  });

  factory ConnectedUserModel.fromJson(Map<String, dynamic> json) {
    return ConnectedUserModel(
      username: json['username'] as String? ?? 'unknown',
      role: json['role'] as String? ?? 'unknown',
      platform: json['platform'] as String? ?? 'unknown',
      ip: json['ip'] as String?,
      loginTime: json['loginTime'] as String? ?? '',
      lastSeen: json['lastSeen'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'role': role,
      'platform': platform,
      'ip': ip,
      'loginTime': loginTime,
      'lastSeen': lastSeen,
    };
  }
}
