// lib/core/utils/validators.dart

/// A utility class for common input validation logic.
class Validators {
  /// Validates a phone number.
  /// Returns null if the number is valid, otherwise returns an error message string.
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number cannot be empty.';
    }
    // A simple regex for a 10-digit phone number.
    // This can be adjusted for country codes or other formats.
    final phoneRegExp = RegExp(r'^\d{10}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'Enter a valid 10-digit phone number.';
    }
    return null;
  }
}