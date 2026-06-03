class OcrResultModel {
  final String lrn;
  final String firstName;
  final String lastName;
  final String middleName;
  final String extension; // Added Ext
  final String? dob;      // Nullable for SF9
  final String sex;
  final String gradeLevel;
  final String section;
  final String schoolYear;
  final String trackStrand;
  final String rawText;

  OcrResultModel({
    required this.lrn,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.extension,
    this.dob,
    required this.sex,
    required this.gradeLevel,
    required this.section,
    required this.schoolYear,
    required this.trackStrand,
    required this.rawText,
  });

  factory OcrResultModel.fromJson(Map<String, dynamic> json) {
    final extracted = json['extracted'] as Map<String, dynamic>? ?? {};
    
    return OcrResultModel(
      lrn: extracted['lrn']?.toString() ?? '',
      firstName: extracted['firstName']?.toString() ?? '',
      lastName: extracted['lastName']?.toString() ?? '',
      middleName: extracted['middleName']?.toString() ?? '',
      extension: extracted['extension']?.toString() ?? '', // Parse Ext
      dob: extracted['dob']?.toString(), // Parse nullable DOB
      sex: extracted['sex']?.toString() ?? '',
      gradeLevel: extracted['gradeLevel']?.toString() ?? '',
      section: extracted['section']?.toString() ?? '',
      schoolYear: extracted['schoolYear']?.toString() ?? '',
      trackStrand: extracted['trackStrand']?.toString() ?? '',
      rawText: json['rawText']?.toString() ?? '',
    );
  }
}