import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Helper utility for determining document icons and colors based on file extension and document type.
class FileIconHelper {
  /// Checks if a file is an Excel spreadsheet or tabular data file.
  static bool isExcel(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.xlsx') ||
        name.endsWith('.xls') ||
        name.endsWith('.csv') ||
        name.endsWith('.tsv') ||
        name.endsWith('.ods') ||
        type.contains('excel') ||
        type.contains('sheet') ||
        type.contains('xls');
  }

  /// Checks if a file is a PDF document.
  static bool isPdf(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.pdf') || type.contains('pdf');
  }

  /// Checks if a file is an image file.
  static bool isImage(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.bmp') ||
        name.endsWith('.svg') ||
        name.endsWith('.heic') ||
        type.contains('image') ||
        type.contains('photo') ||
        type.contains('picture');
  }

  /// Checks if a file is a Word or text document.
  static bool isWordOrText(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.docx') ||
        name.endsWith('.doc') ||
        name.endsWith('.rtf') ||
        name.endsWith('.odt') ||
        name.endsWith('.txt') ||
        name.endsWith('.pages') ||
        type.contains('word') ||
        type.contains('doc') ||
        type.contains('text');
  }

  /// Checks if a file is a presentation/slide file.
  static bool isPresentation(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.pptx') ||
        name.endsWith('.ppt') ||
        name.endsWith('.odp') ||
        name.endsWith('.key') ||
        type.contains('presentation') ||
        type.contains('powerpoint') ||
        type.contains('slide');
  }

  /// Checks if a file is an archive/compressed file.
  static bool isArchive(String? fileName, {String? docType}) {
    final name = (fileName ?? '').toLowerCase().trim();
    final type = (docType ?? '').toLowerCase().trim();
    return name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z') ||
        name.endsWith('.tar') ||
        name.endsWith('.gz');
  }

  /// Returns the appropriate [IconData] for a given file name and optional document type.
  static IconData getIcon(String? fileName, {String? docType}) {
    if (isPdf(fileName, docType: docType)) {
      return Icons.picture_as_pdf;
    }
    if (isExcel(fileName, docType: docType)) {
      return Icons.table_chart;
    }
    if (isImage(fileName, docType: docType)) {
      return Icons.image;
    }
    if (isWordOrText(fileName, docType: docType)) {
      return Icons.description;
    }
    if (isPresentation(fileName, docType: docType)) {
      return Icons.slideshow;
    }
    if (isArchive(fileName, docType: docType)) {
      return Icons.folder_zip;
    }

    final name = (fileName ?? '').toLowerCase().trim();
    if (name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.m4a') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg')) {
      return Icons.audio_file;
    }
    if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm')) {
      return Icons.video_file;
    }
    if (name.endsWith('.json') ||
        name.endsWith('.xml') ||
        name.endsWith('.html') ||
        name.endsWith('.css') ||
        name.endsWith('.js') ||
        name.endsWith('.sql')) {
      return Icons.code;
    }

    return Icons.insert_drive_file;
  }

  /// Returns the appropriate [Color] for a given file name and optional document type.
  static Color getColor(String? fileName, {String? docType}) {
    if (isPdf(fileName, docType: docType)) {
      return Colors.redAccent;
    }
    if (isExcel(fileName, docType: docType)) {
      return Colors.green.shade600;
    }
    if (isImage(fileName, docType: docType)) {
      return Colors.blueAccent;
    }
    if (isWordOrText(fileName, docType: docType)) {
      return const Color(0xFF1976D2);
    }
    if (isPresentation(fileName, docType: docType)) {
      return const Color(0xFFE65100);
    }
    if (isArchive(fileName, docType: docType)) {
      return const Color(0xFFF57C00);
    }

    final name = (fileName ?? '').toLowerCase().trim();
    if (name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.m4a') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg')) {
      return const Color(0xFF00897B);
    }
    if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm')) {
      return const Color(0xFF7B1FA2);
    }
    if (name.endsWith('.json') ||
        name.endsWith('.xml') ||
        name.endsWith('.html') ||
        name.endsWith('.css') ||
        name.endsWith('.js') ||
        name.endsWith('.sql')) {
      return const Color(0xFF0097A7);
    }

    return AppColors.primaryGreen;
  }

  /// Builds a standard file icon widget with consistent sizing and colors.
  static Widget buildIcon(
    String? fileName, {
    String? docType,
    double size = 24,
    Color? overrideColor,
  }) {
    final icon = getIcon(fileName, docType: docType);
    final color = overrideColor ?? getColor(fileName, docType: docType);
    return Icon(icon, size: size, color: color);
  }
}
