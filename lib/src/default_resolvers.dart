import 'types.dart';

/// Set `strictCollisions: true` to reject aliases assigned to different values.
/// By default, the last assignment wins for 1.x compatibility.
///
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
  bool strictCollisions = false,
}) {
  // Empty input creates a resolver that never matches.
  if (aliases.isEmpty) {
    return (_) => null;
  }

  final map = <String, E>{};

  String keyOf(String s) => caseInsensitive ? s.toLowerCase() : s;

  void add(String key, E value) {
    if (strictCollisions && map.containsKey(key) && map[key] != value) {
      throw ArgumentError('Conflicting normalized environment aliases.');
    }
    map[key] = value;
  }

  for (final entry in aliases.entries) {
    final env = entry.key;
    final values = entry.value;
    if (allowEnumName) {
      add(keyOf(env.name), env);
    }
    for (final raw in values) {
      if (raw.trim().isEmpty) continue;
      add(keyOf(raw.trim()), env);
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

/// Set `strictCollisions: true` to reject conflicting normalized tokens.
/// By default, the last assignment wins for 1.x compatibility.
///
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
  bool strictCollisions = false,
}) {
  if (tokens.isEmpty) return (_) => null;

  final map = <String, E>{};
  String keyOf(String s) => caseInsensitive ? s.toLowerCase() : s;

  for (final entry in tokens.entries) {
    final k = entry.key.trim();
    if (k.isEmpty) continue;
    final normalized = keyOf(k);
    if (strictCollisions &&
        map.containsKey(normalized) &&
        map[normalized] != entry.value) {
      throw ArgumentError('Conflicting normalized environment tokens.');
    }
    map[normalized] = entry.value;
  }

  if (map.isEmpty) return (_) => null;

  return (String input) {
    final k = keyOf(input.trim());
    if (k.isEmpty) return null;
    return map[k];
  };
}
