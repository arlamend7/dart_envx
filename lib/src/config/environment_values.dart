import 'config_exception.dart';
import 'config_values.dart';

/// Maps flat environment strings to nested, case-sensitive configuration.
///
/// Only matching [prefix] keys are included; the prefix is removed before
/// splitting by [separator]. Values remain strings. Empty segments and
/// scalar/object collisions throw. No case or underscore conversion is guessed.
Map<String, Object?> nestEnvironmentValues(
  Map<String, String> values, {
  String prefix = '',
  String separator = '__',
}) {
  if (separator.isEmpty) throw ArgumentError('Separator must not be empty.');
  final result = <String, Object?>{};
  for (final entry in values.entries) {
    if (!entry.key.startsWith(prefix)) continue;
    final segments = entry.key.substring(prefix.length).split(separator);
    if (segments.any((part) => part.isEmpty)) {
      throw const ConfigParseException(
          'Environment key contains an empty segment.');
    }
    var parent = result;
    for (final segment in segments.take(segments.length - 1)) {
      if (parent.containsKey(segment) &&
          parent[segment] is! Map<String, Object?>) {
        throw const ConfigParseException('Conflicting environment key paths.');
      }
      parent =
          (parent[segment] ??= <String, Object?>{}) as Map<String, Object?>;
    }
    if (parent.containsKey(segments.last)) {
      throw const ConfigParseException('Conflicting environment key paths.');
    }
    parent[segments.last] = entry.value;
  }
  return freezeConfig(result);
}
