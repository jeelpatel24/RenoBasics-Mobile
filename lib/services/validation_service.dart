class ValidationService {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Need 1 uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Need 1 lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Need 1 number';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10 && !(digits.length == 11 && digits[0] == '1')) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? validateBusinessNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Business Number is required';
    final clean = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^[a-zA-Z0-9]{9,15}$').hasMatch(clean)) {
      return 'Enter a valid BN (9-15 alphanumeric)';
    }
    return null;
  }

  static String? validateOBR(String? value) {
    if (value == null || value.trim().isEmpty) return 'OBR number is required';
    final clean = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^[a-zA-Z0-9]{5,20}$').hasMatch(clean)) {
      return 'Enter a valid OBR number';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? validatePostalCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Postal code is required';
    final clean = value.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!RegExp(r'^[A-Z]\d[A-Z]\d[A-Z]\d$').hasMatch(clean)) {
      return 'Enter a valid Canadian postal code (e.g. M5V 2T6)';
    }
    return null;
  }
}
