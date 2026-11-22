import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary Brand Colors
  static const Color primaryGreen = Color(0xFF1C8248);
  /// High-contrast green for text and icons on dark surfaces (>= 6.8:1).
  static const Color primaryGreenLight = Color(0xFF34D399);
  static const Color darkGreen = Color(0xFF085F32);
  static const Color fourPs = Color(0xFF2E3192);

  // ── Light Theme Backgrounds ──────────────────────────────────
  static const Color pageBackground = Color(
    0xFFF3F4F6,
  ); // Light gray background
  static const Color surfaceWhite = Colors.white; // Cards, Dialogs
  static const Color inputBackground = Color(0xFFE5E5E5);
  static const Color borderLight = Color(0xFFD1D5DB);
  static const Color hoverLight = Color(0xFFF3F4F6);
  static const Color overlayLight = Color(0x7F000000);

  // ── Light Theme Text Colors ──────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4B5550);
  static const Color textMuted = Color(0xFF5E6862);

  // ── Status Colors ────────────────────────────────────────────
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.orange;
  static const Color success = Color(0xFF1C8248);
  static const Color info = Colors.blue;

  // ── Dark Theme Backgrounds ───────────────────────────────────
  /// Main scaffold background — deep charcoal with a soft green undertone (not black)
  static const Color darkPageBackground = Color(0xFF161D19);

  /// Card / dialog surface in dark mode
  static const Color darkSurfaceCard = Color(0xFF202A25);

  /// Secondary surface (inputs, hover areas) in dark mode
  static const Color darkSurface2 = Color(0xFF2A362F);
  static const Color hoverDark = Color(0xFF35443B);
  static const Color overlayDark = Color(0xB3000000);

  // ── Dark Theme Text Colors ───────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE7ECE7);
  static const Color darkTextSecondary = Color(0xFFB5C4BA);
  static const Color darkTextMuted = Color(0xFF92A599);

  // ── Dark Theme Borders & Dividers ───────────────────────────
  static const Color darkBorder = Color(0xFF45584D);
}
