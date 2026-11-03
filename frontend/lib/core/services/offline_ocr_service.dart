import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/ocr_result_model.dart';

/// On-device, offline OCR parser using Google ML Kit Text Recognition (unbundled mode).
/// Automatically extracts DepEd document fields (LRN, names, birthdate, sex, grade,
/// section, school year) completely offline on Android without contacting the backend.
class OfflineOcrService {
  /// Processes an image file locally on Android and returns an [OcrResultModel].
  /// Returns null or throws on unsupported platforms or processing errors.
  static Future<OcrResultModel?> processDocument({
    required File file,
    required String docType,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognized = await textRecognizer.processImage(inputImage);
      final rawText = recognized.text;

      if (rawText.trim().isEmpty) {
        return null;
      }

      return parse(rawText, docType);
    } finally {
      await textRecognizer.close();
    }
  }

  /// Parses raw recognized OCR text into an [OcrResultModel] matching DepEd standards.
  static OcrResultModel parse(String text, String docType) {
    if (docType.toUpperCase() == 'SF9') {
      return _parseSF9(text);
    } else {
      // Default to SF10 / General Student Records
      return _parseSF10(text);
    }
  }

  // ─── SF9 Parser ────────────────────────────────────────────────────────────

  static OcrResultModel _parseSF9(String text) {
    final processedText = _normalizeOcrLrnMisreads(text);
    final normalizedSingleLine = processedText
        .replaceAll('\r', '')
        .replaceAll('|', 'I')
        .replaceAll(RegExp(r'\s+'), ' ');

    final lrn = _extractLrn(processedText, normalizedSingleLine);
    final name = _extractStudentName(text);
    final dob = _extractDob(text);
    final sex = _extractSex(text);

    String gradeLevel = '';
    final gradeMatch = RegExp(r'(?:Grade|Grade\s*Level)[:\s,]*(\d+)', caseSensitive: false)
        .firstMatch(text);
    if (gradeMatch != null) {
      gradeLevel = gradeMatch.group(1) ?? '';
    }

    String section = '';
    final sectionMatch = RegExp(r'Section[:\s,]*([^\r\n,]+)', caseSensitive: false)
        .firstMatch(text);
    if (sectionMatch != null) {
      String sec = sectionMatch.group(1)?.trim() ?? '';
      sec = sec.replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '').trim();
      section = sec;
    }

    String schoolYear = '';
    final syMatch = RegExp(r'(?:School\s*Year|S\.?Y\.?)[:\s,]*(\d{4}\s*-\s*\d{4})', caseSensitive: false)
        .firstMatch(text);
    if (syMatch != null) {
      schoolYear = (syMatch.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');
    }

    String trackStrand = '';
    final trackMatch = RegExp(
      r'(?:TRACK\s*/?\s*STRAND|TRACK|STRAND)[:\s,]*([A-Za-z0-9/\-\s]+?)(?=\s*(?:Admitted|Grade|Section|School\s*Year|S\.?Y\.?|LRN|SEX|DOB|DATE|\r|\n|$))',
      caseSensitive: false,
    ).firstMatch(text);
    if (trackMatch != null) {
      trackStrand = trackMatch.group(1)?.trim() ?? '';
    }

    final scholastic = _extractAllScholasticRecords(text);
    if (scholastic.isNotEmpty) {
      final latest = scholastic.last;
      if (gradeLevel.isEmpty) gradeLevel = latest['gradeLevel'] ?? '';
      if (section.isEmpty) section = latest['section'] ?? '';
      if (schoolYear.isEmpty) schoolYear = latest['schoolYear'] ?? '';
    }

    return OcrResultModel(
      lrn: lrn,
      firstName: name.firstName,
      lastName: name.lastName,
      middleName: name.middleName,
      extension: name.extension,
      dob: dob,
      sex: sex,
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
      trackStrand: trackStrand,
      rawText: text,
    );
  }

