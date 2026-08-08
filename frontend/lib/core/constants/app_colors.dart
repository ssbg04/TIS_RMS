import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary Brand Colors
  static const Color primaryGreen = Color(0xFF1C8248);
  static const Color darkGreen = Color(0xFF085F32);

  // ── Light Theme Backgrounds ──────────────────────────────────
  static const Color pageBackground = Color(
    0xFFF3F4F6,
  ); // Light gray background
  static const Color surfaceWhite = Colors.white; // Cards, Dialogs
  static const Color inputBackground = Color(0xFFE5E5E5);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color hoverLight = Color(0xFFF3F4F6);
  static const Color overlayLight = Color(0x7F000000);

  // ── Light Theme Text Colors ──────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);

  // ── Status Colors ────────────────────────────────────────────
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.orange;
  static const Color success = Color(0xFF1C8248);
  static const Color info = Colors.blue;

  // ── Dark Theme Backgrounds ───────────────────────────────────
  /// Main scaffold background — deep space/slate black
  static const Color darkPageBackground = Color(0xFF0A0C10);

  /// Card / dialog surface in dark mode
  static const Color darkSurfaceCard = Color(0xFF12161A);

  /// Secondary surface (inputs, hover areas) in dark mode
  static const Color darkSurface2 = Color(0xFF1A2026);
  static const Color hoverDark = Color(0xFF222B33);
  static const Color overlayDark = Color(0xB3000000);

  // ── Dark Theme Text Colors ───────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE2E6EA);
  static const Color darkTextSecondary = Color(0xFF949CA4);
  static const Color darkTextMuted = Color(0xFF5F666E);

  // ── Dark Theme Borders & Dividers ───────────────────────────
  static const Color darkBorder = Color(0xFF222B33);
}
