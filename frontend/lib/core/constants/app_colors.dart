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
  /// Main scaffold background — deep charcoal navy (not pure black)
  static const Color darkPageBackground = Color(0xFF1A1D23);

  /// Card / dialog surface in dark mode
  static const Color darkSurfaceCard = Color(0xFF22262F);

  /// Secondary surface (inputs, hover areas) in dark mode
  static const Color darkSurface2 = Color(0xFF2A2F3A);

  // ── Dark Theme Text Colors ───────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE8EAF0);
  static const Color darkTextSecondary = Color(0xFF9AA0B0);
  static const Color darkTextMuted = Color(0xFF60677A);

  // ── Dark Theme Borders & Dividers ───────────────────────────
  static const Color darkBorder = Color(0xFF2E3340);
}
