import 'types.dart';
import 'environment_registry.dart';

/// Resolves the current environment and returns typed configuration.
///
/// Pure core with I/O only at `resolveFromBuildDefine`, which reads the
/// compile-time define via `String.fromEnvironment`.
///
/// No-throw design: unrecognized values fall back to [registry.defaultEnvironment].
class EnvironmentService<K, C> {
  /// Where we keep configs and the default environment.
  final EnvironmentRegistry<K, C> registry;

  /// How to parse a raw string value into the environment key.
  final EnvResolver<K> resolver;

  /// Compile-time define key, defaults to [EnvxConstants.defaultDefineKey].
  final String defineKey;

  /// Creates a new [EnvironmentService].
  ///
  /// Parameters:
  /// - [registry]: map of environments to configs, with a chosen default.
  /// - [resolver]: function that maps string => key (nullable result).
  /// - [defineKey]: optional override for the compile-time define key.
  const EnvironmentService({
    required this.registry,
    required this.resolver,
    this.defineKey = EnvxConstants.defaultDefineKey,
  });

  /// Parse [raw] via [resolver], falling back to [registry.defaultEnvironment] if null/empty/unrecognized.
  K resolveFromString(String? raw) {
    if (raw == null) return registry.defaultEnvironment;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return registry.defaultEnvironment;
    final resolved = resolver(trimmed);
    return resolved ?? registry.defaultEnvironment;
  }

  /// Read the compile-time define and resolve an environment.
  ///
  /// - [key]: optional override for the `String.fromEnvironment` key.
  /// - [fallbackValue]: optional raw value used if the define is empty.
  ///
  /// Never throws. If it can't resolve, it falls back to [registry.defaultEnvironment].
  K resolveFromBuildDefine({String? key, String? fallbackValue}) {
    final k = (key == null || key.isEmpty) ? defineKey : key;
    // Note: `String.fromEnvironment` is evaluated at compile time.
    const empty = '';
    final defined = String.fromEnvironment(k, defaultValue: empty);
    final candidate = defined.isEmpty ? (fallbackValue ?? empty) : defined;
    if (candidate.isEmpty) return registry.defaultEnvironment;
    final resolved = resolver(candidate);
    return resolved ?? registry.defaultEnvironment;
  }

  /// Get configuration for [env] with fallback to default.
  ///
  /// May return `null` if neither the requested nor default configs exist in the registry.
  Future<C>? configFor(K env) => registry.tryGetOrDefault(env);

  /// Convenience: resolve environment from a string and return its config.
  Future<C>? configFromString(String? raw) {
    final env = resolveFromString(raw);
    return configFor(env);
  }

  /// Convenience: resolve environment from the build define and return its config.
  Future<C>? configFromBuildDefine({String? key, String? fallbackValue}) {
    final env = resolveFromBuildDefine(key: key, fallbackValue: fallbackValue);
    return configFor(env);
  }
}
