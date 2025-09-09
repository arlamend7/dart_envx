import 'types.dart';

/// Build a resolver from explicit alias lists per enum value.
///
/// Example:
/// ```dart
/// final resolver = aliasesResolver<AppEnv>({
///   AppEnv.production: ['prod', 'production'],
///   AppEnv.staging: ['stage', 'staging'],
///   AppEnv.development: ['dev', 'development'],
/// });
/// ```
///
/// Notes:
/// - Matching is case-insensitive by default.
/// - Optionally recognizes the enum's `name` (Dart >= 2.15) when [allowEnumName] is true.
EnvResolver<E> aliasesResolver<E extends Enum>(
  Map<E, List<String>> aliases, {
  bool caseInsensitive = true,
  bool allowEnumName = true,
}) {
  // Validate eagerly, no throws – just produce a resolver that never matches if inputs are unusable.
  if (aliases.isEmpty) {
    return (_) => null;
  }

  final map = <String, E>{};

  String keyOf(String s) => caseInsensitive ? s.toLowerCase() : s;

  for (final entry in aliases.entries) {
    final env = entry.key;
    final values = entry.value;
    if (allowEnumName) {
      map[keyOf(env.name)] = env;
    }
    for (final raw in values) {
      if (raw.trim().isEmpty) continue;
      map[keyOf(raw.trim())] = env;
    }
  }

  if (map.isEmpty) {
    return (_) => null;
  }

  return (String input) {
    final k = keyOf(input.trim());
    if (k.isEmpty) return null;
    return map[k];
  };
}

/// Build a resolver from a flat string->enum mapping.
/// Useful when you already have a normalized token map.
///
/// Example:
/// ```dart
/// final resolver = tokenResolver<AppEnv>({
///   'prod': AppEnv.production,
///   'production': AppEnv.production,
///   'stage': AppEnv.staging,
///   'staging': AppEnv.staging,
///   'dev': AppEnv.development,
///   'development': AppEnv.development,
/// });
/// ```
EnvResolver<E> tokenResolver<E extends Enum>(
  Map<String, E> tokens, {
  bool caseInsensitive = true,
}) {
  if (tokens.isEmpty) return (_) => null;

  final map = <String, E>{};
  String keyOf(String s) => caseInsensitive ? s.toLowerCase() : s;

  for (final entry in tokens.entries) {
    final k = entry.key.trim();
    if (k.isEmpty) continue;
    map[keyOf(k)] = entry.value;
  }

  if (map.isEmpty) return (_) => null;

  return (String input) {
    final k = keyOf(input.trim());
    if (k.isEmpty) return null;
    return map[k];
  };
}
