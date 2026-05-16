class SystemUser {
  final int id;
  final String username;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? extension;
  final String role;
  final String? email;
  final String? phone;
  final String? createdAt;

  SystemUser({
    required this.id,
    required this.username,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.extension,
    required this.role,
    this.email,
    this.phone,
    this.createdAt,
  });

  String get fullName {
    final mid = middleName != null && middleName!.isNotEmpty ? '${middleName![0]}. ' : '';
    final ext = extension != null && extension!.isNotEmpty ? ' $extension' : '';
    return '$firstName $mid$lastName$ext'.trim();
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  factory SystemUser.fromJson(Map<String, dynamic> json) {
    return SystemUser(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      extension: json['extension'] as String?,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
