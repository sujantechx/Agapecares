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

  /// Validate email address. Returns null when valid.
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email cannot be empty.';
    final emailRegExp = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!emailRegExp.hasMatch(value)) return 'Enter a valid email address.';
    return null;
  }

  /// Optional phone validator: accepts empty/null as valid, otherwise validates the phone.
  static String? validatePhoneNumberOptional(String? value) {
    if (value == null || value.isEmpty) return null;
    return validatePhoneNumber(value);
  }
}