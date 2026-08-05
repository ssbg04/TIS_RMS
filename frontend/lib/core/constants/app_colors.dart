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
  /// Main scaffold background — deep obsidian forest
  static const Color darkPageBackground = Color(0xFF0C100D);

  /// Card / dialog surface in dark mode
  static const Color darkSurfaceCard = Color(0xFF141916);

  /// Secondary surface (inputs, hover areas) in dark mode
  static const Color darkSurface2 = Color(0xFF1C241F);

  // ── Dark Theme Text Colors ───────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE2E8E4);
  static const Color darkTextSecondary = Color(0xFF94A398);
  static const Color darkTextMuted = Color(0xFF5F6E64);

  // ── Dark Theme Borders & Dividers ───────────────────────────
  static const Color darkBorder = Color(0xFF243029);
}
