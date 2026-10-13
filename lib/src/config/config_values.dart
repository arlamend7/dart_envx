import 'config_exception.dart';

/// Recursively copies JSON-compatible data into immutable maps and lists.
Map<String, Object?> freezeConfig(Map<String, Object?> values) =>
    Map<String, Object?>.unmodifiable(values.map(
      (key, value) => MapEntry(key, _freeze(value)),
    ));

Object? _freeze(Object? value) {
  if (value is Map<String, Object?>) return freezeConfig(value);
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null || value is String || value is bool || value is num) {
    if (value is num && !value.isFinite) {
      throw const ConfigTypeException('Configuration numbers must be finite.');
    }
    return value;
  }
  throw const ConfigTypeException('Configuration must contain JSON values.');
}

/// Recursively merges maps; later scalars, lists, and null replace earlier ones.
Map<String, Object?> mergeConfig(
  Map<String, Object?> base,
  Map<String, Object?> overlay,
) {
  final result = Map<String, Object?>.of(base);
  for (final entry in overlay.entries) {
    final previous = result[entry.key];
    final next = entry.value;
    result[entry.key] =
        previous is Map<String, Object?> && next is Map<String, Object?>
            ? mergeConfig(previous, next)
            : next;
  }
  return freezeConfig(result);
}

/// Immutable configuration with case-sensitive, dot-separated path access.
///
/// Literal dots and backslashes in keys are escaped as `\.` and `\\` in paths.
/// Lists are values, not index-addressable path segments. Null is present for
/// [contains], but treated as missing by required getters.
class ConfigValues {
  /// Defensively copies [values], recursively freezing maps and lists.
  ConfigValues(Map<String, Object?> values) : values = freezeConfig(values);

  /// The immutable configuration map, including literal (unescaped) keys.
  final Map<String, Object?> values;

  (bool, Object?) _lookup(String path) {
    Object? value = values;
    for (final segment in _segments(path)) {
      if (value is! Map<String, Object?> || !value.containsKey(segment)) {
        return (false, null);
      }
      value = value[segment];
    }
    return (true, value);
  }

  /// Whether [path] exists, including explicit null values.
  bool contains(String path) => _lookup(path).$1;

  /// Returns a value, or null when absent. Use [contains] to distinguish null.
  Object? get(String path) => _lookup(path).$2;

  Object _required(String path) {
    final value = get(path);
    if (value == null) {
      throw const ConfigMissingException('Required value missing.');
    }
    return value;
  }

  /// Reads a string without coercing other value types.
  String getString(String path) {
    final value = _required(path);
    if (value is String) return value;
    throw const ConfigTypeException('Expected a string.');
  }

  /// Reads an integer or parses a decimal integer string.
  int getInt(String path) {
    final value = _required(path);
    if (value is int) return value;
    if (value is String && RegExp(r'^[+-]?\d+$').hasMatch(value)) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const ConfigTypeException('Expected an integer.');
  }

  /// Reads a finite number or parses a finite numeric string.
  double getDouble(String path) {
    final value = _required(path);
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value)
            : null;
    if (parsed != null && parsed.isFinite) return parsed;
    throw const ConfigTypeException('Expected a finite number.');
  }

  /// Reads a boolean or a case-insensitive `true` / `false` string.
  bool getBool(String path) {
    final value = _required(path);
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    throw const ConfigTypeException('Expected a boolean.');
  }

  /// Reads a required object section as another immutable view.
  ConfigValues getSection(String path) {
    final value = _required(path);
    if (value is Map<String, Object?>) return ConfigValues(value);
    throw const ConfigTypeException('Expected an object section.');
  }
}

List<String> _segments(String path) {
  final parts = <String>[];
  var part = StringBuffer();
  var escaped = false;
  for (final rune in path.runes) {
    final char = String.fromCharCode(rune);
    if (escaped) {
      if (char != '.' && char != r'\') {
        throw ArgumentError(
            'Only dots and backslashes can be escaped in paths.');
      }
      part.write(char);
      escaped = false;
    } else if (char == r'\') {
      escaped = true;
    } else if (char == '.') {
      if (part.isEmpty) throw ArgumentError('Empty path segment.');
      parts.add(part.toString());
      part = StringBuffer();
    } else {
      part.write(char);
    }
  }
  if (escaped || part.isEmpty) {
    throw ArgumentError('Invalid configuration path.');
  }
  parts.add(part.toString());
  return parts;
}
