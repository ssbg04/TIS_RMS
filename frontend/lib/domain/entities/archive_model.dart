class ArchiveModel {
  final int id;
  final String lrn;
  final String name;
  final String status;
  final String archivedDate;
  final String expiryDate;
  final bool isExpired;

  ArchiveModel({
    required this.id,
    required this.lrn,
    required this.name,
    required this.status,
    required this.archivedDate,
    required this.expiryDate,
    required this.isExpired,
  });

  factory ArchiveModel.fromJson(Map<String, dynamic> json) {
    return ArchiveModel(
      id: (json['id'] as num).toInt(),
      lrn: json['lrn'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      archivedDate: json['archivedDate'] as String,
      expiryDate: json['expiryDate'] as String,
      isExpired: json['isExpired'] as bool,
    );
  }
}
