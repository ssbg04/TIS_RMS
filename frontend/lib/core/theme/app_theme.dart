import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  // Prevent instantiation
  AppTheme._();

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: AppColors.pageBackground,
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        onPrimary: Colors.white,
        secondary: AppColors.darkGreen,
        filledButtonBg: AppColors.primaryGreen,
        surface: AppColors.surfaceWhite,
        cardSurface: AppColors.surfaceWhite,
        appBarSurface: AppColors.surfaceWhite,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        inputFill: AppColors.inputBackground,
        hintColor: AppColors.textMuted,
        labelColor: AppColors.textSecondary,
        errorColor: AppColors.error,
        appBarShadowColor: Colors.black.withValues(alpha: 0.05),
        cardShadowColor: Colors.black.withValues(alpha: 0.08),
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: AppColors.darkPageBackground,
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreenLight,
        onPrimary: const Color(0xFF0B100D),
        secondary: AppColors.darkGreen,
        filledButtonBg: AppColors.primaryGreen,
        surface: AppColors.darkSurface2,
        cardSurface: AppColors.darkSurfaceCard,
        appBarSurface: AppColors.darkSurface2,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        inputFill: AppColors.darkSurface2,
        hintColor: AppColors.darkTextMuted,
        labelColor: AppColors.darkTextSecondary,
        errorColor: AppColors.error,
        appBarShadowColor: Colors.black.withValues(alpha: 0.2),
        cardShadowColor: Colors.black.withValues(alpha: 0.3),
      );

  static ThemeData get highContrastLightTheme => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: const Color(0xFFFFFFFF),
        seedColor: const Color(0xFF146336),
        primary: const Color(0xFF146336),
        onPrimary: Colors.white,
        secondary: AppColors.darkGreen,
        filledButtonBg: const Color(0xFF146336),
        surface: const Color(0xFFFFFFFF),
        cardSurface: const Color(0xFFFFFFFF),
        appBarSurface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF000000),
        onSurfaceVariant: const Color(0xFF1F2937),
        inputFill: const Color(0xFFFFFFFF),
        hintColor: const Color(0xFF1F2937),
        labelColor: const Color(0xFF1F2937),
        errorColor: const Color(0xFFB91C1C),
        appBarShadowColor: Colors.black.withValues(alpha: 0.12),
        cardShadowColor: Colors.black.withValues(alpha: 0.12),
        cardBorderColor: const Color(0xFF1F2937),
        inputBorderColor: const Color(0xFF1F2937),
        dividerColor: const Color(0xFF1F2937),
        outlineColor: const Color(0xFF1F2937),
        textColor: const Color(0xFF000000),
      );

  static ThemeData get highContrastDarkTheme => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: const Color(0xFF0B100D),
        seedColor: const Color(0xFF146336),
        primary: const Color(0xFF4ADE80),
        onPrimary: const Color(0xFF0B100D),
        secondary: const Color(0xFF146336),
        filledButtonBg: const Color(0xFF146336),
        surface: const Color(0xFF141C17),
        cardSurface: const Color(0xFF141C17),
        appBarSurface: const Color(0xFF141C17),
        onSurface: const Color(0xFFFFFFFF),
        onSurfaceVariant: const Color(0xFFD1DDD5),
        inputFill: const Color(0xFF141C17),
        hintColor: const Color(0xFFD1DDD5),
        labelColor: const Color(0xFFD1DDD5),
        errorColor: const Color(0xFFF87171),
        appBarShadowColor: Colors.black.withValues(alpha: 0.4),
        cardShadowColor: Colors.black.withValues(alpha: 0.4),
        cardBorderColor: const Color(0xFF7A9183),
        inputBorderColor: const Color(0xFF7A9183),
        dividerColor: const Color(0xFF7A9183),
        outlineColor: const Color(0xFF7A9183),
        textColor: const Color(0xFFFFFFFF),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color seedColor,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color filledButtonBg,
    required Color surface,
    required Color cardSurface,
    required Color appBarSurface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color inputFill,
    required Color hintColor,
    required Color labelColor,
    required Color errorColor,
    required Color appBarShadowColor,
    required Color cardShadowColor,
    Color? cardBorderColor,
    Color? inputBorderColor,
    Color? dividerColor,
    Color? outlineColor,
    Color? textColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final overlayBrightness = isDark ? Brightness.light : Brightness.dark;
    final baseTextTheme = isDark
        ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.interTextTheme();
    final textTheme = textColor != null
        ? baseTextTheme.apply(bodyColor: textColor, displayColor: textColor)
        : baseTextTheme;
    final defaultInputBorderSide = inputBorderColor != null
        ? BorderSide(color: inputBorderColor, width: 1.5)
        : BorderSide.none;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: filledButtonBg,
      dividerColor: dividerColor,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outlineColor,
        error: errorColor,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: appBarSurface,
        elevation: cardBorderColor != null ? 0 : 1,
        shadowColor: appBarShadowColor,
        scrolledUnderElevation: 0,
        shape: cardBorderColor != null
            ? Border(bottom: BorderSide(color: cardBorderColor, width: 1.5))
            : null,
        iconTheme: IconThemeData(color: onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: overlayBrightness,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: overlayBrightness,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: cardBorderColor != null ? 0 : 2,
        shadowColor: cardShadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          side: cardBorderColor != null
              ? BorderSide(color: cardBorderColor, width: 1.5)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button Theme — always dark green bg + white text for >= 4.5:1 contrast
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: filledButtonBg,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: filledButtonBg.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p24,
            vertical: AppSizes.p16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme — keeps dark green bg + white text when colorScheme.primary is light
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: filledButtonBg,
          foregroundColor: Colors.white,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p24,
            vertical: AppSizes.p16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Default Input Decoration (Text Fields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: defaultInputBorderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: defaultInputBorderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(
            color: primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: errorColor, width: 2.0),
        ),
        hintStyle: GoogleFonts.inter(color: hintColor),
        labelStyle: GoogleFonts.inter(color: labelColor),
      ),

      // ListTile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
      ),

      // Font Family & Typography
      textTheme: textTheme,

      // Page Transitions
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }
}
