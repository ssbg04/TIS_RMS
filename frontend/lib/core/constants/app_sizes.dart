class AppSizes {
  // Prevent instantiation
  AppSizes._();

  // Padding & Margins
  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0; // Default Standard Padding
  static const double p20 = 20.0;
  static const double p24 = 24.0; // Screen Edge Padding
  static const double p32 = 32.0;
  static const double p48 = 48.0;

  // Border Radii
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0; // Standard for Inputs/Buttons
  static const double radiusLarge = 12.0; // Standard for Cards/Modals
  static const double radiusCircular = 100.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // Elevations
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
}
