class AppValidators {
  /// Validates a phone number. Must start with 09 and have exactly 11 digits.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Only use 09... format exactly 11 digits
    final regex = RegExp(r'^09\d{9}$');
    if (!regex.hasMatch(value)) {
      return 'Must be an 11-digit number starting with 09 (e.g., 09123456789)';
    }
    return null;
  }

  /// Validates an email address using a standard regex.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final regex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    if (!regex.hasMatch(value)) {
      return 'Enter a valid email (e.g., name@email.com)';
    }
    return null;
  }

  /// Validates password complexity: > 8 chars, 1 uppercase, 1 lowercase, 1 number
  static String? validatePasswordComplexity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length <= 8) {
      return 'Password must be more than 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Helper to validate required fields
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
