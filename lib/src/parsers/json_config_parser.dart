import 'dart:convert';

import '../config/config_exception.dart';
import '../config/config_values.dart';

/// Parses a JSON object, rejecting arrays, scalars, and invalid JSON.
///
/// Error messages omit source text. Returned maps and lists are immutable.
Map<String, Object?> parseJsonConfig(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const ConfigParseException(
          'JSON configuration root must be an object.');
    }
    return freezeConfig(decoded);
  } on FormatException {
    throw const ConfigParseException('Invalid JSON configuration.');
  }
}
