class UserModel {
  final int id;
  final String username;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? extension;
  final String role; // 'admin', 'teacher'
  final String? email;
  final String? phone;
  final String? addedBy; // "System" or the username of creator

  UserModel({
    required this.id,
    required this.username,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.extension,
    required this.role,
    this.email,
    this.phone,
    this.addedBy,
  });

  // Helper to get full formatted name
  String get fullName => '$firstName ${middleName != null && middleName!.isNotEmpty ? '${middleName![0]}. ' : ''}$lastName ${extension ?? ''}'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      extension: json['extension'] as String?,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      addedBy: json['added_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'extension': extension,
      'role': role,
      'email': email,
      'phone': phone,
      'added_by': addedBy,
    };
  }
}