  // ─── SF10 Parser ───────────────────────────────────────────────────────────

  static OcrResultModel _parseSF10(String text) {
    final processedText = _normalizeOcrLrnMisreads(text);
    final normalizedSingleLine = processedText
        .replaceAll('\r', '')
        .replaceAll('|', 'I')
        .replaceAll(RegExp(r'\s+'), ' ');

    final lrn = _extractLrn(processedText, normalizedSingleLine);
    final name = _extractStudentName(text);
    final dob = _extractDob(text);
    final sex = _extractSex(text);

    String gradeLevel = '';
    String section = '';
    String schoolYear = '';
    String trackStrand = '';

    final trackMatch = RegExp(
      r'(?:TRACK\s*/?\s*STRAND|TRACK|STRAND)[:\s,]*([A-Za-z0-9/\-\s]+?)(?=\s*(?:Admitted|Grade|Section|School\s*Year|S\.?Y\.?|LRN|SEX|DOB|DATE|\r|\n|$))',
      caseSensitive: false,
    ).firstMatch(text);
    if (trackMatch != null) {
      trackStrand = trackMatch.group(1)?.trim() ?? '';
    }

    final scholastic = _extractAllScholasticRecords(text);
    if (scholastic.isNotEmpty) {
      final latest = scholastic.last;
      gradeLevel = latest['gradeLevel'] ?? '';
      section = latest['section'] ?? '';
      schoolYear = latest['schoolYear'] ?? '';
    }

    return OcrResultModel(
      lrn: lrn,
      firstName: name.firstName,
      lastName: name.lastName,
      middleName: name.middleName,
      extension: name.extension,
      dob: dob,
      sex: sex,
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
      trackStrand: trackStrand,
      rawText: text,
    );
  }

  // ─── Helpers: LRN, Name, DOB, Sex, Records ─────────────────────────────────

  static String _normalizeOcrLrnMisreads(String text) {
    return text.replaceAllMapped(
      RegExp(r'(L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)([0-9OoIl|][\s\-\.]*(?:[0-9OoIl|][\s\-\.]*){11})',
          caseSensitive: false),
      (match) {
        final prefix = match.group(1) ?? '';
        final lrnStr = match.group(2) ?? '';
        final cleaned = lrnStr.replaceAll(RegExp(r'[Oo]'), '0').replaceAll(RegExp(r'[Il|]'), '1');
        return '$prefix$cleaned';
      },
    );
  }

  static String _extractLrn(String processedText, String normalizedText) {
    final lrnMatch = RegExp(
      r'(?:L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)?(\d[\s\-\.]*(?:\d[\s\-\.]*){11})',
      caseSensitive: false,
    ).firstMatch(normalizedText);

    if (lrnMatch != null) {
      final cand = (lrnMatch.group(1) ?? '').replaceAll(RegExp(r'[\s\-\.]'), '');
      if (cand.length == 12) return cand;
    }

    final fallback = RegExp(r'\b\d{12}\b').firstMatch(processedText);
    if (fallback != null) {
      return fallback.group(0) ?? '';
    }

    return '';
  }

  static _ParsedName _extractStudentName(String text) {
    String lastName = '';
    String firstName = '';
    String middleName = '';
    String extension = '';

    // 1. Explicit separate headers
    final lastMatch = RegExp(
      r"""\b(?:LAST\s*NAME|SURNAME|FAMILY\s*NAME)[:\s,]*([A-Za-z\-\ \.\']+?)(?=\s*(?:FIRST|GIVEN|MIDDLE|\bM\.?I\.?\b|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\r|\n|$))""",
      caseSensitive: false,
    ).firstMatch(text);

    final firstMatch = RegExp(
      r"""\b(?:FIRST\s*NAME|GIVEN\s*NAME)[:\s,]*([A-Za-z\-\ \.\']+?)(?=\s*(?:LAST|SURNAME|MIDDLE|\bM\.?I\.?\b|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\r|\n|$))""",
      caseSensitive: false,
    ).firstMatch(text);

    final middleMatch = RegExp(
      r"""\b(?:MIDDLE\s*NAME|MIDDLE\s*INITIAL|MIDDLE|\bM\.?I\.?\b)[:\s,]*([A-Za-z\-\ \.\']+?)(?=\s*(?:LAST|SURNAME|FIRST|GIVEN|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\r|\n|$))""",
      caseSensitive: false,
    ).firstMatch(text);

    final extMatch = RegExp(
      r'\b(?:EXTENSION\s*NAME|EXT\.?\s*NAME|NAME\s*EXT\.?|EXTENSION|SUFFIX|EXT)[:\s,]*([A-Za-z0-9\.\-]+?)(?=\s*(?:LAST|FIRST|MIDDLE|\bM\.?I\.?\b|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\r|\n|$))',
      caseSensitive: false,
    ).firstMatch(text);

    if (lastMatch != null) lastName = lastMatch.group(1)?.trim() ?? '';
    if (firstMatch != null) firstName = firstMatch.group(1)?.trim() ?? '';
    if (middleMatch != null) middleName = middleMatch.group(1)?.trim() ?? '';
    if (extMatch != null) extension = extMatch.group(1)?.trim() ?? '';

    // 2. Combined name fallback
    if (lastName.isEmpty || firstName.isEmpty) {
      final combinedMatch = RegExp(
        r"""(?:Name|Learner\x27?s?\s*Name|Name\s*of\s*Learner|Name\s*of\s*Student)[:\s,]+([A-Za-z\-\ \.\']+?),\s*([A-Za-z\-\ \.\']+?)(?=\s*(?:LRN|SEX|GENDER|DOB|BIRTH|DATE|GRADE|SECTION|SCHOOL|S\.?Y\.?|TRACK|STRAND|\r|\n|$))""",
        caseSensitive: false,
      ).firstMatch(text);

      if (combinedMatch != null) {
        final candLast = combinedMatch.group(1)?.trim() ?? '';
        final candRest = (combinedMatch.group(2)?.trim() ?? '')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();

        if (lastName.isEmpty) lastName = candLast;
        if (candRest.isNotEmpty) {
          final extCheck = candRest.last.toUpperCase().replaceAll('.', '');
          const validExts = ['JR', 'SR', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
          if (validExts.contains(extCheck)) {
            if (extension.isEmpty) extension = candRest.removeLast();
          }
          if (candRest.length >= 2 && middleName.isEmpty) {
            middleName = candRest.removeLast();
          }
          if (firstName.isEmpty) firstName = candRest.join(' ');
        }
      }
    }

    lastName = _cleanNameField(lastName);
    firstName = _cleanNameField(firstName);
    middleName = _cleanNameField(middleName);
    extension = extension.replaceAll(RegExp(r'[\.,]'), '').trim().toUpperCase();

    // Cross-field duplicate word stripping
    if (lastName.isNotEmpty && firstName.isNotEmpty && firstName.toLowerCase() != lastName.toLowerCase()) {
      final escaped = RegExp.escape(lastName);
      final candidate = firstName.replaceAll(RegExp('\\b$escaped\\b', caseSensitive: false), '').trim();
      if (candidate.isNotEmpty) firstName = candidate;
    }
    if (lastName.isNotEmpty && middleName.isNotEmpty && middleName.toLowerCase() != lastName.toLowerCase()) {
      final escaped = RegExp.escape(lastName);
      final candidate = middleName.replaceAll(RegExp('\\b$escaped\\b', caseSensitive: false), '').trim();
      if (candidate.isNotEmpty) middleName = candidate;
    }
    if (firstName.isNotEmpty && middleName.isNotEmpty && middleName.toLowerCase() != firstName.toLowerCase()) {
      final escaped = RegExp.escape(firstName);
      final candidate = middleName.replaceAll(RegExp('\\b$escaped\\b', caseSensitive: false), '').trim();
      if (candidate.isNotEmpty) middleName = candidate;
    }

    // Extract extensions that might be embedded in name fields
    final extPattern = RegExp(r'(?:,\s*|\b)(JR\.?|SR\.?|I{1,3}|IV|V|VI{0,3}|IX|X)\b', caseSensitive: false);
    if (extension.isEmpty) {
      final match = extPattern.firstMatch(lastName);
      if (match != null) {
        extension = (match.group(1) ?? '').replaceAll(RegExp(r'[\.,]'), '').trim().toUpperCase();
        lastName = lastName.replaceAll(match.group(0)!, '').replaceAll(RegExp(r',+$'), '').trim();
      }
    }
    if (extension.isEmpty) {
      final match = extPattern.firstMatch(firstName);
      if (match != null) {
        extension = (match.group(1) ?? '').replaceAll(RegExp(r'[\.,]'), '').trim().toUpperCase();
        firstName = firstName.replaceAll(match.group(0)!, '').replaceAll(RegExp(r',+$'), '').trim();
      }
    }
    if (extension.isEmpty) {
      final match = extPattern.firstMatch(middleName);
      if (match != null) {
        extension = (match.group(1) ?? '').replaceAll(RegExp(r'[\.,]'), '').trim().toUpperCase();
        middleName = middleName.replaceAll(match.group(0)!, '').replaceAll(RegExp(r',+$'), '').trim();
      }
    }

    return _ParsedName(
      lastName: _cleanNameField(lastName),
      firstName: _cleanNameField(firstName),
      middleName: _cleanNameField(middleName),
      extension: extension,
    );
  }

  static String _cleanNameField(String str) {
    if (str.trim().isEmpty) return '';

    // Remove unwanted DepEd header label words if accidentally captured
    String cleaned = str.replaceAll(
      RegExp(
        r'\b(?:LAST|FIRST|MIDDLE|SURNAME|FAMILY|GIVEN|NAME|EXTENSION|SUFFIX|EXT|LEARNER\x27?S?|STUDENT|LRN|SEX|GENDER|DOB|BIRTH|DATE|GRADE|SECTION|SCHOOL|S\.?Y\.?)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    cleaned = cleaned.replaceAll(RegExp(r"[^A-Za-z\-\.\'\s]"), ' ');
    final words = cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'^\.+|\.+$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '';

    // Deduplicate repeated adjacent words
    final deduped = <String>[];
    for (int i = 0; i < words.length; i++) {
      if (i == 0 || words[i].toLowerCase() != words[i - 1].toLowerCase()) {
        deduped.add(words[i]);
      }
    }

    return deduped.join(' ');
  }

  static String? _extractDob(String text) {
    const months = {
      'jan': '01', 'january': '01',
      'feb': '02', 'february': '02',
      'mar': '03', 'march': '03',
      'apr': '04', 'april': '04',
      'may': '05',
      'jun': '06', 'june': '06',
      'jul': '07', 'july': '07',
      'aug': '08', 'august': '08',
      'sep': '09', 'september': '09',
      'oct': '10', 'october': '10',
      'nov': '11', 'november': '11',
      'dec': '12', 'december': '12',
    };

    final keywordMatch = RegExp(
      r'(?:Date\s*of\s*Birth|Birth\s*Date|Birthdate(?:\s*\([^\)]*\))?|DOB|Birth|Born)[:\s,]*([^\n,]{4,35})',
      caseSensitive: false,
    ).firstMatch(text);

    final searchArea = keywordMatch?.group(1) ?? text;

    // 1. Month Day, Year (e.g. May 14, 2007 or 14 May 2007)
    final m1 = RegExp(r'\b([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\b').firstMatch(searchArea);
    if (m1 != null) {
      final mStr = m1.group(1)!.toLowerCase();
      final dStr = m1.group(2)!.padLeft(2, '0');
      final yStr = m1.group(3)!;
      if (months.containsKey(mStr)) {
        return '$yStr-${months[mStr]}-$dStr';
      }
    }

    final m2 = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,9}),?\s+(\d{4})\b').firstMatch(searchArea);
    if (m2 != null) {
      final dStr = m2.group(1)!.padLeft(2, '0');
      final mStr = m2.group(2)!.toLowerCase();
      final yStr = m2.group(3)!;
      if (months.containsKey(mStr)) {
        return '$yStr-${months[mStr]}-$dStr';
      }
    }

    // 2. YYYY-MM-DD or YYYY/MM/DD
    final iso = RegExp(r'\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b').firstMatch(searchArea);
    if (iso != null) {
      final y = iso.group(1)!;
      final m = iso.group(2)!.padLeft(2, '0');
      final d = iso.group(3)!.padLeft(2, '0');
      return '$y-$m-$d';
    }

    // 3. MM/DD/YYYY or DD/MM/YYYY
    final slash = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b').firstMatch(searchArea);
    if (slash != null) {
      final p1 = int.tryParse(slash.group(1)!) ?? 0;
      final p2 = int.tryParse(slash.group(2)!) ?? 0;
      int y = int.tryParse(slash.group(3)!) ?? 0;
      if (y < 100) {
        y += (y <= 30 ? 2000 : 1900);
      }
      int m = p1;
      int d = p2;
      if (p1 > 12 && p2 <= 12) {
        d = p1;
        m = p2;
      }
      return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }

    return null;
  }

  static String _extractSex(String text) {
    final match = RegExp(r'(?:Sex|Gender)[:\s,]*(MALE|FEMALE|M\b|F\b)', caseSensitive: false)
        .firstMatch(text);
    if (match != null) {
      final val = match.group(1)!.toUpperCase();
      return val.startsWith('M') ? 'Male' : 'Female';
    }
    return '';
  }

  static List<Map<String, String>> _extractAllScholasticRecords(String text) {
    final records = <Map<String, String>>[];
    final gradeRegex = RegExp(r'(?:GRADE\s*LEVEL|Classified\s*as\s*Grade|GRADE\s*:)[\s,:]*([7-9]|1[0-2])\b',
        caseSensitive: false);

    final matches = gradeRegex.allMatches(text);
    for (final match in matches) {
      final gradeLevel = match.group(1) ?? '';
      final startIndex = match.start;
      final endIndex = (startIndex + 600 < text.length) ? startIndex + 600 : text.length;
      final block = text.substring(startIndex, endIndex);

      // Section
      String section = '';
      final secMatch = RegExp(
        r'SECTION[\s,:]*([A-Za-z0-9\-\s]+?)(?=\s*(?:FIRST|SECOND|1ST|2ND|SEM|SCHOOL\s*YEAR|S\.?Y\.?|NAME\s*OF|ADVISER|TEACHER|,|\n|$))',
        caseSensitive: false,
      ).firstMatch(block);
      if (secMatch != null) {
        section = (secMatch.group(1) ?? '').replaceAll(RegExp(r'[,:]'), '').trim();
      }

      // School Year
      String schoolYear = '';
      final syMatch = RegExp(r'(?:SCHOOL\s*YEAR|S\.?Y\.?)[\s,:]*(\d{4}\s*-\s*\d{4})', caseSensitive: false)
          .firstMatch(block);
      if (syMatch != null) {
        schoolYear = (syMatch.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');
      }

      if (gradeLevel.isNotEmpty && section.isNotEmpty && schoolYear.isNotEmpty) {
        records.add({
          'gradeLevel': gradeLevel,
          'section': section,
          'schoolYear': schoolYear,
        });
      }
    }

    return records;
  }
}

class _ParsedName {
  final String lastName;
  final String firstName;
  final String middleName;
  final String extension;

  const _ParsedName({
    required this.lastName,
    required this.firstName,
    required this.middleName,
    required this.extension,
  });
}

